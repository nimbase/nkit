import unittest
import std/math
import nkit/gui/layout_core

type FakeLeaf* = ref object of LayoutNode
  desired: Size

proc fakeLeaf*(w: float64, h: float64): LayoutNode =
  let n = FakeLeaf(desired: size(w, h))
  discard initNode(n, likLeaf)
  result = n

method measureSelf*(n: FakeLeaf, maxWidth: float64, maxHeight: float64): Size =
  n.desired

func childAt(n: LayoutNode, i: int): LayoutNode =
  n.children[i]

func near(a, b: float64): bool =
  abs(a - b) < 0.01

suite "layout solver: measure":
  test "row intrinsic sums children plus spacing":
    let r = newRow(fakeLeaf(100, 20), fakeLeaf(50, 30)).spacing(10.0)
    let s = measure(r, 1000, 1000)
    check near(s.width, 160.0)
    check near(s.height, 30.0)

  test "column intrinsic stacks children plus spacing":
    let c = newColumn(fakeLeaf(100, 20), fakeLeaf(100, 30)).spacing(5.0)
    let s = measure(c, 1000, 1000)
    check near(s.height, 55.0)
    check near(s.width, 100.0)

  test "flex children contribute zero intrinsic main size":
    let r = newRow(fakeLeaf(100, 20), newExpanded(fakeLeaf(50, 30)))
    let s = measure(r, 1000, 1000)
    check near(s.width, 100.0)

  test "padding wraps child measurement":
    let p = newPadding(fakeLeaf(80, 40), 10.0)
    let s = measure(p, 1000, 1000)
    check near(s.width, 100.0)
    check near(s.height, 60.0)

  test "sized box fixes dimensions":
    let b = newSizedBox(200.0, 50.0, fakeLeaf(80, 40))
    let s = measure(b, 1000, 1000)
    check near(s.width, 200.0)
    check near(s.height, 50.0)

  test "empty sized box is a gap":
    let g = newSizedBox(12.0, 0.0)
    let s = measure(g, 1000, 1000)
    check near(s.width, 12.0)
    check near(s.height, 0.0)

