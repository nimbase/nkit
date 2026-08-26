import std/[os, strutils, osproc]
import pkg/openparser/regex
import nkit/cli/project

## iOS build pipeline helpers for the nkit CLI.
##
## Pure builders (triple composition, nim argument assembly, Info.plist
## rendering) are separated from process wrappers so they can be unit
## tested without touching xcrun or nimble.

type
  Platform* = enum
    pfIos
    pfMacos

proc hostArch*(): string =
  ## Canonical clang-triple arch of the machine running the CLI
  ## ("arm64" / "x86_64"), detected at runtime so one binary serves
  ## both Mac types.  Uses hw.machine (reports real hardware even
  ## under Rosetta) rather than uname -m (reports emulated arch).
  let (outp, code) = execCmdEx("sysctl -n hw.machine")
  if code == 0:
    let m = strip(outp)
    if m in ["arm64", "x86_64"]:
      return m
  when defined(arm64):
    result = "arm64"
  else:
    result = "x86_64"

proc hostCpu*(): string =
  ## Nim-style CPU flag value matching hostArch.
  if hostArch() == "x86_64": "amd64" else: "arm64"

func outDirFor*(platform: Platform, outDir: string): string =
  case platform
  of pfIos: outDir / "ios-simulator"
  of pfMacos: outDir / "macos"

func appBundlePath*(platform: Platform, outDir, appName: string): string =
  outDirFor(platform, outDir) / (appName & ".app")

func executablePath*(platform: Platform, outDir,
                     appName: string): string =
  appBundlePath(platform, outDir, appName) / appName

func simulatorTriple*(cpu, minVersion: string): string =
  cpu & "-apple-ios" & minVersion & "-simulator"

func platformCfgPath*(platform: Platform, outDir: string): string =
  outDirFor(platform, outDir) / "nkit_cross.cfg"

func composeNimArgs*(platform: Platform, cfg: ProjectConfig,
                     sdkPath, outDir: string,
                     release = false): seq[string] =
  ## Assembles the arguments handed to the package manager. Compiler
  ## details live in the project's managed config block because package
  ## managers re-split spaced flag values; see upsertPlatformConfig.
  if release:
    result.add("-d:release")
  result.add("-o:\"" & executablePath(platform, outDir, cfg.name) & "\"")

const
  CrossBegin = "# BEGIN NKIT CROSS CONFIG (managed by nkit)"
  CrossEnd = "# END NKIT CROSS CONFIG"

proc nkitSrcPath*(): string =
  ## Resolves the absolute path to nkit's src/ directory by walking
  ## up from the CLI binary (bin/nkit → ../src).  Returns "" when
  ## the binary lives outside a nkit checkout (global install).
  let cliDir = parentDir(getAppFilename())
  let candidate = cliDir / ".." / "src"
  if dirExists(candidate):
    return expandFilename(candidate)

proc renderPlatformCfg*(platform: Platform, minVersion,
                        sdkPath: string): string =
  ## Compiler flags for the target platform. Quoting here is parsed by
  ## nim's config loader, so spaces are safe.
  result = "--os:macosx\n--cpu:" & hostCpu() & "\n--cc:clang\n"
  let nkitSrc = nkitSrcPath()
  if nkitSrc.len > 0:
    result.add("--path:\"" & nkitSrc & "\"\n")
  if platform == pfIos:
    # --os:macosx is the only Apple target nim knows; -d:ios drives the
    # conditional imports toward the UIKit shims.
    result.add("--define:ios\n")
    let triple = simulatorTriple(hostArch(), minVersion)
    let targetArgs = "-target " & triple & " -isysroot " & sdkPath
    result.add("--passC:\"" & targetArgs & "\"\n")
    result.add("--passL:\"" & targetArgs &
      " -framework Foundation -framework UIKit" &
      " -framework CoreGraphics -framework QuartzCore\"\n")

proc upsertPlatformConfig*(platform: Platform, cfg: ProjectConfig,
                           sdkPath: string) =
  ## Writes the cross-compilation flags into the project's config.nims
  ## between managed markers, leaving any user content untouched.
  ## Expects the current directory to be the project root.
  var content: string
  if fileExists("config.nims"):
    content = readFile("config.nims")
  let blockText = CrossBegin & "\n" &
    renderPlatformCfg(platform, cfg.ios.min_version, sdkPath) & CrossEnd & "\n"
  if CrossBegin in content:
    let start = strutils.find(content, CrossBegin)
    let stop = strutils.find(content, CrossEnd) + CrossEnd.len
    content = content[0 ..< start] & blockText & content[stop .. ^1]
  else:
    if content.len > 0 and not content.endsWith("\n"):
      content.add("\n")
    content.add(blockText)
  writeFile("config.nims", content)

func renderInfoPlist*(name, bundleId, version: string): string =
  ## Renders a minimal Info.plist for an .app bundle.
  """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$2</string>
    <key>CFBundleIdentifier</key>
    <string>$1</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$2</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$3</string>
    <key>CFBundleVersion</key>
    <string>$3</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
</dict>
</plist>
""".replace("$1", bundleId).replace("$2", name).replace("$3", version)

