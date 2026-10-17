import std/[os, strutils]
import pkg/kapsis
import pkg/kapsis/interactive/prompts
import ./project
import ./ios
import ./assets
import ./scaffold
import ./dmg
import ./pkg

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
  try:
    result = parsePlatform(s)
  except ValueError as e:
    displayError(e.msg, quitProcess = true)

proc resolvePlatform(v: Values): Platform =
  ## Platform for build/run; omitted means the host desktop target.
  if v.has("platform"):
    platformFromValue(v.get("platform").getAny)
  else:
    defaultDesktopPlatform()

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

proc removeLegacyFlatBundle(platform: Platform, outDir,
                              appName: string) =
  ## Drops leftovers of the pre-Contents macOS layout (Info.plist, binary
  ## and Resources at the bundle root) so stale files never shadow the new
  ## Contents/ payload.
  if platform != pfMacos:
    return
  let bundle = appBundlePath(platform, outDir, appName)
  let legacyPlist = bundle / "Info.plist"
  if fileExists(legacyPlist):
    removeFile(legacyPlist)
  let legacyExe = bundle / appName
  if fileExists(legacyExe):
    removeFile(legacyExe)
  let legacyRes = bundle / "Resources"
  if dirExists(legacyRes):
    removeDir(legacyRes)

proc buildCommand*(v: Values) =
  let platform = resolvePlatform(v)
  let pkgman = packageManagerFromValue(v)
  let release = v.has("--release")
  let (cfg, projectDir) = loadCurrentProject()
  setCurrentDir(projectDir)

  let outDir = "build"
  if platform == pfLinux:
    createDir(outDirFor(platform, outDir))
  elif platform == pfMacos:
    # Standard Contents/ layout: the compiler target dir must exist before
    # clue appends the binary name inside it.
    createDir(parentDir(executablePath(platform, outDir, cfg.name)))
    removeLegacyFlatBundle(platform, outDir, cfg.name)
  else:
    createDir(appBundlePath(platform, outDir, cfg.name))

  case platform
  of pfIos:
    displayInfo("resolving iOS Simulator SDK")
    let sdk = resolveSimulatorSdk()
    upsertPlatformConfig(pfIos, cfg, sdk)
    displayInfo("building " & cfg.name & " for iOS Simulator")
    let nimArgs =
      if pkgman == "clue":
        @["-o:\"" & clueBuildTarget(pfIos, outDir, cfg.name) & "\""]
      else:
        composeNimArgs(pfIos, cfg, sdk, outDir, release)
    let cmd = pkgman & " build " & join(nimArgs, " ") & forwardExtras()
    if runStreaming(cmd) != 0:
      displayError("build failed", quitProcess = true)
  of pfMacos:
    upsertPlatformConfig(pfMacos, cfg, "")
    displayInfo("building " & cfg.name & " for macOS")
    let nimArgs =
      if pkgman == "clue":
        @["-o:\"" & clueBuildTarget(pfMacos, outDir, cfg.name) & "\""]
      else:
        composeNimArgs(pfMacos, cfg, "", outDir, release)
    let cmd = pkgman & " build " &
      join(nimArgs, " ") &
      forwardExtras()
    if runStreaming(cmd) != 0:
      displayError("build failed", quitProcess = true)
  of pfLinux:
    upsertPlatformConfig(pfLinux, cfg, "")
    displayInfo("building " & cfg.name & " for Linux")
    let nimArgs =
      if pkgman == "clue":
        @["-o:\"" & clueBuildTarget(pfLinux, outDir, cfg.name) & "\""]
      else:
        composeNimArgs(pfLinux, cfg, "", outDir, release)
    let cmd = pkgman & " build " & join(nimArgs, " ") & forwardExtras()
    if runStreaming(cmd) != 0:
      displayError("build failed", quitProcess = true)

  if platform != pfLinux:
    # Bundle resources (macOS/iOS only): assets land in Resources/
    # preserving their project-relative paths; an icon is installed at
    # the Resources root and published via CFBundleIconFile.
    var iconName = ""
    if cfg.assets.len > 0 or cfg.icon.len > 0:
      let resDir = resourcesDirFor(platform, outDir, cfg.name)
      createDir(resDir)
      if cfg.assets.len > 0:
        try:
          let copied = copyAssets(projectDir, cfg.assets, resDir)
          displayInfo("bundled " & $copied & " asset file(s)")
        except ValueError as e:
          displayError(e.msg, quitProcess = true)
      if cfg.icon.len > 0:
        try:
          iconName = installIcon(projectDir, cfg.icon, resDir)
          displayInfo("set application icon: " & iconName)
        except ValueError as e:
          displayError(e.msg, quitProcess = true)
        except IOError as e:
          displayError(e.msg, quitProcess = true)
        except OSError as e:
          displayError(e.msg, quitProcess = true)
    writeFile(infoPlistPath(platform, outDir, cfg.name),
      renderInfoPlist(cfg.name, cfg.ios.bundle_id, cfg.version, iconName,
        isiOS = platform == pfIos))
    if platform == pfMacos:
      # PkgInfo marks the bundle type/creator (APPL????), like Xcode builds.
      writeFile(contentsDirFor(platform, outDir, cfg.name) / "PkgInfo",
        "APPL????")

  let bundleExe = executablePath(platform, outDir, cfg.name)
  if not fileExists(bundleExe):
    # clue places binaries in a subdirectory under the -o: path;
    # relocate into the bundle ourselves.
    let nested = bundleExe / cfg.name
    if fileExists(nested):
      if dirExists(bundleExe):
        # clue treated the -o: path itself as a directory (macOS target);
        # collapse it so the bundle executable is a file, not a folder.
        let staged = bundleExe & ".bin"
        moveFile(nested, staged)
        removeDir(bundleExe)
        moveFile(staged, bundleExe)
      else:
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
  of pfLinux:
    let bin = executablePath(pfLinux, "build", cfg.name)
    displayInfo("running " & bin)
    if runLinuxApp(bin) != 0:
      displayError("failed to run " & bin, quitProcess = true)

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

