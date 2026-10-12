import std/tables
import ../foundation/id_allocator
import ../foundation/event
import ../foundation/event_emitter
import ../foundation/color
import ./view

when defined(ios):
  import ../platform/ios/uifunctions
elif defined(macosx):
  import ../platform/macos/nsfunctions
elif defined(linux):
  import ../platform/linux/gfunctions

export view, color

type
  ColorChangedEvent* = ref object of GuiEvent
    colorId*: Id
    color*: Color

  ColorWell* = ref object of View

var liveColorWells: Table[uint32, ColorWell]

method typeName(e: ColorChangedEvent): string = "ColorChangedEvent"

proc newColorChangedEvent*(colorId: Id, color: Color): ColorChangedEvent =
  result = ColorChangedEvent(colorId: colorId, color: color)
  discard stamp(result)

when defined(macosx) or defined(ios) or defined(linux):
  proc colorwellEventTrampoline(widgetId: uint32, ctx: pointer) {.cdecl.} =
    let w = liveColorWells.getOrDefault(widgetId)
    if not w.isNil:
      var r, g, b, a: uint8
      naColorwellGetColor(w.native, addr r, addr g, addr b, addr a)
      emitAsync(w, newColorChangedEvent(w.id, color(r, g, b, a)))

var colorwellCallbacksArmed = false

proc ensureColorwellCallbacks*() =
  when defined(macosx) or defined(ios) or defined(linux):
    if not colorwellCallbacksArmed:
      naColorwellSetEventCallback(colorwellEventTrampoline, nil)
      colorwellCallbacksArmed = true

proc newColorWell*(initial = color(0, 122, 255)): ColorWell =
  ## A native color picker swatch (NSColorWell / UIColorWell /
  ## GtkColorButton). Tapping it opens the platform color panel; the
  ## chosen color arrives as a `ColorChangedEvent`.
  ensureColorwellCallbacks()
  let vid = allocate(typeTagGuiWidget)
  when defined(macosx) or defined(ios) or defined(linux):
    let nativePtr = naColorwellCreate(vid.uint32)
  else:
    let nativePtr: pointer = nil
  result = ColorWell()
  discard wrapView(result, nativePtr, vid)
  liveColorWells[vid.uint32] = result
  when defined(macosx) or defined(ios) or defined(linux):
    naColorwellSetColor(result.native, initial.r, initial.g, initial.b,
                        initial.a)

proc destroy*(w: ColorWell) =
  when defined(macosx) or defined(ios) or defined(linux):
    naColorwellFree(w.nativeKey, w.native)
    w.native = nil
  liveColorWells.del(w.nativeKey)
  shutdownEmitter[GuiEvent](w)

proc setColor*(w: ColorWell, c: Color) =
  when defined(macosx) or defined(ios) or defined(linux):
    naColorwellSetColor(w.native, c.r, c.g, c.b, c.a)

proc getColor*(w: ColorWell): Color =
  when defined(macosx) or defined(ios) or defined(linux):
    var r, g, b, a: uint8
    naColorwellGetColor(w.native, addr r, addr g, addr b, addr a)
    color(r, g, b, a)
  else:
    color(0, 0, 0, 0)

proc setEnabled*(w: ColorWell, enabled: bool) =
  when defined(macosx) or defined(ios) or defined(linux):
    naColorwellSetEnabled(w.native, enabled)

proc isEnabled*(w: ColorWell): bool =
  when defined(macosx) or defined(ios) or defined(linux):
    naColorwellIsEnabled(w.native)
  else:
    false

proc onColorChanged*(w: ColorWell,
                     handler: proc(e: ColorChangedEvent)): ListenerId {.discardable.} =
  addListener[GuiEvent, ColorChangedEvent](w, handler)

proc fireChange*(w: ColorWell) =
  ## Full-stack test hook.
  when defined(macosx) or defined(ios) or defined(linux):
    naColorwellFire(w.nativeKey)