# --- process wrappers ------------------------------------------------------

proc runCapture*(cmd: string): string =
  ## Runs `cmd`, capturing stdout. Raises on non-zero exit.
  let (outp, code) = execCmdEx(cmd)
  if code != 0:
    raise newException(CatchableError,
      "command failed (" & $code & "): " & cmd)
  outp

proc resolveSimulatorSdk*(): string =
  ## Queries xcrun for the iphonesimulator SDK path.
  strip(runCapture("xcrun --sdk iphonesimulator --show-sdk-path"))

proc runStreaming*(cmd: string): int =
  ## Runs `cmd` inheriting stdio so build output and log streams flow live.
  execCmd(cmd)

proc ensureBooted*(udid: string) =
  ## Boots the target simulator and waits until it is ready to accept
  ## installs; no-op cost when it is already running.
  discard runStreaming("xcrun simctl boot \"" & udid & "\" 2>/dev/null")
  discard runStreaming("xcrun simctl bootstatus \"" & udid & "\" -b")

proc installAppBundle*(udid, bundlePath: string): int =
  runStreaming("xcrun simctl install \"" & udid & "\" \"" &
    bundlePath & "\"")

proc launchApp*(udid, bundleId: string): int =
  runStreaming("xcrun simctl launch \"" & udid & "\" \"" &
    bundleId & "\"")

proc streamLogs*(udid, processName: string): int =
  runStreaming("xcrun simctl spawn " & udid &
    " log stream --predicate 'process == \"" & processName & "\"'")

proc listSimulatorDevices*(onlyAvailable = false): int =
  ## Prints the simctl device table; pass --available to hide
  ## unavailable simulator pairs
  var cmd = "xcrun simctl list devices"
  if onlyAvailable:
    cmd.add(" available")
  runStreaming(cmd)

proc findDeviceUdid*(devicesOutput, query: string): string =
  ## Pure parser for `simctl list devices` text. Maps a fuzzy name like
  ## "iphone 12" to a UDID. Exact case-insensitive names win over
  ## substring matches; ambiguous or missing queries raise ValueError.
  let uuidProg = compile("\\(([0-9A-Fa-f-]{36})\\)")
  var exact: seq[string]
  var partial: seq[string]
  for line in devicesOutput.splitLines():
    let l = line.strip()
    if not l.contains("("):
      continue
    var vm = initRegexVM(uuidProg)
    let m = vm.find(l)
    if m.matched:
      let udid = m.group(1).str(l)
      let nameEnd = strutils.find(l, "(")
      let devName = strip(l[0 ..< nameEnd])
      if cmpIgnoreCase(devName, query) == 0:
        exact.add(udid & "|" & devName)
      elif query.toLowerAscii in devName.toLowerAscii:
        partial.add(udid & "|" & devName)
  for candidates in [exact, partial]:
    if candidates.len == 1:
      return candidates[0].split("|")[0]
    elif candidates.len > 1:
      var msg = "multiple devices match \"" & query & "\":"
      for c in candidates:
        msg.add("\n  " & c.split("|")[1])
      raise newException(ValueError, msg)
  raise newException(ValueError,
    "no simulator matches \"" & query & "\"; try `nkit devices --available`")

proc resolveSimulatorUdid*(query: string): string =
  ## Resolves a device name against the simulators that are currently
  ## available for install/launch.
  findDeviceUdid(runCapture("xcrun simctl list devices available"), query)

proc listSimulatorRuntimes*(): int =
  ## Prints the installed simulator runtimes table
  runStreaming("xcrun simctl runtime list")

proc runtimeInstallerTool*(): string =
  ## Third-party runtime installer present on this machine:
  ## "xcodes" or "xcversion"; empty when neither exists
  for t in ["xcodes", "xcversion"]:
    let (outp, code) = execCmdEx("command -v " & t)
    if code == 0 and strip(outp).len > 0:
      return t

func downloadPlatformFor*(name: string): string =
  ## Maps a runtime label like "iOS 18.2" or "17" onto an xcodebuild
  ## platform name; defaults to iOS
  result = "iOS"
  let lower = name.toLowerAscii()
  if "tvos" in lower: result = "tvOS"
  elif "watchos" in lower: result = "watchOS"
  elif "visionos" in lower: result = "visionOS"

proc installSimulatorRuntime*(name: string): int =
  ## Downloads a simulator runtime with the best available installer:
  ## `xcodes runtimes install` / `xcversion simulators --install` when
  ## present, otherwise Xcode 15+'s built-in `-downloadPlatform`.
  case runtimeInstallerTool()
  of "xcodes":
    runStreaming("xcodes runtimes install \"" & name & "\"")
  of "xcversion":
    runStreaming("xcversion simulators --install=\"" & name & "\"")
  else:
    runStreaming("xcodebuild -downloadPlatform " &
      downloadPlatformFor(name))

proc openMacApp*(bundlePath: string) =
  discard runStreaming("open \"" & bundlePath & "\"")
