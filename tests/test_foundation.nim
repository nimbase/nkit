import unittest
import std/monotimes

import nkit

suite "geometry":
  test "constructors":
    let p = point(1.5, 2.5)
    check p.x == 1.5 and p.y == 2.5
    let s = size(10, 20)
    check s.width == 10 and s.height == 20
    let r = rectangle(0, 0, 100, 200)
    check r.width == 100 and r.height == 200

suite "color":
  test "fromHex formats":
    check colorFromHex("#FFF") == Color(r: 255, g: 255, b: 255, a: 255)
    check colorFromHex("F00") == Color(r: 255, g: 0, b: 0, a: 255)
    check colorFromHex("#F0FA") == Color(r: 255, g: 0, b: 255, a: 170)
    check colorFromHex("#00FF00") == Color(r: 0, g: 255, b: 0, a: 255)
    check colorFromHex("FF000080") == Color(r: 255, g: 0, b: 0, a: 128)

  test "invalid input raises":
    expect ValueError:
      discard colorFromHex("12345")
    expect ValueError:
      discard colorFromHex("GGGGGG")
    expect ValueError:
      discard colorFromHex("12Z")

  test "packed conversions":
    check toRgba(colorRed) == 0xFF0000FF'u32
    check toArgb(colorRed) == 0xFFFF0000'u32

  test "constants":
    check colorTransparent.a == 0
    check colorBlack == Color(r: 0, g: 0, b: 0, a: 255)

suite "keyboard":
  test "modifier combination":
    let mods = modCtrl or modShift
    check mods.hasMods(modCtrl)
    check mods.hasMods(modShift)
    check not mods.hasMods(modAlt)

  test "accelerator toString":
    check keyboardAccelerator("").toString() == ""
    check keyboardAccelerator("S", modCtrl).toString() == "Ctrl+S"
    when defined(macosx):
      check keyboardAccelerator("A", modCtrl or modShift or modMeta).toString() == "Ctrl+Shift+Cmd+A"
    else:
      check keyboardAccelerator("A", modCtrl or modShift or modMeta).toString() == "Ctrl+Shift+Super+A"
    check keyboardAccelerator("F4", modAlt).toString() == "Alt+F4"

  test "isEmpty":
    check keyboardAccelerator("", modCtrl).isEmpty
    check not keyboardAccelerator("X").isEmpty

suite "events":
  test "type names":
    check newKeyPressedEvent(65).typeName() == "KeyPressedEvent"
    check newKeyReleasedEvent(65).typeName() == "KeyReleasedEvent"
    check newModifierKeysChangedEvent(3).typeName() == "ModifierKeysChangedEvent"

  test "subtype relationships":
    let e = newKeyPressedEvent(42)
    check e of KeyboardEvent
    check e of Event
    check KeyboardEvent(e).keycode == 42

suite "id allocator":
  test "layout round trip":
    let id = allocate(typeTagWindow)
    check id.isValid()
    check id.getType() == typeTagWindow
    let (t, s) = id.decompose()
    check t == typeTagWindow
    check s >= 1'u32

  test "uniqueness per type":
    resetCounter(typeTagMenu)
    let a = allocate(typeTagMenu)
    let b = allocate(typeTagMenu)
    check a != b
    check getSequence(a) == 1'u32
    check getSequence(b) == 2'u32

  test "invalid id":
    check not idInvalid.isValid()

