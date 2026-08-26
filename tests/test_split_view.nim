import unittest
import nkit/gui/split_view
import nkit/foundation/geometry
import nkit/foundation/dispatcher
import nkit/gui/view
import nkit/gui/label

suite "split view":
  test "panes register in order":
    let sv = newVerticalSplitView()
    defer:
      destroy(sv)
    let left = newPlainView()
    let right = newPlainView()
    addPane(sv, left)
    addPane(sv, right)
    check paneCount(sv) == 2

  test "divider position set/get round-trip":
    let host = newPlainView()
    setFrameRect(host, rectangle(0.0, 0.0, 400.0, 300.0))
    let sv = newVerticalSplitView()
    addSubview(host, View(sv))
    fillParent(View(sv))
    let a = newLabel("A")
    let b = newLabel("B")
    addPane(sv, a)
    addPane(sv, b)
    layoutNow(host)
    discard runMainThreadLoopFor(120)
    check setPosition(sv, 0, 150.0)
    check getPosition(sv, 0) > 100.0 and getPosition(sv, 0) < 200.0
    # out-of-range divider is rejected
    check setPosition(sv, 5, 10.0) == false

  test "holding priorities apply without error":
    let sv = newHorizontalSplitView()
    defer:
      destroy(sv)
    addPane(sv, newPlainView())
    addPane(sv, newPlainView())
    setHoldingPriority(sv, 0, 260.0)
    setHoldingPriority(sv, 1, 250.0)
    check paneCount(sv) == 2
