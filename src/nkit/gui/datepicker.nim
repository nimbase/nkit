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
  DatePickerStyle* = enum
    dpsTextField
    dpsClockAndCalendar

  DateChangedEvent* = ref object of GuiEvent
    datePickerId*: Id
    unixSeconds*: float64

  DatePicker* = ref object of View

var liveDatePickers: Table[uint32, DatePicker]

method typeName(e: DateChangedEvent): string = "DateChangedEvent"

proc newDateChangedEvent*(datePickerId: Id, unixSeconds: float64): DateChangedEvent =
  result = DateChangedEvent(datePickerId: datePickerId, unixSeconds: unixSeconds)
  discard stamp(result)

when defined(macosx) or defined(ios):
  proc datepickerEventTrampoline(widgetId: uint32, seconds: float64, ctx: pointer) {.cdecl.} =
    let dp = liveDatePickers.getOrDefault(widgetId)
    if not dp.isNil:
      emitAsync(dp, newDateChangedEvent(dp.id, seconds))

var datepickerCallbacksArmed = false

proc ensureDatePickerCallbacks*() =
  when defined(macosx) or defined(ios):
    if not datepickerCallbacksArmed:
      naDatePickerSetEventCallback(datepickerEventTrampoline, nil)
      datepickerCallbacksArmed = true

proc newDatePicker*(style: DatePickerStyle = dpsTextField): DatePicker =
  ensureDatePickerCallbacks()
  let vid = allocate(typeTagGuiWidget)
  when defined(macosx) or defined(ios):
    let nativePtr = naDatePickerCreate(vid.uint32, cint(ord(style)))
  else:
    let nativePtr: pointer = nil
  result = DatePicker()
  discard wrapView(result, nativePtr, vid)
  liveDatePickers[vid.uint32] = result

proc destroy*(dp: DatePicker) =
  when defined(macosx) or defined(ios):
    naDatePickerFree(dp.nativeKey, dp.native)
    dp.native = nil
  liveDatePickers.del(dp.nativeKey)
  shutdownEmitter[GuiEvent](dp)

proc setUnixSeconds*(dp: DatePicker, seconds: float64) =
  when defined(macosx) or defined(ios):
    naDatePickerSetUnixSeconds(dp.native, seconds)

proc getUnixSeconds*(dp: DatePicker): float64 =
  when defined(macosx) or defined(ios):
    naDatePickerGetUnixSeconds(dp.native)
  else:
    0.0

proc onDateChanged*(dp: DatePicker, handler: proc(e: DateChangedEvent)): ListenerId {.discardable.} =
  addListener[GuiEvent, DateChangedEvent](dp, handler)
