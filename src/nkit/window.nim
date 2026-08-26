import nkit/foundation/event
import nkit/foundation/geometry
import nkit/foundation/id_allocator
import nkit/foundation/color

when defined(ios):
  import nkit/platform/ios/uifunctions
elif defined(macosx):
  import nkit/platform/macos/nsfunctions

type
  WindowId* = Id

  TitleBarStyle* = enum
    tsNormal
    tsHidden

  VisualEffect* = enum
    veNone
    veBlur
    veAcrylic
    veMica

type Window* = ref object of RootObj
  id*: WindowId
  nativeKey*: uint32

var onWindowCreated*: proc(w: Window) {.closure.}

var mostRecentWindowValue: Window = nil

proc mostRecentWindow*(): Window =
  ## Window returned by the last newWindow() call; the default mount target
  ## for the `layout do:` template.
  mostRecentWindowValue

proc newWindow*(): Window =
  when defined(macosx) or defined(ios):
    let key = naWindowCreate()
  else:
    let key = allocate(typeTagWindow).uint32
  result = Window(id: key.WindowId, nativeKey: key)
  mostRecentWindowValue = result
  if not onWindowCreated.isNil:
    onWindowCreated(result)

proc getId*(w: Window): WindowId =
  w.id

func getKey*(w: Window): uint32 =
  w.nativeKey

# Focus

proc focus*(w: Window) =
  when defined(macosx) or defined(ios):
    naWindowFocus(w.nativeKey)

proc blur*(w: Window) =
  when defined(macosx) or defined(ios):
    naWindowBlur(w.nativeKey)

proc isFocused*(w: Window): bool =
  when defined(macosx) or defined(ios):
    naWindowIsFocused(w.nativeKey)
  else:
    false

# Visibility

proc show*(w: Window) =
  when defined(macosx) or defined(ios):
    naWindowShow(w.nativeKey)

proc showInactive*(w: Window) =
  when defined(macosx) or defined(ios):
    naWindowShowInactive(w.nativeKey)

proc hide*(w: Window) =
  when defined(macosx) or defined(ios):
    naWindowHide(w.nativeKey)

proc isVisible*(w: Window): bool =
  when defined(macosx) or defined(ios):
    naWindowIsVisible(w.nativeKey)
  else:
    false

# State

proc maximize*(w: Window) =
  when defined(macosx) or defined(ios):
    naWindowMaximize(w.nativeKey)

proc unmaximize*(w: Window) =
  when defined(macosx) or defined(ios):
    naWindowUnmaximize(w.nativeKey)

proc isMaximized*(w: Window): bool =
  when defined(macosx) or defined(ios):
    naWindowIsMaximized(w.nativeKey)
  else:
    false

proc minimize*(w: Window) =
  when defined(macosx) or defined(ios):
    naWindowMinimize(w.nativeKey)

proc restore*(w: Window) =
  when defined(macosx) or defined(ios):
    naWindowRestore(w.nativeKey)

proc isMinimized*(w: Window): bool =
  when defined(macosx) or defined(ios):
    naWindowIsMinimized(w.nativeKey)
  else:
    false

proc setFullScreen*(w: Window, fullScreen: bool) =
  when defined(macosx) or defined(ios):
    naWindowSetFullScreen(w.nativeKey, fullScreen)

proc isFullScreen*(w: Window): bool =
  when defined(macosx) or defined(ios):
    naWindowIsFullScreen(w.nativeKey)
  else:
    false

# Bounds and size

proc setBounds*(w: Window, bounds: Rectangle) =
  when defined(macosx) or defined(ios):
    naWindowSetBounds(w.nativeKey, bounds.x, bounds.y, bounds.width, bounds.height)

proc getBounds*(w: Window): Rectangle =
  when defined(macosx) or defined(ios):
    var x, y, wd, h: float64
    naWindowGetBounds(w.nativeKey, addr x, addr y, addr wd, addr h)
    Rectangle(x: x, y: y, width: wd, height: h)
  else:
    Rectangle()

proc setSize*(w: Window, size: Size, animate = false) =
  when defined(macosx) or defined(ios):
    naWindowSetSize(w.nativeKey, size.width, size.height, animate)

proc getSize*(win: Window): Size =
  when defined(macosx) or defined(ios):
    var fw, fh: float64
    naWindowGetSize(win.nativeKey, addr fw, addr fh)
    Size(width: fw, height: fh)
  else:
    Size()

proc setContentSize*(w: Window, size: Size) =
  when defined(macosx) or defined(ios):
    naWindowSetContentSize(w.nativeKey, size.width, size.height)

proc setMaxSize*(w: Window, maxSize: Size) =
  when defined(macosx) or defined(ios):
    naWindowSetMaxSize(w.nativeKey, maxSize.width, maxSize.height)

proc setMinSize*(w: Window, minSize: Size) =
  when defined(macosx) or defined(ios):
    naWindowSetMinSize(w.nativeKey, minSize.width, minSize.height)

