import unittest
import std/[strutils, times, tables]

import nkit

suite "app info":
  test "name falls back to process name":
    let info = sharedAppInfo()
    check info.getName().len > 0
    check info.getIdentifier().len >= 0
    check info.getVersion().len >= 0
    check info.getBuildNumber().len >= 0

suite "device info":
  test "macos identity fields":
    let info = sharedDeviceInfo()
    check info.getName().len > 0
    check info.getModel().len > 0
    check info.getManufacturer() == "Apple"
    check info.getOsName() == "macOS"
    let version = info.getOsVersion()
    check version.len > 0
    check version.count('.') == 2
    check info.getKernelVersion().len > 0
    let arch = info.getArchitecture()
    check arch == "arm64" or arch.startsWith("x86_64")

suite "url opener":
  test "validation matrix":
    let opener = sharedUrlOpener()
    check opener.isSupported()

    var r = opener.open("")
    check not r.success
    check r.errorCode == uoeInvalidUrlEmpty

    r = opener.open("example.com/page")
    check not r.success
    check r.errorCode == uoeInvalidUrlMissingScheme

    r = opener.open("ftp://example.com")
    check not r.success
    check r.errorCode == uoeInvalidUrlUnsupportedScheme

    r = opener.open("HTTP://EXAMPLE.COM")
    check r.success
    check r.errorCode == uoeNone

    r = opener.open("https://example.com")
    check r.success

  test "canOpen mirrors validation":
    let opener = sharedUrlOpener()
    check opener.canOpen("http://x")
    check not opener.canOpen("nope")
    check not opener.canOpen("gopher://x")

suite "preferences":
  test "set get remove contains round trip":
    let scope = "test-" & $now()
    let p = newPreferences(scope)
    defer:
      discard p.clear()
      p.close()

    check not p.contains("alpha")
    check p.set("alpha", "one")
    check p.contains("alpha")
    check p.get("alpha") == "one"
    check p.get("missing", "fallback") == "fallback"
    check p.getSize() >= 1
    check p.getKeys().contains("alpha")
    check p.getAll()["alpha"] == "one"
    check p.remove("alpha")
    check not p.contains("alpha")
    check not p.remove("alpha")

suite "secure storage stub":
  test "mirrors upstream stub behavior":
    let s = newSecureStorage("test")
    check not isAvailable()
    check not s.set("k", "v")
    check s.get("k", "dflt") == "dflt"
    check not s.remove("k")
    check not s.clear()
    check not s.contains("k")
    check s.getKeys().len == 0
    check s.getSize() == 0
    check s.getScope() == "test"

suite "storage polymorphism":
  test "preferences through storage interface":
    let storage: Storage = newPreferences("poly-test")
    check storage.set("a", "b")
    check storage.get("a") == "b"

suite "accessibility":
  test "query does not crash":
    check isAccessibilityEnabled() in {true, false}

suite "launch at login":
  test "defaults detected without crashing":
    let lal = newLaunchAtLogin()
    check lal.getId().len > 0
    check lal.getDisplayName().len > 0
    check lal.getArguments().len == 0

    let custom = newLaunchAtLogin("com.example.custom", "Custom Name")
    check custom.getId() == "com.example.custom"
    check custom.getDisplayName() == "Custom Name"

  test "program guard rejects foreign executables":
    let lal = newLaunchAtLogin()
    discard lal.setProgram("/usr/bin/other", @["--flag"])
    if isSupported():
      check not lal.enable()
      check lal.isEnabled() in {true, false}
