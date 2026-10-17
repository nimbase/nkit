import std/[unittest, os, strutils]
import nkit/cli/ios
import nkit/cli/assets

## Unit tests for CLI platform resolution and clue output targets.
## Pure filesystem-free checks; nothing here shells out to xcrun or nimble.

suite "default desktop platform":
  test "omitted platform falls back to the host desktop target":
    when defined(linux):
      check parsePlatform("") == pfLinux
      check defaultDesktopPlatform() == pfLinux
    else:
      check parsePlatform("") == pfMacos
      check defaultDesktopPlatform() == pfMacos

suite "parse platform":
  test "explicit values map to their targets":
    check parsePlatform("ios") == pfIos
    check parsePlatform("macos") == pfMacos
    check parsePlatform("linux") == pfLinux

  test "unknown values raise ValueError":
    var raised = false
    try:
      discard parsePlatform("windows")
    except ValueError:
      raised = true
    check raised

suite "clue build target":
  test "macos receives Contents/MacOS (clue appends the binary)":
    check clueBuildTarget(pfMacos, "build", "demo") ==
      "build" / "macos" / "demo.app" / "Contents" / "MacOS"

  test "ios receives the bundle path (clue appends the binary)":
    check clueBuildTarget(pfIos, "build", "demo") ==
      "build" / "ios-simulator" / "demo.app"

  test "linux receives the plain output dir":
    check clueBuildTarget(pfLinux, "build", "demo") ==
      "build" / "linux"

suite "macos bundle layout":
  test "executable, plist and resources live under Contents":
    check executablePath(pfMacos, "build", "demo") ==
      "build" / "macos" / "demo.app" / "Contents" / "MacOS" / "demo"
    check infoPlistPath(pfMacos, "build", "demo") ==
      "build" / "macos" / "demo.app" / "Contents" / "Info.plist"
    check resourcesDirFor(pfMacos, "build", "demo") ==
      "build" / "macos" / "demo.app" / "Contents" / "Resources"

  test "ios bundle stays flat":
    check executablePath(pfIos, "build", "demo") ==
      "build" / "ios-simulator" / "demo.app" / "demo"
    check infoPlistPath(pfIos, "build", "demo") ==
      "build" / "ios-simulator" / "demo.app" / "Info.plist"
    check resourcesDirFor(pfIos, "build", "demo") ==
      "build" / "ios-simulator" / "demo.app" / "Resources"

suite "info plist":
  test "macos plist has icon entry and no iOS-only keys":
    let plist = renderInfoPlist("demo", "com.example.demo", "1.0",
      "demo", isiOS = false)
    check "CFBundleIconFile" in plist
    check "LSRequiresIPhoneOS" notin plist

  test "ios plist keeps the iOS-only keys":
    let plist = renderInfoPlist("demo", "com.example.demo", "1.0", "demo")
    check "LSRequiresIPhoneOS" in plist
