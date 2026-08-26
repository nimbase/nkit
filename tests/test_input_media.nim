import unittest
import std/[os, strutils]

import nkit

suite "image":
  test "from missing file returns nil":
    check fromImageFile("/nonexistent/nope.png").isNil

  test "from base64 round trip":
    let tinyPng = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    let img = fromBase64(tinyPng)
    if not img.isNil:
      check img.exists()
      let s = img.getSize()
      check s.width == 1'f64
      check s.height == 1'f64
      check img.getFormat() == "PNG"
      let b64 = img.toBase64()
      check b64.startsWith("data:image/png;base64,")
      img.free()

  test "data uri prefix stripped":
    let withPrefix = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    let img = fromBase64(withPrefix)
    if not img.isNil:
      check img.exists()
      img.free()

  test "invalid base64 returns nil":
    check fromBase64("!!!definitely not base64!!!").isNil

suite "shortcut validation":
  test "valid accelerators":
    check isValidAccelerator("Ctrl+Shift+A")
    check isValidAccelerator("CmdOrCtrl+N")
    check isValidAccelerator("Alt+F4")
    check isValidAccelerator("F5")
    check isValidAccelerator("Media+Space") == false
    check isValidAccelerator("Ctrl+Num0")
    check isValidAccelerator("cmd+,")
    check isValidAccelerator("Shift+PageDown")
    check isValidAccelerator("a")
    check isValidAccelerator("Ctrl+Alt+Delete")

  test "invalid accelerators":
    check not isValidAccelerator("")
    check not isValidAccelerator("Ctrl")
    check not isValidAccelerator("Ctrl+Shift")
    check not isValidAccelerator("NotAModifier+A")
    check not isValidAccelerator("Ctrl++")
    check not isValidAccelerator("A+B")
    check not isValidAccelerator("Ctrl+F25")

suite "shortcut manager":
  test "singleton and defaults":
    let sm = sharedShortcutManager()
    let again = sharedShortcutManager()
    check cast[pointer](sm) == cast[pointer](again)
    when defined(macosx):
      check sm.isSupported()
    check sm.isEnabled()
    check sm.getAll().len == 0

  test "register rejects invalid accelerator with event":
    let sm = sharedShortcutManager()
    var failed = 0
    discard sm.addListener(proc(e: ShortcutRegistrationFailedEvent) =
      inc failed
      check e.errorMessage == "Invalid accelerator format")
    let sc = sm.register("Bogus+X", proc() = discard)
    discard runMainThreadLoopFor(100)
    check sc.isNil
    check failed == 1
    removeAllListeners(sm, ShortcutRegistrationFailedEvent)

  test "register duplicate rejected":
    let sm = sharedShortcutManager()
    var failedMsgs = newSeq[string]()
    discard sm.addListener(proc(e: ShortcutRegistrationFailedEvent) =
      failedMsgs.add(e.errorMessage))
    let first = sm.register("Ctrl+Alt+T", proc() = discard)
    check not first.isNil
    let dupExact = sm.register("Ctrl+Alt+T", proc() = discard)
    discard runMainThreadLoopFor(150)
    check dupExact.isNil
    check failedMsgs.contains("Accelerator already registered")
    let dupCase = sm.register("ctrl+alt+t", proc() = discard)
    discard runMainThreadLoopFor(150)
    check dupCase.isNil
    check failedMsgs.contains("Platform registration failed")
    check sm.unregisterAll() >= 1
    removeAllListeners(sm, ShortcutRegistrationFailedEvent)

  test "unregister by accelerator and id":
    let sm = sharedShortcutManager()
    let sc = sm.register("Ctrl+Alt+U", proc() = discard)
    if not sc.isNil:
      check not sm.isAvailable("Ctrl+Alt+U")
      check sm.unregisterByAccelerator("Ctrl+Alt+U")
      check sm.isAvailable("Ctrl+Alt+U")
      check not sm.unregisterByAccelerator("Ctrl+Alt+U")

      let sc2 = sm.register("Ctrl+Alt+V", proc() = discard)
      if not sc2.isNil:
        check sm.unregister(sc2.id)
        check not sm.unregister(sc2.id)

  test "get lookups and scope filter":
    let sm = sharedShortcutManager()
    defer:
      discard sm.unregisterAll()
    let global = sm.register(ShortcutOptions(
      accelerator: "Ctrl+Alt+G",
      callback: proc() = discard,
      description: "global one",
      scope: ssGlobal,
      enabled: true))
    let appScoped = sm.register(ShortcutOptions(
      accelerator: "Ctrl+Alt+H",
      callback: proc() = discard,
      description: "app one",
      scope: ssApplication,
      enabled: true))
    if not global.isNil:
      check cast[pointer](sm.get(global.id)) == cast[pointer](global)
      check sm.getByAccelerator("Ctrl+Alt+G").accelerator == "Ctrl+Alt+G"
      check sm.getByScope(ssGlobal).len >= 1
      check global.getDescription() == "global one"
      global.setDescription("renamed")
      check global.getDescription() == "renamed"
    if not appScoped.isNil:
      var inAppScope = false
      for sc in sm.getByScope(ssApplication):
        if sc.id == appScoped.id:
          inAppScope = true
      check inAppScope

suite "keyboard monitor":
  test "start stop lifecycle":
    let km = newKeyboardMonitor()
    let started = km.start()
    if started:
      check km.isMonitoring()
      km.stop()
      check not km.isMonitoring()
      check km.start()
      km.stop()
    else:
      skip()
