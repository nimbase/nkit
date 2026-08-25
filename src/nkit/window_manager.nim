import nkit/foundation/event_emitter
import nkit/foundation/geometry
import nkit/window
import nkit/window_registry

when defined(macosx) or defined(ios):
  import nkit/platform/macos/nsfunctions

const maxEnumeratedWindows = 256

type WindowManager* = ref object of EventEmitter[WindowEvent]

when defined(macosx) or defined(ios):
  proc eventTrampoline(kind: cint, windowId: uint32, a, b: float64, ctx: pointer) {.cdecl.} =
    let wm = cast[WindowManager](ctx)
    let wid = windowId.WindowId
    case int(kind)
    of 0: wm.emit(newWindowEvent[WindowFocusedEvent](wid))
    of 1: wm.emit(newWindowEvent[WindowBlurredEvent](wid))
    of 2: wm.emit(newWindowEvent[WindowMinimizedEvent](wid))
    of 3: wm.emit(newWindowEvent[WindowRestoredEvent](wid))
    of 4: wm.emit(newWindowMovedEvent(wid, Point(x: a, y: b)))
    of 5: wm.emit(newWindowResizedEvent(wid, Size(width: a, height: b)))
    else: discard

var sharedWindowManagerInstance: WindowManager

proc registerWindow*(wm: WindowManager, window: Window) =
  let reg = sharedWindowRegistry()
  if not reg.contains(window.id):
    reg.add(window)

proc wrapNativeKey*(wm: WindowManager, key: uint32): Window =
  let reg = sharedWindowRegistry()
  let id = key.WindowId
  let existing = reg.get(id)
  if not existing.isNil:
    return existing
  let w = Window(id: id, nativeKey: key)
  reg.add(w)
  w

proc getAllWindows*(wm: WindowManager): seq[Window] =
  when defined(macosx) or defined(ios):
    var ids: array[maxEnumeratedWindows, uint32]
    let count = int(naWindowListIds(cast[ptr uint32](addr ids[0]), cint(maxEnumeratedWindows)))
    for i in 0 ..< count:
      discard wm.wrapNativeKey(ids[i])
  result = sharedWindowRegistry().getAll()

proc getWindow*(wm: WindowManager, id: WindowId): Window =
  let reg = sharedWindowRegistry()
  result = reg.get(id)
  if result.isNil:
    discard wm.getAllWindows()
    result = reg.get(id)

proc getCurrentWindow*(wm: WindowManager): Window =
  when defined(macosx) or defined(ios):
    let key = naWindowMainWindowId()
    if key != 0:
      result = wm.wrapNativeKey(key)

proc sharedWindowManager*(): WindowManager =
  if sharedWindowManagerInstance.isNil:
    let wm = WindowManager()
    initEmitter(wm)
    when defined(macosx) or defined(ios):
      naWindowSetEventCallback(eventTrampoline, cast[pointer](wm))
    if onWindowCreated.isNil:
      onWindowCreated = proc(w: Window) =
        wm.registerWindow(w)
    discard wm.getAllWindows()
    sharedWindowManagerInstance = wm
  result = sharedWindowManagerInstance