suite "layout solver: place":
  test "row start alignment places children left to right with spacing":
    let r = newRow(fakeLeaf(100, 20), fakeLeaf(50, 30)).spacing(10.0)
    computeLayout(r, size(400, 100))
    check near(childAt(r, 0).frame.x, 0.0)
    check near(childAt(r, 1).frame.x, 110.0)
    check near(childAt(r, 0).frame.width, 100.0)

  test "row center alignment offsets by leftover":
    let r = newRow(fakeLeaf(100, 20)).mainAlign(maCenter)
    computeLayout(r, size(400, 100))
    check near(childAt(r, 0).frame.x, 150.0)

  test "row end alignment pushes to right edge":
    let r = newRow(fakeLeaf(100, 20)).mainAlign(maEnd)
    computeLayout(r, size(400, 100))
    check near(childAt(r, 0).frame.x, 300.0)

  test "space between spreads leftover into gaps":
    let r = newRow(fakeLeaf(100, 20), fakeLeaf(100, 20), fakeLeaf(100, 20)).
                   mainAlign(maSpaceBetween)
    computeLayout(r, size(400, 100))
    check near(childAt(r, 0).frame.x, 0.0)
    check near(childAt(r, 1).frame.x, 150.0)
    check near(childAt(r, 2).frame.x, 300.0)

  test "space evenly pads both edges and gaps":
    let r = newRow(fakeLeaf(100, 20), fakeLeaf(100, 20)).mainAlign(maSpaceEvenly)
    computeLayout(r, size(400, 100))
    check near(childAt(r, 0).frame.x, 200.0 / 3.0)
    check near(childAt(r, 1).frame.x, 200.0 / 3.0 * 2.0 + 100.0)

  test "space around wraps children with half-gap edges":
    let r = newRow(fakeLeaf(100, 20), fakeLeaf(100, 20)).mainAlign(maSpaceAround)
    computeLayout(r, size(400, 100))
    check near(childAt(r, 0).frame.x, 50.0)
    check near(childAt(r, 1).frame.x, 250.0)

  test "flex weights split free space proportionally":
    let r = newRow(newExpanded(fakeLeaf(0, 20), 1.0), newExpanded(fakeLeaf(0, 20), 3.0))
    computeLayout(r, size(400, 100))
    check near(childAt(r, 0).frame.width, 100.0)
    check near(childAt(r, 1).frame.width, 300.0)

  test "flex and fixed mix keeps fixed sizes":
    let r = newRow(fakeLeaf(100, 20), newExpanded(fakeLeaf(0, 20)), fakeLeaf(60, 20))
    computeLayout(r, size(400, 100))
    check near(childAt(r, 0).frame.width, 100.0)
    check near(childAt(r, 1).frame.width, 240.0)
    check near(childAt(r, 2).frame.width, 60.0)
    check near(childAt(r, 1).frame.x, 100.0)
    check near(childAt(r, 2).frame.x, 340.0)

  test "cross axis stretch fills height":
    let r = newRow(fakeLeaf(100, 20)).crossAlign(caStretch)
    computeLayout(r, size(400, 100))
    check near(childAt(r, 0).frame.height, 100.0)
    check near(childAt(r, 0).frame.y, 0.0)

  test "cross axis center and end offsets":
    let rc = newRow(fakeLeaf(100, 20)).crossAlign(caCenter)
    computeLayout(rc, size(400, 100))
    check near(childAt(rc, 0).frame.y, 40.0)
    let re = newRow(fakeLeaf(100, 20)).crossAlign(caEnd)
    computeLayout(re, size(400, 100))
    check near(childAt(re, 0).frame.y, 80.0)

  test "column distributes vertically with flex":
    let c = newColumn(newExpanded(fakeLeaf(100, 50), 1.0),
                      newExpanded(fakeLeaf(100, 50), 1.0))
    computeLayout(c, size(200, 300))
    check near(childAt(c, 0).frame.height, 150.0)
    check near(childAt(c, 0).frame.y, 0.0)
    check near(childAt(c, 1).frame.y, 150.0)

  test "padding insets children inside container":
    let inner = fakeLeaf(100, 40)
    let p = newPadding(inner, 10.0)
    let outer = newColumn(p).crossAlign(caStretch)
    computeLayout(outer, size(200, 200))
    check near(p.frame.width, 200.0)
    check near(inner.frame.x, 10.0)
    check near(inner.frame.y, 10.0)
    check near(inner.frame.width, 180.0)

  test "margin offsets child within its slot":
    let leaf = fakeLeaf(100, 40)
    let wrapper = newMargin(leaf, 15.0)
    let r = newRow(wrapper)
    computeLayout(r, size(400, 100))
    check near(leaf.frame.x, 15.0)
    check near(leaf.frame.y, 15.0)
    check near(leaf.frame.height, 40.0)
    check near(wrapper.frame.x, 0.0)

  test "sized box constrains child rect":
    let inner = fakeLeaf(100, 100)
    let b = newSizedBox(150.0, 80.0, inner)
    let r = newRow(b)
    computeLayout(r, size(400, 100))
    check near(inner.frame.width, 150.0)
    check near(inner.frame.height, 80.0)

  test "nested row inside column with padding":
    let l1 = fakeLeaf(60, 20)
    let l2 = fakeLeaf(60, 20)
    let innerRow = newRow(l1, l2).spacing(8.0)
    let padded = newPadding(innerRow, 12.0)
    let page = newColumn(padded)
    computeLayout(page, size(300, 200))
    check near(innerRow.frame.x, 12.0)
    check near(innerRow.frame.y, 12.0)
    check near(l1.frame.x, 0.0)
    check near(l2.frame.x, 68.0)

  test "expanded wrapper fills and passes rect to child":
    let inner = fakeLeaf(0, 30)
    let c = newColumn(newExpanded(inner, 1.0), fakeLeaf(100, 30)).crossAlign(caStretch)
    computeLayout(c, size(200, 300))
    check near(inner.frame.width, 200.0)
    check near(inner.frame.height, 270.0)
    check near(inner.frame.y, 0.0)

import nkit/gui/layout
import nkit/gui/label
import nkit/gui/view
import nkit/window
import nkit/foundation/dispatcher