proc flagItems(v: Values, names: openArray[string]): seq[string] =
  ## Concatenates the values of a repeatable flag declared under any of
  ## `names`. Kapsis keys values by the spelling used in the declaration, so
  ## a flag exposed as both `-f` and `--file` arrives as two separate lists.
  for name in names:
    if v.has(name):
      result.add v.get(name).getItems

proc bundleCommand*(v: Values) =
  when not defined(macosx):
    displayError("nkit bundle is only supported on macOS", quitProcess = true)
  else:
    # packaging is driven by an .app on disk rather than by nkit.yaml, so it
    # works in any directory holding a built app
    var appBundle =
      if v.has("app"): v.get("app").getFilepath
      else: ""
    var outPath, volName, imageFormat, fs: string
    var entries: seq[VolumeEntry]
    try:
      if appBundle.len == 0:
        appBundle = discoverAppBundle()
      if appBundle.len == 0:
        displayError("no app bundle found under " &
          outDirFor(pfMacos, "build") &
          "; run `nkit build macos` first, or name one: nkit bundle App.app",
          quitProcess = true)
      if not dirExists(appBundle):
        displayError("no app bundle at " & appBundle, quitProcess = true)
      outPath =
        if v.has("--out"): v.get("--out").getStr
        elif v.has("-o"): v.get("-o").getStr
        else: defaultDmgPath(appBundle)
      volName =
        if v.has("--volname"): v.get("--volname").getStr
        else: appNameFrom(appBundle)
      imageFormat = if v.has("--format"): v.get("--format").getAny else: ""
      fs = if v.has("--fs"): v.get("--fs").getAny else: ""
      entries = volumeEntries(appBundle,
        flagItems(v, ["--file", "-f"]), flagItems(v, ["--dir", "-d"]))
    except ValueError as e:
      displayError(e.msg, quitProcess = true)

    let
      appName = appNameFrom(appBundle)
      stageDir = stagePath(parentDir(outPath), appName)

    if v.has("--pkg"):
      # installer packaging is project-driven: identifier and version come
      # from nkit.yaml, so --pkg only works inside a project directory;
      # plain `nkit bundle` keeps working on any .app with no config
      var cfg = ProjectConfig()
      try:
        cfg = loadCurrentProject().cfg
      except IOError:
        displayError("nkit bundle --pkg needs a nkit.yaml for the " &
          "package identifier and version; run it inside a project " &
          "directory (see `nkit init`)", quitProcess = true)
      except ValueError as e:
        displayError(e.msg, quitProcess = true)
      let
        pkgPath = pkgPathFor(outPath, appName)
        signIdentity =
          if v.has("--sign"): v.get("--sign").getStr
          else: ""
      displayInfo("building installer package " & pkgPath)
      if buildPkg(appBundle, cfg.ios.bundle_id, cfg.version, pkgPath,
                   signIdentity) != 0:
        displayError("pkgbuild failed to create " & pkgPath,
          quitProcess = true)
      let pkgLabel = pkgPath.splitPath.tail
      for e in entries:
        if e.label == pkgLabel:
          displayError(pkgLabel & " is provided twice (the installer " &
            "package and " & e.source &
            "); the volume root cannot hold both", quitProcess = true)
      entries.add VolumeEntry(source: pkgPath, label: pkgLabel)
      displayInfo("added " & pkgLabel & " to the volume")

    displayInfo("staging " & $entries.len & " items in " & stageDir)
    discard stageVolume(stageDir, entries, not v.has("--no-applications"))

    displayInfo("creating " & outPath)
    if createDmg(stageDir, volName, outPath, imageFormat, fs) != 0:
      displayError("hdiutil failed to create " & outPath, quitProcess = true)
    displaySuccess("created " & outPath)
    display("mount it with: open " & outPath)

proc cleanCommand*(v: Values) =
  removeDir("build")
  displaySuccess("removed build directory")