suite "object registry":
  type Thing = ref object
    v: int

  test "add get remove":
    let reg = newObjectRegistry[Thing]()
    let a = Thing(v: 1)
    let b = Thing(v: 2)
    reg.add(100'u32, a)
    reg.add(200'u32, b)
    check reg.len == 2
    check reg.contains(100'u32)
    check reg.get(100'u32) == a
    check not reg.contains(300'u32)
    check reg.remove(100'u32)
    check not reg.remove(100'u32)
    check reg.len == 1

  test "replace and clear":
    let reg = newObjectRegistry[Thing]()
    reg.add(7'u32, Thing(v: 1))
    reg.add(7'u32, Thing(v: 99))
    check reg.get(7'u32).v == 99
    check reg.getAll().len == 1
    reg.clear()
    check reg.len == 0

type
  TestEvent* = ref object of Event
  DerivedEvent* = ref object of TestEvent
    value*: int

method typeName(e: TestEvent): string = "TestEvent"
method typeName(e: DerivedEvent): string = "DerivedEvent"

proc newTestEvent(): TestEvent =
  var e = TestEvent()
  e.timestamp = getMonoTime()
  e

proc newDerivedEvent(value: int): DerivedEvent =
  var e = DerivedEvent(value: value)
  e.timestamp = getMonoTime()
  e

suite "event emitter":

  test "callback in registration order":
    let em = EventEmitter[TestEvent]()
    initEmitter(em)
    var order = newSeq[int]()
    let l1 = em.addListener(proc(e: TestEvent) = order.add(1))
    discard em.addListener(proc(e: TestEvent) = order.add(2))
    em.emit(newTestEvent())
    check order == @[1, 2]
    check em.removeListener(l1)

  test "subtype dispatch":
    let em = EventEmitter[TestEvent]()
    initEmitter(em)
    var baseHits, derivedHits = 0
    discard em.addListener(proc(e: TestEvent) = inc baseHits)
    discard em.addListener(proc(e: DerivedEvent) = derivedHits += e.value)
    em.emit(newTestEvent())
    check baseHits == 1
    check derivedHits == 0
    em.emit(newDerivedEvent(5))
    check baseHits == 2
    check derivedHits == 5

  test "remove inside callback tombstones":
    let em = EventEmitter[TestEvent]()
    initEmitter(em)
    var hits = 0
    var lid: ListenerId
    lid = em.addListener(proc(e: TestEvent) =
      inc hits
      doAssert(em.removeListener(lid)))
    em.emit(newTestEvent())
    em.emit(newTestEvent())
    check hits == 1
    check not em.removeListener(lid)

  test "listener lifecycle hooks fire on transitions":
    let em = EventEmitter[TestEvent]()
    initEmitter(em)
    var starts, stops = 0
    em.onStartListening = proc() = inc starts
    em.onStopListening = proc() = inc stops
    let l1 = em.addListener(proc(e: TestEvent) = discard)
    check starts == 1
    let l2 = em.addListener(proc(e: TestEvent) = discard)
    check starts == 1
    discard l2
    check em.removeListener(l2)
    check stops == 0
    check em.removeListener(l1)
    check stops == 1

  test "counts":
    let em = EventEmitter[TestEvent]()
    initEmitter(em)
    discard em.addListener(proc(e: TestEvent) = discard)
    discard em.addListener(proc(e: TestEvent) = discard)
    discard em.addListener(proc(e: DerivedEvent) = discard)
    check em.totalListenerCount() == 3
    check em.listenerCount(TestEvent) == 2
    check em.listenerCount(DerivedEvent) == 1
    check em.hasListeners(DerivedEvent)
    removeAllListeners(em, DerivedEvent)
    check em.totalListenerCount() == 2
    em.clearListeners()
    check em.totalListenerCount() == 0
    check not em.hasListeners(TestEvent)

suite "positioning strategy":
  test "absolute":
    let s = absoluteStrategy(point(100, 200))
    check s.kind == pstAbsolute
    check s.resolvePoint() == point(100, 200)

  test "relative rect with offset":
    let s = relativeStrategy(rectangle(10, 20, 300, 400), point(5, 15))
    check s.getRelativeRectangle().x == 10
    check s.resolvePoint() == point(15, 35)

  test "lazy resolver":
    var bounds = rectangle(0, 0, 50, 50)
    let s = relativeStrategy(proc(): Rectangle = bounds)
    check s.getRelativeRectangle().width == 50
    bounds = rectangle(0, 0, 500, 500)
    check s.getRelativeRectangle().width == 500

suite "dispatcher":
  test "main thread detection":
    check isMainThread()
    setMainThread()
    check isMainThread()

  test "queued work runs via loop":
    var ran = false
    check runOnMainThread(proc() = ran = true)
    check not ran
    check runMainThreadLoopFor(100)
    check ran
