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
  SegmentedSelectEvent* = ref object of GuiEvent
    segmentedId*: Id
    index*: int

  SegmentedControl* = ref object of View

var liveSegmented: Table[uint32, SegmentedControl]

method typeName(e: SegmentedSelectEvent): string = "SegmentedSelectEvent"

proc newSegmentedSelectEvent*(segmentedId: Id, index: int): SegmentedSelectEvent =
  result = SegmentedSelectEvent(segmentedId: segmentedId, index: index)
  discard stamp(result)

when defined(macosx) or defined(ios) or defined(linux):
  proc segmentedEventTrampoline(widgetId: uint32, index: int64, ctx: pointer) {.cdecl.} =
    let sc = liveSegmented.getOrDefault(widgetId)
    if not sc.isNil:
      emitAsync(sc, newSegmentedSelectEvent(sc.id, int(index)))

var segmentedCallbacksArmed = false

proc ensureSegmentedCallbacks*() =
  when defined(macosx) or defined(ios) or defined(linux):
    if not segmentedCallbacksArmed:
      naSegmentedSetEventCallback(segmentedEventTrampoline, nil)
      segmentedCallbacksArmed = true

proc setLabels*(sc: SegmentedControl, labels: openArray[string]) =
  when defined(macosx) or defined(ios) or defined(linux):
    var cstrs: seq[cstring]
    for l in labels:
      cstrs.add(l.cstring)
    naSegmentedSetLabels(sc.native, cast[ptr cstring](addr cstrs[0]), cint(cstrs.len))

proc newSegmented*(labels: openArray[string] = []): SegmentedControl =
  ensureSegmentedCallbacks()
  let vid = allocate(typeTagGuiWidget)
  when defined(macosx) or defined(ios) or defined(linux):
    let nativePtr = naSegmentedCreate(vid.uint32)
  else:
    let nativePtr: pointer = nil
  result = SegmentedControl()
  discard wrapView(result, nativePtr, vid)
  liveSegmented[vid.uint32] = result
  when defined(macosx) or defined(ios) or defined(linux):
    if labels.len > 0:
      setLabels(result, labels)

proc destroy*(sc: SegmentedControl) =
  when defined(macosx) or defined(ios) or defined(linux):
    naSegmentedFree(sc.nativeKey, sc.native)
    sc.native = nil
  liveSegmented.del(sc.nativeKey)
  shutdownEmitter[GuiEvent](sc)

proc count*(sc: SegmentedControl): int =
  when defined(macosx) or defined(ios) or defined(linux):
    int(naSegmentedCount(sc.native))
  else:
    0

proc getSelectedIndex*(sc: SegmentedControl): int =
  when defined(macosx) or defined(ios) or defined(linux):
    int(naSegmentedSelected(sc.native))
  else:
    -1

proc selectIndex*(sc: SegmentedControl, index: int) =
  when defined(macosx) or defined(ios) or defined(linux):
    naSegmentedSelect(sc.native, index.int64)

proc onSelect*(sc: SegmentedControl, handler: proc(e: SegmentedSelectEvent)): ListenerId =
  addListener[GuiEvent, SegmentedSelectEvent](sc, handler)

proc fireSelect*(sc: SegmentedControl) =
  ## Full-stack test hook.
  when defined(macosx) or defined(ios) or defined(linux):
    naSegmentedFire(sc.nativeKey, sc.native)
