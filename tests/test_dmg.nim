import std/[unittest, os, strutils]
import std/symlinks
import nkit/cli/dmg

## Unit tests for the pure builders behind `nkit bundle`. Nothing here runs
## hdiutil; the staging step itself is covered manually on macOS.

proc rejects(body: proc ()): bool =
  ## True when `body` refuses its input with a ValueError
  try:
    body()
    false
  except ValueError:
    true

suite "volume entries":
  # a small fixture tree so the existence checks inside `volumeEntries`
  # have something real to look at
  let tmp = getTempDir() / "nkit_dmg_entries_test"
  setup:
    removeDir(tmp)
    createDir(tmp / "Demo.app")
    createDir(tmp / "docs")
    createDir(tmp / "licenses")
    createDir(tmp / "one")
    createDir(tmp / "two")
    writeFile(tmp / "README.md", "readme")
    writeFile(tmp / "LICENSE.txt", "license")
    writeFile(tmp / "licenses" / "MIT", "mit")
    writeFile(tmp / "one" / "README.md", "one")
    writeFile(tmp / "two" / "README.md", "two")
    createDir(tmp / "other")
    writeFile(tmp / "other" / "Demo.app", "decoy")
  teardown:
    removeDir(tmp)

  test "the app bundle comes first, keeping its extension":
    let entries = volumeEntries(tmp / "Demo.app", @[], @[])
    check entries.len == 1
    check entries[0].source == (tmp / "Demo.app").string
    check entries[0].label == "Demo.app"

  test "extra files keep their extension":
    let entries = volumeEntries(tmp / "Demo.app",
      @[(tmp / "README.md").string, (tmp / "LICENSE.txt").string], @[])
    check entries[1].label == "README.md"
    check entries[2].label == "LICENSE.txt"

  test "extra directories are added after files":
    let entries = volumeEntries(tmp / "Demo.app",
      @[(tmp / "README.md").string], @[(tmp / "docs").string])
    check entries.len == 3
    check entries[1].label == "README.md"
    check entries[2].label == "docs"

  test "a missing file is rejected":
    check rejects(proc () =
      discard volumeEntries((tmp / "Demo.app").string,
        @[(tmp / "nope.txt").string], @[]))

  test "a directory passed as a file is rejected":
    check rejects(proc () =
      discard volumeEntries((tmp / "Demo.app").string, @[(tmp / "docs").string], @[]))

  test "a file passed as a directory is rejected":
    check rejects(proc () =
      discard volumeEntries((tmp / "Demo.app").string, @[],
        @[(tmp / "README.md").string]))

  test "two extras claiming the same name are rejected":
    # the collision is on the basename, so the same file may be added twice
    # from different directories but two different files sharing a basename
    # may not
    check rejects(proc () =
      discard volumeEntries((tmp / "Demo.app").string,
        @[(tmp / "one" / "README.md").string, (tmp / "two" / "README.md").string], @[]))

  test "an extra clashing with the app name is rejected":
    check rejects(proc () =
      discard volumeEntries((tmp / "Demo.app").string,
        @[(tmp / "other" / "Demo.app").string], @[]))

suite "app bundle naming":
  test "the extension is dropped from a bundle name":
    check appNameFrom("build/macos/Demo.app") == "Demo"
    check appNameFrom("/a/b/Some App.app") == "Some App"

  test "a bundle without the extension is taken as-is":
    check appNameFrom("build/macos/Demo") == "Demo"

  test "the extension is matched without regard to case":
    check appNameFrom("build/macos/Demo.APP") == "Demo"

  test "a dotted name only loses its last extension":
    check appNameFrom("build/macos/My.App.v1.app") == "My.App.v1"

suite "app bundle discovery":
  test "nothing is found in a directory without a build":
    let tmp = getTempDir() / "nkit_dmg_find_none"
    removeDir(tmp)
    try:
      check discoverAppBundle(tmp) == ""
    finally:
      removeDir(tmp)

  test "nothing is found when the build directory is empty":
    let tmp = getTempDir() / "nkit_dmg_find_empty"
    removeDir(tmp)
    createDir(tmp / "macos")
    try:
      check discoverAppBundle(tmp) == ""
    finally:
      removeDir(tmp)

  test "the single bundle under build/macos is found":
    let tmp = getTempDir() / "nkit_dmg_find_one"
    removeDir(tmp)
    createDir(tmp / "macos" / "Demo.app")
    try:
      check discoverAppBundle(tmp) == (tmp / "macos" / "Demo.app").string
    finally:
      removeDir(tmp)

  test "several bundles are refused rather than guessed between":
    let tmp = getTempDir() / "nkit_dmg_find_many"
    removeDir(tmp)
    createDir(tmp / "macos" / "Demo.app")
    createDir(tmp / "macos" / "Other.app")
    try:
      check rejects(proc () = discard discoverAppBundle(tmp))
    finally:
      removeDir(tmp)

