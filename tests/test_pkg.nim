import std/[unittest, os, strutils]
import nkit/cli/pkg

## Unit tests for the pure builders behind `nkit bundle --pkg`. Nothing
## here runs pkgbuild; installer creation itself is covered manually and
## end to end on macOS.

suite "pkg paths":
  test "the installer lands beside the disk image":
    check pkgPathFor("build/macos/Demo.dmg", "Demo") ==
      "build/macos/Demo.pkg"

  test "a redirected image keeps the installer next to it":
    check pkgPathFor("/tmp/scratch/Demo.dmg", "Demo") ==
      "/tmp/scratch/Demo.pkg"

  test "the install location is /Applications":
    check PkgInstallLocation == "/Applications"

suite "pkgbuild arguments":
  test "a component package carries identifier and version":
    let args = composePkgArgs("build/macos/Demo.app",
      "com.example.demo", "0.1.0", "build/macos/Demo.pkg")
    check args.startsWith("pkgbuild ")
    check "--component \"build/macos/Demo.app\"" in args
    check "--install-location \"/Applications\"" in args
    check "--identifier \"com.example.demo\"" in args
    check "--version \"0.1.0\"" in args
    check args.endsWith("\"build/macos/Demo.pkg\"")

  test "an unsigned package has no sign flag":
    check "--sign" notin composePkgArgs("Demo.app", "com.example.demo",
      "0.1.0", "Demo.pkg")

  test "a named identity is passed through to pkgbuild":
    let args = composePkgArgs("Demo.app", "com.example.demo", "0.1.0",
      "Demo.pkg", "Developer ID Installer: Example")
    check "--sign \"Developer ID Installer: Example\"" in args

  test "paths with spaces stay quoted":
    let args = composePkgArgs("/tmp/My App/Demo.app", "com.example.demo",
      "0.1.0", "/tmp/My App/Demo.pkg")
    check "--component \"/tmp/My App/Demo.app\"" in args
    check args.endsWith("\"/tmp/My App/Demo.pkg\"")