proc getContentSize*(win: Window): Size =
  when defined(macosx) or defined(ios):
    var fw, fh: float64
    naWindowGetContentSize(win.nativeKey, addr fw, addr fh)
    Size(width: fw, height: fh)
  else:
    Size()

proc setContentBounds*(w: Window, bounds: Rectangle) =
  when defined(macosx) or defined(ios):
    naWindowSetContentBounds(w.nativeKey, bounds.x, bounds.y, bounds.width, bounds.height)

proc getContentBounds*(w: Window): Rectangle =
  when defined(macosx) or defined(ios):
    var x, y, wd, h: float64
    naWindowGetContentBounds(w.nativeKey, addr x, addr y, addr wd, addr h)
    Rectangle(x: x, y: y, width: wd, height: h)
  else:
    Rectangle()

proc setMinimumSize*(w: Window, size: Size) =
  when defined(macosx) or defined(ios):
    naWindowSetMinimumSize(w.nativeKey, size.width, size.height)

proc getMinimumSize*(win: Window): Size =
  when defined(macosx) or defined(ios):
    var fw, fh: float64
    naWindowGetMinimumSize(win.nativeKey, addr fw, addr fh)
    Size(width: fw, height: fh)
  else:
    Size()

proc setMaximumSize*(w: Window, size: Size) =
  when defined(macosx) or defined(ios):
    naWindowSetMaximumSize(w.nativeKey, size.width, size.height)

proc getMaximumSize*(win: Window): Size =
  when defined(macosx) or defined(ios):
    var fw, fh: float64
    naWindowGetMaximumSize(win.nativeKey, addr fw, addr fh)
    Size(width: fw, height: fh)
  else:
    Size()

proc setPosition*(w: Window, position: Point) =
  when defined(macosx) or defined(ios):
    naWindowSetPosition(w.nativeKey, position.x, position.y)

proc getPosition*(w: Window): Point =
  when defined(macosx) or defined(ios):
    var x, y: float64
    naWindowGetPosition(w.nativeKey, addr x, addr y)
    Point(x: x, y: y)
  else:
    Point()

proc center*(w: Window) =
  when defined(macosx) or defined(ios):
    naWindowCenter(w.nativeKey)

# Title

proc setTitle*(w: Window, title: string) =
  when defined(macosx) or defined(ios):
    naWindowSetTitle(w.nativeKey, title.cstring)

proc getTitle*(w: Window): string =
  when defined(macosx) or defined(ios):
    $naWindowGetTitle(w.nativeKey)
  else:
    ""

# Behavior

proc setResizable*(w: Window, resizable: bool) =
  when defined(macosx) or defined(ios):
    naWindowSetResizable(w.nativeKey, resizable)

proc isResizable*(w: Window): bool =
  when defined(macosx) or defined(ios):
    naWindowIsResizable(w.nativeKey)
  else:
    false

proc setMovable*(w: Window, movable: bool) =
  when defined(macosx) or defined(ios):
    naWindowSetMovable(w.nativeKey, movable)

proc isMovable*(w: Window): bool =
  when defined(macosx) or defined(ios):
    naWindowIsMovable(w.nativeKey)
  else:
    false

proc setMinimizable*(w: Window, minimizable: bool) =
  when defined(macosx) or defined(ios):
    naWindowSetMinimizable(w.nativeKey, minimizable)

proc isMinimizable*(w: Window): bool =
  when defined(macosx) or defined(ios):
    naWindowIsMinimizable(w.nativeKey)
  else:
    false

proc setMaximizable*(w: Window, maximizable: bool) =
  when defined(macosx) or defined(ios):
    naWindowSetMaximizable(w.nativeKey, maximizable)

proc isMaximizable*(w: Window): bool =
  when defined(macosx) or defined(ios):
    naWindowIsMaximizable(w.nativeKey)
  else:
    false

proc setClosable*(w: Window, closable: bool) =
  when defined(macosx) or defined(ios):
    naWindowSetClosable(w.nativeKey, closable)

proc isClosable*(w: Window): bool =
  when defined(macosx) or defined(ios):
    naWindowIsClosable(w.nativeKey)
  else:
    false

proc setAlwaysOnTop*(w: Window, alwaysOnTop: bool) =
  when defined(macosx) or defined(ios):
    naWindowSetAlwaysOnTop(w.nativeKey, alwaysOnTop)

proc isAlwaysOnTop*(w: Window): bool =
  when defined(macosx) or defined(ios):
    naWindowIsAlwaysOnTop(w.nativeKey)
  else:
    false

proc setVisibleOnAllWorkspaces*(w: Window, visible: bool) =
  when defined(macosx) or defined(ios):
    naWindowSetVisibleOnAllWorkspaces(w.nativeKey, visible)

proc isVisibleOnAllWorkspaces*(w: Window): bool =
  when defined(macosx) or defined(ios):
    naWindowIsVisibleOnAllWorkspaces(w.nativeKey)
  else:
    false

