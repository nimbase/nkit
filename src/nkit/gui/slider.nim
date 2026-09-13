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
  SliderChangedEvent* = ref object of GuiEvent
    sliderId*: Id
    value*: float64

  SliderReleasedEvent* = ref object of GuiEvent
    sliderId*: Id
    value*: float64

  Slider* = ref object of View

var liveSliders: Table[uint32, Slider]

method typeName(e: SliderChangedEvent): string = "SliderChangedEvent"
method typeName(e: SliderReleasedEvent): string = "SliderReleasedEvent"

proc newSliderChangedEvent*(sliderId: Id, value: float64): SliderChangedEvent =
  result = SliderChangedEvent(sliderId: sliderId, value: value)
  discard stamp(result)

proc newSliderReleasedEvent*(sliderId: Id, value: float64): SliderReleasedEvent =
  result = SliderReleasedEvent(sliderId: sliderId, value: value)
  discard stamp(result)

when defined(macosx) or defined(ios) or defined(linux):
  proc sliderEventTrampoline(widgetId: uint32, value: float64, released: bool, ctx: pointer) {.
      cdecl.} =
    let s = liveSliders.getOrDefault(widgetId)
    if not s.isNil:
      if released:
        emitAsync(s, newSliderReleasedEvent(s.id, value))
      else:
        emitAsync(s, newSliderChangedEvent(s.id, value))

var sliderCallbacksArmed = false

proc ensureSliderCallbacks*() =
  when defined(macosx) or defined(ios) or defined(linux):
    if not sliderCallbacksArmed:
      naSliderSetEventCallback(sliderEventTrampoline, nil)
      sliderCallbacksArmed = true

proc newSlider*(minValue = 0.0, maxValue = 100.0, value = 0.0): Slider =
  ensureSliderCallbacks()
  let vid = allocate(typeTagGuiWidget)
  when defined(macosx) or defined(ios) or defined(linux):
    let nativePtr = naSliderCreate(vid.uint32)
  else:
    let nativePtr: pointer = nil
  result = Slider()
  discard wrapView(result, nativePtr, vid)
  liveSliders[vid.uint32] = result
  when defined(macosx) or defined(ios) or defined(linux):
    naSliderSetRange(result.native, minValue, maxValue)
    naSliderSetValue(result.native, value)

proc destroy*(s: Slider) =
  when defined(macosx) or defined(ios) or defined(linux):
    naSliderFree(s.nativeKey, s.native)
    s.native = nil
  liveSliders.del(s.nativeKey)
  shutdownEmitter[GuiEvent](s)

proc setRange*(s: Slider, minValue, maxValue: float64) =
  when defined(macosx) or defined(ios) or defined(linux):
    naSliderSetRange(s.native, minValue, maxValue)

proc getMinValue*(s: Slider): float64 =
  when defined(macosx) or defined(ios) or defined(linux):
    naSliderGetMin(s.native)
  else:
    0.0

proc getMaxValue*(s: Slider): float64 =
  when defined(macosx) or defined(ios) or defined(linux):
    naSliderGetMax(s.native)
  else:
    0.0

proc setValue*(s: Slider, value: float64) =
  when defined(macosx) or defined(ios) or defined(linux):
    naSliderSetValue(s.native, value)

proc getValue*(s: Slider): float64 =
  when defined(macosx) or defined(ios) or defined(linux):
    naSliderGetValue(s.native)
  else:
    0.0

proc onChanged*(s: Slider, handler: proc(e: SliderChangedEvent)): ListenerId =
  addListener[GuiEvent, SliderChangedEvent](s, handler)

proc onReleased*(s: Slider, handler: proc(e: SliderReleasedEvent)): ListenerId =
  addListener[GuiEvent, SliderReleasedEvent](s, handler)
