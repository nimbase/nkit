import unittest

import nkit
import nkit/gui/colorwell
import nkit/gui/sugar

suite "colorwell":
  test "create with initial color":
    let w = newColorWell(color(20, 0x48, 0xca))
    defer:
      destroy(w)
    check getColor(w) == color(20, 0x48, 0xca)

  test "set and get round trip":
    let w = newColorWell()
    defer:
      destroy(w)
    w.setColor(color(59, 0x3b, 0xa7))
    check getColor(w) == color(59, 0x3b, 0xa7)
    w.setColor(color(10, 20, 30, 128))
    let got = getColor(w)
    check got.r == 10
    check got.g == 20
    check got.b == 30
    check got.a == 128

  test "enabled state":
    let w = newColorWell()
    defer:
      destroy(w)
    check w.isEnabled()
    w.setEnabled(false)
    check not w.isEnabled()
    w.setEnabled(true)
    check w.isEnabled()

  test "change event routes through pipeline":
    let w = newColorWell(color(255, 0, 0))
    defer:
      destroy(w)
    var got = 0
    var gotColor = color(0, 0, 0, 0)
    discard onColorChanged(w, proc(e: ColorChangedEvent) =
      inc got
      gotColor = e.color
      check e.colorId == w.id)
    w.setColor(color(0, 255, 0))
    fireChange(w)
    discard runMainThreadLoopFor(100)
    check got == 1
    check gotColor == color(0, 255, 0)

  test "sugar constructor and node wiring":
    var node = colorwell(color(1, 2, 3))
    let w = ColorWell(node.view)
    defer:
      destroy(w)
    check getColor(w) == color(1, 2, 3)
    var changes = 0
    discard onColorChanged(node, proc(e: ColorChangedEvent) =
      inc changes)
    fireChange(w)
    discard runMainThreadLoopFor(100)
    check changes == 1