suite "dmg paths":
  test "the staging directory sits beside the image":
    check stagePath("build/macos", "Demo") == "build/macos/.bundle/Demo"

  test "the image lands beside the app it was built from":
    check defaultDmgPath("build/macos/Demo.app") == "build/macos/Demo.dmg"

  test "a bundle outside the build directory still works":
    check defaultDmgPath("/tmp/scratch/Some App.app") ==
      "/tmp/scratch/Some App.dmg"

suite "hdiutil arguments":
  test "format and filesystem are left to hdiutil when unset":
    let args = composeDmgArgs("build/.bundle/Demo", "Demo",
      "build/macos/Demo.dmg")
    check "-srcfolder \"build/.bundle/Demo\"" in args
    check "-volname \"Demo\"" in args
    check args.endsWith("\"build/macos/Demo.dmg\"")
    check "-format" notin args
    check "-fs " notin args

  test "an explicit format and filesystem are passed through":
    let args = composeDmgArgs("stage", "Demo", "out.dmg", "ULFO", "HFS+")
    check "-format ULFO" in args
    check "-fs \"HFS+\"" in args

  test "the existing image is overwritten":
    check "-ov" in composeDmgArgs("stage", "Demo", "out.dmg")

  test "ownership prompts are suppressed":
    # hdiutil asks for authentication when the source holds a file it cannot
    # attribute to the current user, which would hang a build
    check "-anyowners" in composeDmgArgs("stage", "Demo", "out.dmg")

  test "paths with spaces stay quoted":
    let args = composeDmgArgs("/tmp/My Stage", "My App",
      "/tmp/My App/Demo.dmg")
    check "-srcfolder \"/tmp/My Stage\"" in args
    check "-volname \"My App\"" in args
    check args.endsWith("\"/tmp/My App/Demo.dmg\"")

suite "output directory":
  test "a missing parent directory is created for the image":
    let tmp = getTempDir() / "nkit_dmg_outdir_test"
    removeDir(tmp)
    try:
      ensureParentDir(tmp / "nested" / "deeper" / "out.dmg")
      check dirExists(tmp / "nested" / "deeper")
    finally:
      removeDir(tmp)

  test "an existing parent directory is left alone":
    let tmp = getTempDir() / "nkit_dmg_outdir_existing_test"
    removeDir(tmp)
    createDir(tmp)
    try:
      ensureParentDir(tmp / "out.dmg")
      ensureParentDir(tmp / "out.dmg")
      check dirExists(tmp)
    finally:
      removeDir(tmp)

suite "dmg constants":
  test "the offered formats and filesystems match hdiutil":
    check "ULFO" in DmgFormatChoices
    check "UDZO" in DmgFormatChoices
    check "HFS+" in DmgFsChoices
    check "APFS" in DmgFsChoices

  test "the Applications shortcut is named as Finder expects":
    check ApplicationsLink == "Applications"

suite "staging":
  test "a volume is assembled with the shortcut in place":
    let tmp = getTempDir() / "nkit_dmg_test"
    removeDir(tmp)
    createDir(tmp / "payload")
    writeFile(tmp / "payload" / "README.md", "hi")
    try:
      let stage = tmp / "stage"
      let written = stageVolume(stage, @[
        VolumeEntry(source: tmp / "payload", label: "Demo.app"),
        VolumeEntry(source: tmp / "payload" / "README.md",
          label: "README.md")])
      check written.len == 3
      check dirExists(stage / "Demo.app")
      check fileExists(stage / "README.md")
      check not symlinkExists(stage / "Demo.app")
      check symlinkExists(stage / ApplicationsLink)
      check (stage / ApplicationsLink).expandSymlink().string == "/Applications"
    finally:
      removeDir(tmp)

  test "staging replaces whatever was there before":
    let tmp = getTempDir() / "nkit_dmg_stale_test"
    removeDir(tmp)
    createDir(tmp)
    writeFile(tmp / "stale.txt", "old")
    try:
      let stage = tmp / "stage"
      createDir(stage)
      writeFile(stage / "stale.txt", "old")
      discard stageVolume(stage, @[
        VolumeEntry(source: tmp / "stale.txt", label: "README.md")])
      check not fileExists(stage / "stale.txt")
      check fileExists(stage / "README.md")
    finally:
      removeDir(tmp)

  test "the Applications shortcut can be left out":
    let tmp = getTempDir() / "nkit_dmg_nolink_test"
    removeDir(tmp)
    createDir(tmp)
    writeFile(tmp / "a.txt", "a")
    try:
      let stage = tmp / "stage"
      discard stageVolume(stage,
        @[VolumeEntry(source: tmp / "a.txt", label: "a.txt")],
        applicationsLink = false)
      check fileExists(stage / "a.txt")
      check not symlinkExists(stage / ApplicationsLink)
    finally:
      removeDir(tmp)