suite "layout applier (views)":
  test "frames apply with y-flip into parent":
    let container = newPlainView()
    setFrameRect(container, rectangle(0.0, 0.0, 400.0, 200.0))
    let lbl = newLabel("Hi")
    let r = row(ViewNode(lbl)).crossAlign(caStart)
    addSubview(container, r.view)
    applyLayout(r, size(400.0, 200.0))
    # solver places the label at y=0 with height ~20; appkit flips to bottom
    let f = getFrameRect(lbl)
    check f.width > 0.0
    check abs(f.y - (200.0 - 0.0 - f.height)) < 0.01

  test "flex row splits real widths":
    let container = newPlainView()
    setFrameRect(container, rectangle(0.0, 0.0, 400.0, 100.0))
    let a = newLabel("A")
    let b = newLabel("B")
    let ea = expanded(ViewNode(a), 1.0)
    let eb = expanded(ViewNode(b), 3.0)
    let r = row(ea, eb)
    addSubview(container, r.view)
    applyLayout(r, size(400.0, 100.0))
    check abs(getFrameRect(a).width - 100.0) < 0.01
    check abs(getFrameRect(b).width - 300.0) < 0.01
    check abs(getFrameRect(eb.view).x - 100.0) < 0.01

  test "installLayout relayouts on window resize":
    let win = newWindow()
    defer:
      free(win)
    let lbl = newLabel("resize me")
    let root = column(expanded(ViewNode(lbl), 1.0))
    installLayout(win, root)
    discard runMainThreadLoopFor(80)
    let before = getFrameRect(lbl)

    setSize(win, size(600.0, 500.0), false)
    discard runMainThreadLoopFor(150)
    let after = getFrameRect(lbl)
    check after.height > before.height or after.width != before.width

suite "align (flutter-style)":
  test "nine-point presets against a 200x100 box with 40x10 child":
    let cases = [
      (alTopLeft, 0.0, 0.0),
      (alTopCenter, 80.0, 0.0),
      (alTopRight, 160.0, 0.0),
      (alCenterLeft, 0.0, 45.0),
      (alCenter, 80.0, 45.0),
      (alCenterRight, 160.0, 45.0),
      (alBottomLeft, 0.0, 90.0),
      (alBottomCenter, 80.0, 90.0),
      (alBottomRight, 160.0, 90.0),
    ]
    for (preset, wantX, wantY) in cases:
      let root = newAligned(fakeLeaf(40.0, 10.0), preset)
      computeLayout(root, size(200.0, 100.0))
      let f = root.children[0].frame
      check near(f.x, wantX)
      check near(f.y, wantY)

  test "fractional vector matches Flutter Alignment(x, y)":
    let root = newAligned(fakeLeaf(40.0, 10.0), -0.5, 0.25)
    computeLayout(root, size(200.0, 100.0))
    let f = root.children[0].frame
    check near(f.x, (160.0) * 0.25)
    check near(f.y, (90.0) * 0.625)

  test "default alignment is center":
    let root = newAligned(fakeLeaf(40.0, 10.0))
    computeLayout(root, size(200.0, 100.0))
    check near(root.children[0].frame.x, 80.0)
    check near(root.children[0].frame.y, 45.0)

  test "align hugs when measured":
    let root = newColumn(newAligned(fakeLeaf(40.0, 10.0), alBottomRight))
    discard measure(root, 500.0, 500.0)
    check near(root.cached.width, 40.0)
    check near(root.cached.height, 10.0)

  test "align inside stretched row centers vertically":
    let root = newRow(
      newExpanded(newAligned(fakeLeaf(40.0, 10.0), alCenter)),
      newExpanded(fakeLeaf(20.0, 20.0))
    ).crossAlign(caStretch)
    computeLayout(root, size(300.0, 60.0))
    let f = root.children[0].children[0].children[0].frame
    check near(f.y, 25.0)
    check near(f.x, 55.0)

  test "expanded wrapping align fills then positions":
    let root = newExpanded(newAligned(fakeLeaf(40.0, 10.0), alBottomCenter))
    computeLayout(root, size(100.0, 50.0))
    let f = root.children[0].children[0].frame
    check near(f.x, 30.0)
    check near(f.y, 40.0)

suite "pixel-grid snapping":
  test "fractional solver origins land on integer view frames":
    let container = newPlainView()
    setFrameRect(container, rectangle(0.0, 0.0, 401.0, 101.0))
    let lbl = newLabel("crisp text")
    let root = centered(ViewNode(lbl))
    addSubview(container, root.view)
    applyLayout(root, size(401.0, 101.0))
    let f = getFrameRect(lbl)
    check f.x == floor(f.x) and f.x == ceil(f.x)
    check f.y == floor(f.y) and f.y == ceil(f.y)
    check f.width == floor(f.width) and f.width == ceil(f.width)
