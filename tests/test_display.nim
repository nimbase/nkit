import unittest
import std/math

import nkit

suite "display manager":
  test "singleton identity":
    let a = sharedDisplayManager()
    let b = sharedDisplayManager()
    check cast[pointer](a) == cast[pointer](b)

  test "reconcile keeps instances stable":
    let dm = DisplayManager()
    initEmitter(dm)

    proc fake(keys: varargs[uint32]): seq[NativeDisplayInfo] =
      result = newSeqOfCap[NativeDisplayInfo](keys.len)
      for k in keys:
        result.add(NativeDisplayInfo(key: k, isPrimary: false))

    var added = newSeq[Display]()
    var removed = newSeq[Display]()
    let first = dm.reconcile(fake(1'u32, 2'u32), added, removed)
    check first.len == 2
    check added.len == 2
    check removed.len == 0
    let key1 = first[0]

    added = @[]
    removed = @[]
    let second = dm.reconcile(fake(2'u32), added, removed)
    check second.len == 1
    check added.len == 0
    check removed.len == 1
    check removed[0].id == key1.id

    added = @[]
    removed = @[]
    let third = dm.reconcile(fake(2'u32, 3'u32), added, removed)
    check third.len == 2
    check third[0].id == second[0].id
    check added.len == 1
    check added[0].id == third[1].id
    check removed.len == 0

  test "handleDisplaysChanged emits remove for vanished keys":
    let dm = DisplayManager()
    initEmitter(dm)

    var added = newSeq[Display]()
    var removed = newSeq[Display]()
    discard dm.reconcile(@[NativeDisplayInfo(key: 42'u32, isPrimary: false)], added, removed)
    check added.len == 1

    var removedIds = newSeq[uint32]()
    discard dm.addListener(proc(e: DisplayRemovedEvent) =
      removedIds.add(e.display.nativeKey))

    dm.handleDisplaysChanged()

    check 42'u32 in removedIds

    let current = dm.getAllDisplays()
    for d in current:
      check d.nativeKey != 42'u32

suite "displays live":
  test "enumeration returns at least one display":
    let dm = sharedDisplayManager()
    let displays = dm.getAllDisplays()
    check displays.len >= 1

  test "instances are stable across enumerations":
    let dm = sharedDisplayManager()
    let a = dm.getAllDisplays()
    let b = dm.getAllDisplays()
    check a.len == b.len
    if a.len > 0:
      check cast[pointer](a[0]) == cast[pointer](b[0])

  test "primary display exists and is primary":
    let dm = sharedDisplayManager()
    let primary = dm.getPrimaryDisplay()
    check primary != nil
    check primary.isPrimary()
    check primary.getSize().width > 0
    check primary.getSize().height > 0
    check primary.getWorkArea().width <= primary.getSize().width
    check primary.getName().len > 0
    check primary.getRefreshRate() > 0
    check primary.getBitDepth() == 32
    check primary.getScaleFactor() >= 1.0

  test "cursor position is finite":
    let p = sharedDisplayManager().getCursorPosition()
    check p.x.classify != fcNaN
    check p.y.classify != fcNaN
