import std/[os, strutils]
import pkg/kapsis
import pkg/kapsis/interactive/prompts
import nkit/cli/project
import nkit/cli/ios
import nkit/cli/scaffold

## Implementations of the nkit CLI commands, loaded by src/nkit.nim
## inside its `when isMainModule` branch.

proc stdinIsTty*(): bool =
  ## True when running attached to an interactive terminal
  when defined(windows):
    proc c_isatty(fildes: cint): cint {.
      importc: "_isatty", header: "<io.h>".}
  else:
    proc c_isatty(fildes: cint): cint {.
      importc: "isatty", header: "<unistd.h>".}
  c_isatty(0) != 0

proc platformFromValue(s: string): Platform =
  case s
  of "ios": result = pfIos
  of "macos": result = pfMacos
  else: displayError("unsupported platform: " & s, quitProcess = true)

proc packageManagerFromValue(v: Values): string =
  ## Resolves --pkgr; falls back to clue when omitted
  result =
    if v.has("--pkgr"): v.get("--pkgr").getAny
    else: "clue"
  if result notin ["nimble", "clue"]:
    displayError("unsupported package manager: " & result, quitProcess = true)

proc forwardExtras(): string =
  ## Rejoins unknown flags captured by kapsis into a nimble argument suffix
  for e in extras:
    result.add(" " & e)

proc loadCurrentProject(): tuple[cfg: ProjectConfig, dir: string] =
  let cfgPath = findProjectConfig()
  result.cfg = loadProjectConfig(cfgPath)
  result.dir = parentDir(absolutePath(cfgPath))

proc initCommand*(v: Values) =
  let interactive = stdinIsTty()
  var name =
    if v.has("name"):
      v.get("name").getStr
    elif interactive:
      prompt("Project name", default = "")
    else:
      ""
  if name.len == 0:
    displayError("project name is required", quitProcess = true)

  let here = v.has("--here")
  let rootDir =
    if here: getCurrentDir()
    else: getCurrentDir() / name
  if here:
    name = splitFile(rootDir).name

  if dirExists(rootDir) and not here:
    displayError("directory already exists: " & rootDir, quitProcess = true)

  let description =
    if interactive:
      prompt("Description", default = "A native app built with nkit")
    else:
      "A native app built with nkit"
  let author =
    if interactive: prompt("Author", default = "")
    else: ""

  scaffoldProject(rootDir, name, "0.1.0", description, author)
  displaySuccess("created project " & name & " in " & rootDir)
  display("next steps:")
  display("  cd " & (if here: "." else: name))
  display("  nkit build ios")

proc buildCommand*(v: Values) =
  let platform = platformFromValue(v.get("platform").getAny)
  let pkgman = packageManagerFromValue(v)
  let release = v.has("--release")
  let (cfg, projectDir) = loadCurrentProject()
  setCurrentDir(projectDir)

  let outDir = "build"
  createDir(appBundlePath(platform, outDir, cfg.name))

  case platform
  of pfIos:
    displayInfo("resolving iOS Simulator SDK")
    let sdk = resolveSimulatorSdk()
    upsertPlatformConfig(pfIos, cfg, sdk)
    displayInfo("building " & cfg.name & " for iOS Simulator")
    # clue treats -o: as a directory and appends the binary name;
    # nimble treats it as the exact file path.
    let nimArgs =
      if pkgman == "clue":
        @["-o:\"" & appBundlePath(pfIos, outDir, cfg.name) & "\""]
      else:
        composeNimArgs(pfIos, cfg, sdk, outDir, release)
    let cmd = pkgman & " build " & join(nimArgs, " ") & forwardExtras()
    if runStreaming(cmd) != 0:
      displayError("build failed", quitProcess = true)
  of pfMacos:
    upsertPlatformConfig(pfMacos, cfg, "")
    displayInfo("building " & cfg.name & " for macOS")
    let cmd = pkgman & " build " &
      join(composeNimArgs(pfMacos, cfg, "", outDir, release), " ") &
      forwardExtras()
    if runStreaming(cmd) != 0:
      displayError("build failed", quitProcess = true)

  writeFile(appBundlePath(platform, outDir, cfg.name) / "Info.plist",
    renderInfoPlist(cfg.name, cfg.ios.bundle_id, cfg.version))

  let bundleExe = executablePath(platform, outDir, cfg.name)
  if not fileExists(bundleExe):
    # clue places binaries in a subdirectory under the -o: path;
    # relocate into the bundle ourselves.
    let nested = bundleExe / cfg.name
    if fileExists(nested):
      moveFile(nested, bundleExe)
    elif fileExists(cfg.name):
      moveFile(cfg.name, bundleExe)
    else:
      displayError("compiler exited 0 but no binary was produced",
        quitProcess = true)
  displaySuccess("built " & appBundlePath(platform, outDir, cfg.name))

proc runCommand*(v: Values) =
  let platform = platformFromValue(v.get("platform").getAny)
  let (cfg, _) = loadCurrentProject()
  case platform
  of pfIos:
    let udid =
      if v.has("--udid"): v.get("--udid").getStr
      elif v.has("device"):
        try:
          resolveSimulatorUdid(v.get("device").getStr)
        except ValueError as e:
          displayError(e.msg &
            "; or install a runtime: nkit runtimes.install \"iOS 18\"",
            quitProcess = true)
          ""
      else: "booted"
    let bundle = appBundlePath(pfIos, "build", cfg.name)
    displayInfo("installing " & bundle & " on " & udid)
    ensureBooted(udid)
    if installAppBundle(udid, bundle) != 0:
      displayError("failed to install " & bundle, quitProcess = true)
    if launchApp(udid, cfg.ios.bundle_id) != 0:
      displayError("failed to launch " & cfg.ios.bundle_id,
        quitProcess = true)
    discard runStreaming("open -a Simulator")
    displaySuccess("launched " & cfg.ios.bundle_id &
      " (stream logs: nkit logs ios)")
  of pfMacos:
    openMacApp(appBundlePath(pfMacos, "build", cfg.name))

proc logsCommand*(v: Values) =
  let platform = platformFromValue(v.get("platform").getAny)
  if platform != pfIos:
    displayError("log streaming is only available for the iOS simulator",
      quitProcess = true)
  let (cfg, _) = loadCurrentProject()
  let udid =
    if v.has("--udid"): v.get("--udid").getStr
    else: "booted"
  discard streamLogs(udid, cfg.name)

proc devicesCommand*(v: Values) =
  ## Lists iOS Simulator devices known to Xcode
  discard listSimulatorDevices(v.has("--available"))

proc runtimesListCommand*(v: Values) =
  ## Prints the simulator runtimes installed on this machine
  displayInfo("installed simulator runtimes:")
  if listSimulatorRuntimes() != 0:
    displayError("failed to list simulator runtimes", quitProcess = true)

proc runtimesInstallCommand*(v: Values) =
  ## Downloads a runtime like "iOS 18" or "watchOS 10"; prefers xcodes
  ## and xcversion, falls back to `xcodebuild -downloadPlatform`
  let name = v.get("name").getStr
  displayInfo("downloading simulator runtime: " & name &
    (if runtimeInstallerTool().len == 0:
      " (via xcodebuild -downloadPlatform)" else: ""))
  if installSimulatorRuntime(name) != 0:
    displayError("runtime installation failed", quitProcess = true)
  displaySuccess("installed " & name & "; refresh with: nkit devices --available")

proc cleanCommand*(v: Values) =
  removeDir("build")
  displaySuccess("removed build directory")
