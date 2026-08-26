import std/tables
import nkit/foundation/id_allocator
import nkit/foundation/event
import nkit/foundation/event_emitter
import nkit/gui/view
when defined(ios):
  import nkit/platform/ios/uifunctions
elif defined(macosx):
  import nkit/platform/macos/nsfunctions

export view

type
  PopoverEdge* = enum
    peTop
    peRight
    peBottom
    peLeft

  PopoverEvent* = ref object of GuiEvent

  PopoverClosedEvent* = ref object of PopoverEvent
    popoverId*: Id

  Popover* = ref object of View
    handle: int64

var popoversLive = initTable[int64, Popover]()
var popoverCallbacksArmed = false

method typeName(e: PopoverClosedEvent): string = "PopoverClosedEvent"

proc newPopoverClosedEvent*(id: Id): PopoverClosedEvent =
  result = PopoverClosedEvent(popoverId: id)
  discard stamp(result)

when defined(macosx) or defined(ios):
  proc popoverCloseTrampoline(handle: int64, ctx: pointer) {.cdecl.} =
    if popoversLive.hasKey(handle):
      let p = popoversLive[handle]
      emit(p, newPopoverClosedEvent(p.id))

proc ensurePopoverCallbacks() =
  when defined(macosx) and not defined(ios):
    if not popoverCallbacksArmed:
      naPopoverSetCloseCallback(popoverCloseTrampoline)
      popoverCallbacksArmed = true

proc newPopover*(width = 240.0, height = 160.0): Popover =
  ensurePopoverCallbacks()
  when defined(macosx) and not defined(ios):
    let h = naPopoverCreate()
    let contentPtr = naPopoverContentView(h)
    naPopoverSetSize(h, width, height)
  else:
    let h = int64(0)
    let contentPtr: pointer = nil
  # Wrap the popover's content view so children attach like any View.
  let base = newPlainView()
  result = Popover(handle: h)
  discard wrapView(result, contentPtr, base.id)
  when defined(macosx) or defined(ios):
    popoversLive[h] = result

proc show*(p: Popover, anchor: View, edge: PopoverEdge = peBottom) =
  when defined(macosx) and not defined(ios):
    naPopoverShow(p.handle, anchor.native, cint(ord(edge)))

proc close*(p: Popover) =
  when defined(macosx) and not defined(ios):
    naPopoverClose(p.handle)

proc isShown*(p: Popover): bool =
  when defined(macosx) and not defined(ios):
    naPopoverIsShown(p.handle)
  else:
    false

proc onClosed*(p: Popover,
               handler: proc(e: PopoverClosedEvent)): ListenerId =
  addListener[GuiEvent, PopoverClosedEvent](p, handler)

proc fireClosedSimulated*(p: Popover) =
  ## Test hook: delivers a close notification through the pipeline.
  when defined(macosx) or defined(ios):
    popoverCloseTrampoline(p.handle, nil)

proc destroy*(p: Popover) =
  when defined(macosx) and not defined(ios):
    popoversLive.del(p.handle)
    naPopoverDestroy(p.handle)
  shutdownEmitter[GuiEvent](p)
