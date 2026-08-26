import unittest

import nkit

suite "window properties":
  test "create and identity":
    let w = newWindow()
    check w.id.isValid()
    check w.id.getType() == typeTagWindow
    w.free()

  test "title round trip":
    let w = newWindow()
    w.setTitle("hello nim window")
    check w.getTitle() == "hello nim window"
    w.setTitle("")
    check w.getTitle() == ""
    w.free()

  test "visibility":
    let w = newWindow()
    check not w.isVisible()
    w.hide()
    check not w.isVisible()
    w.free()

  test "size round trip":
    let w = newWindow()
    w.setSize(size(640, 480))
    let s = w.getSize()
    check s.width == 640
    check s.height == 480
    w.free()

  test "bounds round trip in top-left coordinates":
    let w = newWindow()
    w.setBounds(rectangle(120, 80, 500, 400))
    let b = w.getBounds()
    check b.x == 120
    check b.y == 80
    check b.width == 500
    check b.height == 400
    w.free()

  test "position round trip":
    let w = newWindow()
    w.setSize(size(300, 200))
    w.setPosition(point(50, 60))
    let p = w.getPosition()
    check p.x == 50
    check p.y == 60
    w.free()

  test "minimum and maximum size":
    let w = newWindow()
    w.setMinimumSize(size(200, 150))
    let minS = w.getMinimumSize()
    check minS.width == 200
    check minS.height == 150
    w.setMaximumSize(size(1000, 800))
    let maxS = w.getMaximumSize()
    check maxS.width == 1000
    check maxS.height == 800
    w.free()

  test "content size round trip":
    let w = newWindow()
    w.setContentSize(size(400, 300))
    let s = w.getContentSize()
    check s.width == 400
    check s.height == 300
    w.free()

  test "style flags toggling":
    let w = newWindow()
    check w.isResizable()
    w.setResizable(false)
    check not w.isResizable()
    w.setResizable(true)
    check w.isResizable()
    check not w.isAlwaysOnTop()
    w.setAlwaysOnTop(true)
    check w.isAlwaysOnTop()
    w.setAlwaysOnTop(false)
    check not w.isAlwaysOnTop()
    check not w.isVisibleOnAllWorkspaces()
    w.setVisibleOnAllWorkspaces(true)
    check w.isVisibleOnAllWorkspaces()
    w.setVisibleOnAllWorkspaces(false)
    check w.isMovable()
    w.setMovable(false)
    check not w.isMovable()
    w.setMovable(true)
    check w.hasShadow()
    w.setHasShadow(false)
    check not w.hasShadow()
    w.setHasShadow(true)
    check not w.isIgnoreMouseEvents()
    w.setIgnoreMouseEvents(true)
    check w.isIgnoreMouseEvents()
    w.setIgnoreMouseEvents(false)
    w.free()

  test "opacity round trip":
    let w = newWindow()
    w.setOpacity(0.5'f32)
    let o = w.getOpacity()
    check abs(o - 0.5'f32) < 0.01'f32
    w.setOpacity(1.0'f32)
    w.free()

  test "background color round trip":
    let w = newWindow()
    w.setBackgroundColor(Color(r: 10, g: 20, b: 30, a: 255))
    let c = w.getBackgroundColor()
    check abs(c.r.int - 10) <= 1
    check abs(c.g.int - 20) <= 1
    check abs(c.b.int - 30) <= 1
    check c.a == 255
    w.free()

  test "title bar style round trip":
    let w = newWindow()
    check w.getTitleBarStyle() == tsNormal
    w.setTitleBarStyle(tsHidden)
    check w.getTitleBarStyle() == tsHidden
    w.setTitleBarStyle(tsNormal)
    check w.getTitleBarStyle() == tsNormal
    w.free()

  test "visual effect state stored":
    let w = newWindow()
    check w.getVisualEffect() == veNone
    w.setVisualEffect(veBlur)
    check w.getVisualEffect() == veBlur
    w.setVisualEffect(veNone)
    check w.getVisualEffect() == veNone
    w.free()

suite "window events":
  test "moved and resized fire through manager emitter":
    let wm = sharedWindowManager()
    var movedCount, resizedCount = 0
    var lastPos = point(0, 0)
    discard wm.addListener(proc(e: WindowMovedEvent) =
      inc movedCount
      lastPos = e.newPosition)
    discard wm.addListener(proc(e: WindowResizedEvent) =
      inc resizedCount)

    let w = newWindow()
    discard runOnMainThread(proc() =
      w.setSize(size(700, 500))
      w.setPosition(point(90, 90)))
    discard runMainThreadLoopFor(500)

    check movedCount >= 1
    check resizedCount >= 1
    if movedCount > 0:
      check lastPos.x == 90
      check lastPos.y == 90
    w.free()

suite "window registry and manager":
  test "registry stores and retrieves":
    let reg = sharedWindowRegistry()
    let before = reg.len()
    let w = newWindow()
    reg.add(w)
    check reg.len() == before + 1
    check reg.contains(w.id)
    let fetched = reg.get(w.id)
    check cast[pointer](fetched) == cast[pointer](w)
    check reg.remove(w.id)
    check not reg.contains(w.id)
    w.free()

  test "manager enumerates created windows":
    let wm = sharedWindowManager()
    let w = newWindow()
    let windows = wm.getAllWindows()
    var found = false
    for win in windows:
      if cast[pointer](win) == cast[pointer](w):
        found = true
    check found
    check wm.getWindow(w.id) != nil
    w.free()

  test "application getAllWindows delegates to manager":
    let app = initApplication()
    let w = newWindow()
    let windows = app.getAllWindows()
    var found = false
    for win in windows:
      if cast[pointer](win) == cast[pointer](w):
        found = true
    check found
    w.free()

  test "primary window setter and getter":
    let app = initApplication()
    let w = newWindow()
    app.setPrimaryWindow(w)
    check cast[pointer](app.getPrimaryWindow()) == cast[pointer](w)
    app.primaryWindow = nil
    w.free()
