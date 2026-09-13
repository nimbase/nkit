import std/tables
import ../foundation/id_allocator
import ../window
import ../foundation/event
import ../foundation/event_emitter
import ./view
when defined(ios):
  import ../platform/ios/uifunctions
elif defined(macosx):
  import ../platform/macos/nsfunctions
elif defined(linux):
  import ../platform/linux/gfunctions

export view

type
  ToolbarItemClickedEvent* = ref object of GuiEvent
    ordinal*: int

  Toolbar* = ref object
    handle: int64
    windowId: uint32

var toolbarItems = initTable[uint32, proc()]()
var toolbarItemOrder = initTable[int64, seq[uint32]]()
var nextToolbarWidgetId: uint32 = 1
var toolbarCallbacksArmed = false

when defined(macosx) or defined(ios) or defined(linux):
  proc toolbarClickTrampoline(widgetId: cuint, ctx: pointer) {.cdecl.} =
    let wid = uint32(widgetId)
    if toolbarItems.hasKey(wid):
      toolbarItems[wid]()

method typeName(e: ToolbarItemClickedEvent): string = "ToolbarItemClickedEvent"

proc newToolbarItemClickedEvent*(ordinal: int): ToolbarItemClickedEvent =
  result = ToolbarItemClickedEvent(ordinal: ordinal)
  discard stamp(result)

proc ensureToolbarCallbacks() =
  when defined(macosx) or defined(linux):
    if not toolbarCallbacksArmed:
      naToolbarSetClickCallback(toolbarClickTrampoline)
      toolbarCallbacksArmed = true

proc attachToolbar*(win: Window): Toolbar =
  ensureToolbarCallbacks()
  when defined(macosx) or defined(linux):
    let h = naToolbarAttach(win.id.uint32)
  else:
    let h = int64(0)
  result = Toolbar(handle: h, windowId: win.id.uint32)

proc addItem*(t: Toolbar, label: string, symbolName: string,
              onTap: proc()): int =
  ## Appends an icon item; onTap fires on click. Returns the ordinal.
  when defined(macosx) or defined(linux):
    let wid = nextToolbarWidgetId
    inc nextToolbarWidgetId
    if not onTap.isNil:
      toolbarItems[wid] = onTap
    let ordinal = naToolbarAddItem(t.handle, label.cstring,
                                   symbolName.cstring, wid)
    if not toolbarItemOrder.hasKey(t.handle):
      toolbarItemOrder[t.handle] = @[]
    toolbarItemOrder[t.handle].add(wid)
    result = int(ordinal)
  else:
    0

proc removeItem*(t: Toolbar, ordinal: int) =
  when defined(macosx) or defined(ios) or defined(linux):
    discard

proc itemCount*(t: Toolbar): int =
  when defined(macosx) or defined(linux):
    int(naToolbarItemCount(t.handle))
  else:
    0

proc fireToolbarItemSimulated*(t: Toolbar, ordinal: int) =
  ## Test hook: presses a toolbar item through the callback pipeline.
  when defined(macosx) or defined(ios) or defined(linux):
    if toolbarItemOrder.hasKey(t.handle) and
        ordinal >= 0 and ordinal < toolbarItemOrder[t.handle].len:
      let wid = toolbarItemOrder[t.handle][ordinal]
      if toolbarItems.hasKey(wid):
        toolbarItems[wid]()
