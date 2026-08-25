import std/tables
import nkit/foundation/id_allocator
import nkit/foundation/event
import nkit/foundation/event_emitter
import nkit/gui/view

when defined(macosx) or defined(ios):
  import nkit/platform/macos/nsfunctions

export view

type
  SelectChangedEvent* = ref object of GuiEvent
    selectId*: Id
    index*: int

  Select* = ref object of View

var liveSelects: Table[uint32, Select]

method typeName(e: SelectChangedEvent): string = "SelectChangedEvent"

proc newSelectChangedEvent*(selectId: Id, index: int): SelectChangedEvent =
  result = SelectChangedEvent(selectId: selectId, index: index)
  discard stamp(result)

when defined(macosx) or defined(ios):
  proc selectEventTrampoline(widgetId: uint32, index: int64, ctx: pointer) {.cdecl.} =
    let sel = liveSelects.getOrDefault(widgetId)
    if not sel.isNil:
      emitAsync(sel, newSelectChangedEvent(sel.id, int(index)))

var selectCallbacksArmed = false

proc ensureSelectCallbacks*() =
  when defined(macosx) or defined(ios):
    if not selectCallbacksArmed:
      naSelectSetEventCallback(selectEventTrampoline, nil)
      selectCallbacksArmed = true

proc newSelect*(items: openArray[string] = []): Select =
  ensureSelectCallbacks()
  let vid = allocate(typeTagGuiWidget)
  when defined(macosx) or defined(ios):
    let nativePtr = naSelectCreate(vid.uint32)
  else:
    let nativePtr: pointer = nil
  result = Select()
  discard wrapView(result, nativePtr, vid)
  liveSelects[vid.uint32] = result
  when defined(macosx) or defined(ios):
    for item in items:
      naSelectAddItem(result.native, item.cstring)

proc addItem*(sel: Select, title: string) =
  when defined(macosx) or defined(ios):
    naSelectAddItem(sel.native, title.cstring)

proc clearItems*(sel: Select) =
  when defined(macosx) or defined(ios):
    naSelectClear(sel.native)

proc destroy*(sel: Select) =
  when defined(macosx) or defined(ios):
    naSelectFree(sel.nativeKey, sel.native)
    sel.native = nil
  liveSelects.del(sel.nativeKey)
  shutdownEmitter[GuiEvent](sel)

proc count*(sel: Select): int =
  when defined(macosx) or defined(ios):
    int(naSelectCount(sel.native))
  else:
    0

proc getSelectedIndex*(sel: Select): int =
  when defined(macosx) or defined(ios):
    int(naSelectSelected(sel.native))
  else:
    -1

proc chooseIndex*(sel: Select, index: int) =
  when defined(macosx) or defined(ios):
    naSelectChoose(sel.native, index.int64)

proc getSelectedTitle*(sel: Select): string =
  when defined(macosx) or defined(ios):
    $naSelectSelectedTitle(sel.native)
  else:
    ""

proc onChanged*(sel: Select, handler: proc(e: SelectChangedEvent)): ListenerId =
  addListener[GuiEvent, SelectChangedEvent](sel, handler)
