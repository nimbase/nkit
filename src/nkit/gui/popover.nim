import std/tables
import ../foundation/id_allocator
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

when defined(macosx) or defined(ios) or defined(linux):
  proc popoverCloseTrampoline(handle: int64, ctx: pointer) {.cdecl.} =
    if popoversLive.hasKey(handle):
      let p = popoversLive[handle]
      emit(p, newPopoverClosedEvent(p.id))

proc ensurePopoverCallbacks() =
  when defined(macosx) or defined(linux):
    if not popoverCallbacksArmed:
      naPopoverSetCloseCallback(popoverCloseTrampoline)
      popoverCallbacksArmed = true

proc newPopover*(width = 240.0, height = 160.0): Popover =
  ensurePopoverCallbacks()
  when defined(macosx) or defined(linux):
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
  when defined(macosx) or defined(ios) or defined(linux):
    popoversLive[h] = result

proc show*(p: Popover, anchor: View, edge: PopoverEdge = peBottom) =
  when defined(macosx) or defined(linux):
    naPopoverShow(p.handle, anchor.native, cint(ord(edge)))

proc close*(p: Popover) =
  when defined(macosx) or defined(linux):
    naPopoverClose(p.handle)

proc isShown*(p: Popover): bool =
  when defined(macosx) or defined(linux):
    naPopoverIsShown(p.handle)
  else:
    false

proc onClosed*(p: Popover,
               handler: proc(e: PopoverClosedEvent)): ListenerId =
  addListener[GuiEvent, PopoverClosedEvent](p, handler)

proc fireClosedSimulated*(p: Popover) =
  ## Test hook: delivers a close notification through the pipeline.
  when defined(macosx) or defined(ios) or defined(linux):
    popoverCloseTrampoline(p.handle, nil)

proc destroy*(p: Popover) =
  when defined(macosx) or defined(linux):
    popoversLive.del(p.handle)
    naPopoverDestroy(p.handle)
  shutdownEmitter[GuiEvent](p)