proc setIgnoreMouseEvents*(w: Window, ignore: bool) =
  when defined(macosx) or defined(ios):
    naWindowSetIgnoreMouseEvents(w.nativeKey, ignore)

proc isIgnoreMouseEvents*(w: Window): bool =
  when defined(macosx) or defined(ios):
    naWindowIsIgnoreMouseEvents(w.nativeKey)
  else:
    false

proc isFocusable*(w: Window): bool =
  when defined(macosx) or defined(ios):
    naWindowIsFocusable(w.nativeKey)
  else:
    true

# Appearance

proc setTitleBarStyle*(w: Window, style: TitleBarStyle) =
  when defined(macosx) or defined(ios):
    naWindowSetTitleBarStyle(w.nativeKey, cint(ord(style)))

proc getTitleBarStyle*(w: Window): TitleBarStyle =
  when defined(macosx) or defined(ios):
    TitleBarStyle(naWindowGetTitleBarStyle(w.nativeKey))
  else:
    tsNormal

proc setHasShadow*(w: Window, hasShadow: bool) =
  when defined(macosx) or defined(ios):
    naWindowSetHasShadow(w.nativeKey, hasShadow)

proc hasShadow*(w: Window): bool =
  when defined(macosx) or defined(ios):
    naWindowHasShadow(w.nativeKey)
  else:
    false

proc setOpacity*(w: Window, opacity: float32) =
  when defined(macosx) or defined(ios):
    naWindowSetOpacity(w.nativeKey, opacity.cfloat)

proc getOpacity*(w: Window): float32 =
  when defined(macosx) or defined(ios):
    float32(naWindowGetOpacity(w.nativeKey))
  else:
    1.0'f32

proc setVisualEffect*(w: Window, effect: VisualEffect) =
  when defined(macosx) or defined(ios):
    naWindowSetVisualEffect(w.nativeKey, cint(ord(effect)))

proc getVisualEffect*(w: Window): VisualEffect =
  when defined(macosx) or defined(ios):
    VisualEffect(naWindowGetVisualEffect(w.nativeKey))
  else:
    veNone

proc setBackgroundColor*(w: Window, color: Color) =
  when defined(macosx) or defined(ios):
    naWindowSetBackgroundColor(w.nativeKey, color.r, color.g, color.b, color.a)

proc getBackgroundColor*(w: Window): Color =
  when defined(macosx) or defined(ios):
    var r, g, b, a: uint8
    naWindowGetBackgroundColor(w.nativeKey, addr r, addr g, addr b, addr a)
    Color(r: r, g: g, b: b, a: a)
  else:
    colorWhite

# Interaction

proc startDragging*(w: Window) =
  when defined(macosx) or defined(ios):
    naWindowStartDragging(w.nativeKey)

proc startResizing*(w: Window) =
  discard

# Events

type
  WindowEvent* = ref object of Event
    windowId*: WindowId
  WindowFocusedEvent* = ref object of WindowEvent
  WindowBlurredEvent* = ref object of WindowEvent
  WindowMinimizedEvent* = ref object of WindowEvent
  WindowMaximizedEvent* = ref object of WindowEvent
  WindowRestoredEvent* = ref object of WindowEvent
  WindowMovedEvent* = ref object of WindowEvent
    newPosition*: Point
  WindowResizedEvent* = ref object of WindowEvent
    newSize*: Size

method typeName(e: WindowEvent): string = "WindowEvent"
method typeName(e: WindowFocusedEvent): string = "WindowFocusedEvent"
method typeName(e: WindowBlurredEvent): string = "WindowBlurredEvent"
method typeName(e: WindowMinimizedEvent): string = "WindowMinimizedEvent"
method typeName(e: WindowMaximizedEvent): string = "WindowMaximizedEvent"
method typeName(e: WindowRestoredEvent): string = "WindowRestoredEvent"
method typeName(e: WindowMovedEvent): string = "WindowMovedEvent"
method typeName(e: WindowResizedEvent): string = "WindowResizedEvent"

proc newWindowEvent*[T: WindowEvent](windowId: WindowId): T =
  result = T(windowId: windowId)
  discard stamp(result)

proc newWindowMovedEvent*(windowId: WindowId, newPosition: Point): WindowMovedEvent =
  result = WindowMovedEvent(windowId: windowId, newPosition: newPosition)
  discard stamp(result)

proc newWindowResizedEvent*(windowId: WindowId, newSize: Size): WindowResizedEvent =
  result = WindowResizedEvent(windowId: windowId, newSize: newSize)
  discard stamp(result)

proc free*(w: Window) =
  when defined(macosx) or defined(ios):
    naWindowFree(w.nativeKey)

proc contentView*(w: Window): pointer =
  ## Raw platform content view pointer (NSView* on macOS).
  when defined(macosx) or defined(ios):
    naWindowContentView(w.nativeKey)
