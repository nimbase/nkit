import unittest
import nkit
import nkit/gui/view
import nkit/gui/theme
import nkit/platform/macos/nsfunctions

suite "gui view base":
  test "create defaults and property round trips":
    let v = wrapView(View(), naViewCreate())
    defer:
      destroy(v)
    check v.id != idInvalid
    check v.nativeKey != 0
    check not findView(v.nativeKey).isNil
    check subviewCount(v) == 0

    setTag(v, 42)
    check getTag(v) == 42
    setTooltip(v, "hello tooltip")
    check getTooltip(v) == "hello tooltip"
    setHidden(v, true)
    check isHidden(v)
    setHidden(v, false)
    check not isHidden(v)

    setFrameRect(v, rectangle(5.0, 7.0, 120.0, 60.0))
    let f = getFrameRect(v)
    check f.x == 5.0
    check f.y == 7.0
    check f.width == 120.0
    check f.height == 60.0

  test "hierarchy add remove count":
    let parent = wrapView(View(), naViewCreate())
    defer:
      destroy(parent)
    let c1 = wrapView(View(), naViewCreate())
    let c2 = wrapView(View(), naViewCreate())
    let c3 = wrapView(View(), naViewCreate())
    defer:
      destroy(c1)
      destroy(c2)
      destroy(c3)

    addSubview(parent, c1)
    addSubview(parent, c2)
    addSubview(parent, c3)
    check subviewCount(parent) == 3

    removeFromParent(c2)
    check subviewCount(parent) == 2

    removeAllChildren(parent)
    check subviewCount(parent) == 0

  test "fill constraints resolve after layout":
    let parent = wrapView(View(), naViewCreate())
    defer:
      destroy(parent)
    let child = wrapView(View(), naViewCreate())
    defer:
      destroy(child)

    setFrameRect(parent, rectangle(0.0, 0.0, 200.0, 100.0))
    addSubview(parent, child)
    fillParent(child, left = 10.0, top = 12.0, right = 14.0, bottom = 16.0)
    layoutNow(parent)

    let f = getFrameRect(child)
    check abs(f.x - 10.0) < 0.01
    check abs(f.y - 16.0) < 0.01
    check abs(f.width - 176.0) < 0.01
    check abs(f.height - 72.0) < 0.01

  test "size constraint pins dimensions":
    let parent = wrapView(View(), naViewCreate())
    defer:
      destroy(parent)
    let child = wrapView(View(), naViewCreate())
    defer:
      destroy(child)
    setFrameRect(parent, rectangle(0.0, 0.0, 300.0, 200.0))
    addSubview(parent, child)
    constrainSize(child, 80.0, 30.0)
    layoutNow(parent)
    let f = getFrameRect(child)
    check abs(f.width - 80.0) < 0.01
    check abs(f.height - 30.0) < 0.01

  test "destroy unregisters view":
    let before = liveViewCount()
    let v = wrapView(View(), naViewCreate())
    check liveViewCount() == before + 1
    destroy(v)
    check liveViewCount() == before
    check findView(v.nativeKey).isNil

suite "window content bridge":
  test "set root view fills content area":
    let w = newWindow()
    defer:
      free(w)
    let root = wrapView(View(), naViewCreate())
    defer:
      destroy(root)
    setContent(w, root)
    let cv = contentView(w)
    check not cv.isNil
    check int(naViewSubviewCount(cv)) == 1

    let replacement = wrapView(View(), naViewCreate())
    defer:
      destroy(replacement)
    setContent(w, replacement)
    check int(naViewSubviewCount(cv)) == 1

suite "theme":
  test "dark mode query works":
    discard isDarkMode()

  test "semantic colors are valid":
    let accent = accentColor()
    check accent.a > 0'u8
    let label = labelColor()
    check label.a > 0'u8
    let windowBg = windowBackgroundColor()
    check windowBg != colorTransparent
    let sep = separatorColor()
    check sep.a > 0'u8

  test "system colors differ":
    let red = systemRed()
    let blue = systemBlue()
    check red.r > blue.r
    check blue.b > red.b

  test "appearance change event routes to listener":
    var fired = 0
    discard onAppearanceChanged(proc(e: AppearanceChangedEvent) =
      inc fired)
    triggerAppearanceChanged()
    discard runMainThreadLoopFor(100)
    check fired >= 1
