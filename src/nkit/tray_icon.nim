import nkit/foundation/event
import nkit/foundation/geometry
import nkit/foundation/event_emitter
import nkit/foundation/id_allocator
import nkit/image
import nkit/menu

when defined(macosx) or defined(ios):
  import nkit/platform/macos/nsfunctions

type
  TrayIconId* = Id

  ContextMenuTrigger* = enum
    cmtNone
    cmtClicked
    cmtRightClicked
    cmtDoubleClicked

type
  TrayIconEvent* = ref object of Event
    trayIconId*: TrayIconId
  TrayIconClickedEvent* = ref object of TrayIconEvent
  TrayIconRightClickedEvent* = ref object of TrayIconEvent
  TrayIconDoubleClickedEvent* = ref object of TrayIconEvent

method typeName(e: TrayIconEvent): string = "TrayIconEvent"
method typeName(e: TrayIconClickedEvent): string = "TrayIconClickedEvent"
method typeName(e: TrayIconRightClickedEvent): string = "TrayIconRightClickedEvent"
method typeName(e: TrayIconDoubleClickedEvent): string = "TrayIconDoubleClickedEvent"

proc newTrayIconEvent*[T: TrayIconEvent](trayId: TrayIconId): T =
  result = T(trayIconId: trayId)
  discard stamp(result)

var globalTrayClickSink*: proc(trayKey: uint32, kind: int) {.closure.}

when defined(macosx) or defined(ios):
  proc trayEventTrampoline(kind: cint, id: uint32, ctx: pointer) {.cdecl.} =
    if not globalTrayClickSink.isNil:
      globalTrayClickSink(id, int(kind))

var trayCallbacksArmed = false

proc ensureTrayCallbacks*() =
  when defined(macosx) or defined(ios):
    if not trayCallbacksArmed:
      naTraySetEventCallback(trayEventTrampoline, nil)
      trayCallbacksArmed = true

type TrayIcon* = ref object of EventEmitter[TrayIconEvent]
  id*: TrayIconId
  nativeKey*: uint32
  iconPath*: string
  contextMenuValue*: Menu
  trigger*: ContextMenuTrigger
  menuClosedListener*: ListenerId

proc newTrayIcon*(): TrayIcon =
  ensureTrayCallbacks()
  when defined(macosx) or defined(ios):
    let key = naTrayCreate()
    if key != 0:
      ensureMenuCallbacks()
  else:
    let key = allocate(typeTagTrayIcon).uint32
  let tray = TrayIcon(id: key.TrayIconId, nativeKey: key, trigger: cmtNone)
  initEmitter(tray)
  tray.onStartListening = proc() =
    when defined(macosx) or defined(ios):
      naTraySetupHandlers(tray.nativeKey)
  result = tray

proc getId*(t: TrayIcon): TrayIconId =
  t.id

proc exists*(t: TrayIcon): bool =
  when defined(macosx) or defined(ios):
    naTrayExists(t.nativeKey)
  else:
    false

proc setIconPath*(t: TrayIcon, path: string) =
  t.iconPath = path
  when defined(macosx) or defined(ios):
    if path.len > 0:
      naTraySetIconPath(t.nativeKey, path.cstring)
    else:
      naTrayClearIcon(t.nativeKey)

proc clearIcon*(t: TrayIcon) =
  t.iconPath = ""
  when defined(macosx) or defined(ios):
    naTrayClearIcon(t.nativeKey)

proc setIcon*(t: TrayIcon, img: Image) =
  when defined(macosx) or defined(ios):
    naTraySetIconPtr(t.nativeKey, if img.isNil: nil else: img.nativePtr())

proc setTitle*(t: TrayIcon, title: string) =
  when defined(macosx) or defined(ios):
    naTraySetTitle(t.nativeKey, title.cstring)

proc getTitle*(t: TrayIcon): string =
  when defined(macosx) or defined(ios):
    $naTrayGetTitle(t.nativeKey)
  else:
    ""

proc clearTitle*(t: TrayIcon) =
  when defined(macosx) or defined(ios):
    naTraySetTitle(t.nativeKey, nil)

proc setTooltip*(t: TrayIcon, tooltip: string) =
  when defined(macosx) or defined(ios):
    naTraySetTooltip(t.nativeKey, tooltip.cstring)

proc getTooltip*(t: TrayIcon): string =
  when defined(macosx) or defined(ios):
    $naTrayGetTooltip(t.nativeKey)
  else:
    ""

proc clearTooltip*(t: TrayIcon) =
  when defined(macosx) or defined(ios):
    naTraySetTooltip(t.nativeKey, nil)

proc setContextMenu*(t: TrayIcon, menu: Menu) =
  if not t.contextMenuValue.isNil and t.menuClosedListener != 0:
    discard t.contextMenuValue.removeListener(t.menuClosedListener)
    t.menuClosedListener = 0
  t.contextMenuValue = menu
  when defined(macosx) or defined(ios):
    let menuKey = if menu.isNil: uint32(0) else: menu.nativeKey
    naTraySetContextMenu(t.nativeKey, menuKey)
  if not menu.isNil:
    let selfRef = t
    proc onContextMenuClosed(e: MenuClosedEvent) =
      when defined(macosx) or defined(ios):
        if not selfRef.contextMenuValue.isNil:
          naTraySetContextMenu(selfRef.nativeKey, selfRef.contextMenuValue.nativeKey)
    t.menuClosedListener = menu.addListener(onContextMenuClosed)

proc getContextMenu*(t: TrayIcon): Menu =
  t.contextMenuValue

proc getBounds*(t: TrayIcon): Rectangle =
  when defined(macosx) or defined(ios):
    var x, y, w, h: float64
    naTrayGetBounds(t.nativeKey, addr x, addr y, addr w, addr h)
    Rectangle(x: x, y: y, width: w, height: h)
  else:
    Rectangle()

proc setVisible*(t: TrayIcon, visible: bool): bool =
  when defined(macosx) or defined(ios):
    naTraySetVisible(t.nativeKey, visible)
  else:
    false

proc isVisible*(t: TrayIcon): bool =
  when defined(macosx) or defined(ios):
    naTrayIsVisible(t.nativeKey)
  else:
    false

proc openContextMenu*(t: TrayIcon): bool =
  when defined(macosx) or defined(ios):
    naTrayOpenContextMenu(t.nativeKey)
  else:
    false

proc closeContextMenu*(t: TrayIcon): bool =
  when defined(macosx) or defined(ios):
    naTrayCloseContextMenu(t.nativeKey)
  else:
    true

proc setContextMenuTrigger*(t: TrayIcon, trigger: ContextMenuTrigger) =
  t.trigger = trigger

proc getContextMenuTrigger*(t: TrayIcon): ContextMenuTrigger =
  t.trigger

proc free*(t: TrayIcon) =
  when defined(macosx) or defined(ios):
    naTrayFree(t.nativeKey)

proc dispatchTrayEvent*(t: TrayIcon, kind: int) =
  case kind
  of 0:
    t.emit(newTrayIconEvent[TrayIconClickedEvent](t.id))
  of 1:
    t.emit(newTrayIconEvent[TrayIconRightClickedEvent](t.id))
  of 2:
    t.emit(newTrayIconEvent[TrayIconDoubleClickedEvent](t.id))
  else:
    discard
