import std/[unittest, os, strutils]
import nkit/cli/assets
import nkit/cli/ios
import nkit/cli/project

## Unit tests for app resources: nkit.yaml assets/icon parsing, bundle
## copying, icon validation and the CFBundleIconFile plist entry. Nothing
## here shells out; iconutil conversion is covered manually on macOS.

proc rejects(body: proc ()): bool =
  ## True when `body` refuses its input with a ValueError
  try:
    body()
    false
  except ValueError:
    true

const LegacyYaml = """name: "Demo"
version: "1.2.3"
description: "legacy app"
author: "me"

dependencies:
  nkit: ">= 0.1.0"

ios:
  bundle_id: com.example.demo
  min_version: "15.0"
"""

const AssetsYaml = LegacyYaml & """
assets:
  - assets/images
  - assets/data/scores.csv
icon: assets/icon/AppIcon.icns
"""

suite "project config resources":
  test "legacy configs parse with empty assets and icon":
    let cfg = parseProjectConfig(LegacyYaml)
    check cfg.name == "Demo"
    check cfg.assets.len == 0
    check cfg.icon == ""

  test "assets list and icon parse from yaml":
    let cfg = parseProjectConfig(AssetsYaml)
    check cfg.assets == @["assets/images", "assets/data/scores.csv"]
    check cfg.icon == "assets/icon/AppIcon.icns"

suite "resources dir":
  test "macos uses Contents/Resources, ios stays flat":
    check resourcesDirFor(pfMacos, "build", "Demo") ==
      "build" / "macos" / "Demo.app" / "Contents" / "Resources"
    check resourcesDirFor(pfIos, "build", "Demo") ==
      "build" / "ios-simulator" / "Demo.app" / "Resources"

suite "copy assets":
  let tmp = getTempDir() / "nkit_assets_test"
  setup:
    removeDir(tmp)
    createDir(tmp / "proj" / "assets" / "images" / "nested")
    createDir(tmp / "proj" / "assets" / "data")
    writeFile(tmp / "proj" / "assets" / "images" / "logo.png", "png")
    writeFile(tmp / "proj" / "assets" / "images" / "nested" / "bg.png",
      "bg")
    writeFile(tmp / "proj" / "assets" / "data" / "scores.csv", "csv")
    writeFile(tmp / "proj" / "top.txt", "top")
    createDir(tmp / "dest")
  teardown:
    removeDir(tmp)

  test "directories copy preserving relative paths":
    let n = copyAssets(tmp / "proj", @["assets/images"],
      tmp / "dest")
    check n == 2
    check readFile(tmp / "dest" / "assets" / "images" / "logo.png") ==
      "png"
    check readFile(tmp / "dest" / "assets" / "images" / "nested" /
      "bg.png") == "bg"

  test "a lone file entry copies as-is":
    let n = copyAssets(tmp / "proj", @["top.txt"], tmp / "dest")
    check n == 1
    check readFile(tmp / "dest" / "top.txt") == "top"

  test "a missing source is rejected":
    check rejects(proc () =
      discard copyAssets(tmp / "proj", @["assets/nope"], tmp / "dest"))

  test "absolute paths are rejected":
    check rejects(proc () =
      discard copyAssets(tmp / "proj", @["/etc/hosts"], tmp / "dest"))

  test "escapes above the project root are rejected":
    check rejects(proc () =
      discard copyAssets(tmp / "proj", @["../outside"], tmp / "dest"))

suite "app icon":
  let tmp = getTempDir() / "nkit_icon_test"
  setup:
    removeDir(tmp)
    createDir(tmp / "proj" / "assets" / "icon")
    createDir(tmp / "proj" / "assets" / "icon" / "AppIcon.iconset")
    writeFile(tmp / "proj" / "assets" / "icon" / "AppIcon.icns", "icns")
    writeFile(tmp / "proj" / "assets" / "icon" / "logo.png", "png")
    createDir(tmp / "dest")
  teardown:
    removeDir(tmp)

  test "a .icns file yields its bare name":
    check iconPlistName(tmp / "proj",
      "assets/icon/AppIcon.icns") == "AppIcon"

  test "an .iconset directory yields its bare name":
    check iconPlistName(tmp / "proj",
      "assets/icon/AppIcon.iconset") == "AppIcon"

  test "other files are rejected":
    check rejects(proc () =
      discard iconPlistName(tmp / "proj", "assets/icon/logo.png"))

  test "a missing icon is rejected":
    check rejects(proc () =
      discard iconPlistName(tmp / "proj", "assets/icon/Missing.icns"))

  test "install copies the .icns to the Resources root":
    let name = installIcon(tmp / "proj", "assets/icon/AppIcon.icns",
      tmp / "dest")
    check name == "AppIcon"
    check readFile(tmp / "dest" / "AppIcon.icns") == "icns"

suite "info plist icon":
  test "CFBundleIconFile appears only when an icon is set":
    let withIcon = renderInfoPlist("Demo", "com.example.demo", "1.0",
      "AppIcon")
    check "<key>CFBundleIconFile</key>" in withIcon
    check "<string>AppIcon</string>" in withIcon
    let without = renderInfoPlist("Demo", "com.example.demo", "1.0")
    check "<key>CFBundleIconFile</key>" notin without
    # existing keys are untouched
    check "<string>com.example.demo</string>" in without
