import unittest
import nkit/gui/animate
import nkit/gui/view
import nkit/foundation/geometry
import nkit/foundation/dispatcher

suite "animations":
  test "animate drives progress from 0 to completion":
    let v = newPlainView()
    defer:
      destroy(v)
    var calls = 0
    var lastProgress = -1.0
    animate(v, 60, linear, proc(view: View, p: float64) =
      calls += 1
      lastProgress = p)
    discard runMainThreadLoopFor(400)
    check calls >= 2
    check lastProgress == 1.0

  test "easing stays within [0, 1]":
    for t in @[0.0, 0.25, 0.5, 0.75, 1.0]:
      check easeInOut(t) >= 0.0 and easeInOut(t) <= 1.0
      check easeOut(t) >= 0.0 and easeOut(t) <= 1.0

  test "fade in restores alpha to one":
    let v = newPlainView()
    defer:
      destroy(v)
    v.setAlpha(0.0)
    fadeIn(v, 50)
    discard runMainThreadLoopFor(300)
    check v.getAlpha() > 0.9

  test "moveTo lands on the target frame":
    let host = newPlainView()
    setFrameRect(host, rectangle(0.0, 0.0, 500.0, 400.0))
    let child = newPlainView()
    addSubview(host, child)
    setFrameRect(child, rectangle(10.0, 10.0, 40.0, 40.0))
    moveTo(child, 200.0, 300.0, 60)
    discard runMainThreadLoopFor(400)
    let f = child.getFrameRect()
    check f.x == 200.0
    check f.y == 300.0
    check f.width == 40.0

  test "resizeTo reaches the requested size":
    let v = newPlainView()
    setFrameRect(v, rectangle(0.0, 0.0, 30.0, 30.0))
    defer:
      destroy(v)
    resizeTo(v, 120.0, 80.0, 50)
    discard runMainThreadLoopFor(350)
    let f = v.getFrameRect()
    check f.width == 120.0
    check f.height == 80.0
