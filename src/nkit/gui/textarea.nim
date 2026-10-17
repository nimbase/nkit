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
  TextAreaChangedEvent* = ref object of GuiEvent
    textAreaId*: Id

  TextAreaFocusEvent* = ref object of GuiEvent
    textAreaId*: Id

  TextAreaBlurEvent* = ref object of GuiEvent
    textAreaId*: Id

  TextArea* = ref object of View

var liveTextAreas: Table[uint32, TextArea]

method typeName(e: TextAreaChangedEvent): string = "TextAreaChangedEvent"
method typeName(e: TextAreaFocusEvent): string = "TextAreaFocusEvent"
method typeName(e: TextAreaBlurEvent): string = "TextAreaBlurEvent"

proc newTextAreaChangedEvent*(textAreaId: Id): TextAreaChangedEvent =
  result = TextAreaChangedEvent(textAreaId: textAreaId)
  discard stamp(result)

proc newTextAreaFocusEvent*(textAreaId: Id): TextAreaFocusEvent =
  result = TextAreaFocusEvent(textAreaId: textAreaId)
  discard stamp(result)

proc newTextAreaBlurEvent*(textAreaId: Id): TextAreaBlurEvent =
  result = TextAreaBlurEvent(textAreaId: textAreaId)
  discard stamp(result)

when defined(macosx) or defined(ios) or defined(linux):
  proc textAreaEventTrampoline(widgetId: uint32, ctx: pointer) {.cdecl.} =
    let ta = liveTextAreas.getOrDefault(widgetId)
    if not ta.isNil:
      emitAsync(ta, newTextAreaChangedEvent(ta.id))

  proc textAreaFocusTrampoline(widgetId: uint32, focused: bool,
                               ctx: pointer) {.cdecl.} =
    let ta = liveTextAreas.getOrDefault(widgetId)
    if ta.isNil: return
    if focused:
      emitAsync(ta, newTextAreaFocusEvent(ta.id))
    else:
      emitAsync(ta, newTextAreaBlurEvent(ta.id))

var textAreaCallbacksArmed = false
var textAreaFocusArmed = false

proc ensureTextAreaCallbacks*() =
  when defined(macosx) or defined(ios) or defined(linux):
    if not textAreaCallbacksArmed:
      naTextAreaSetEventCallback(textAreaEventTrampoline, nil)
      textAreaCallbacksArmed = true

proc ensureTextAreaFocusCallbacks*() =
  when defined(macosx):
    if not textAreaFocusArmed:
      naTextAreaSetFocusCallback(textAreaFocusTrampoline, nil)
      textAreaFocusArmed = true

proc newTextArea*(text = ""): TextArea =
  ensureTextAreaCallbacks()
  ensureTextAreaFocusCallbacks()
  let vid = allocate(typeTagGuiWidget)
  when defined(macosx) or defined(ios) or defined(linux):
    let nativePtr = naTextAreaCreate(vid.uint32)
  else:
    let nativePtr: pointer = nil
  result = TextArea()
  discard wrapView(result, nativePtr, vid)
  liveTextAreas[vid.uint32] = result
  when defined(macosx) or defined(ios) or defined(linux):
    if text.len > 0:
      naTextAreaSetText(result.nativeKey, result.native, text.cstring)

proc destroy*(ta: TextArea) =
  when defined(macosx) or defined(ios) or defined(linux):
    naTextAreaFree(ta.nativeKey, ta.native)
    ta.native = nil
  liveTextAreas.del(ta.nativeKey)
  shutdownEmitter[GuiEvent](ta)

proc setText*(ta: TextArea, text: string) =
  when defined(macosx) or defined(ios) or defined(linux):
    naTextAreaSetText(ta.nativeKey, ta.native, text.cstring)

proc getText*(ta: TextArea): string =
  when defined(macosx) or defined(ios) or defined(linux):
    $naTextAreaGetText(ta.nativeKey, ta.native)
  else:
    ""

proc setEditable*(ta: TextArea, editable: bool) =
  when defined(macosx) or defined(ios) or defined(linux):
    naTextAreaSetEditable(ta.nativeKey, ta.native, editable)

proc isEditable*(ta: TextArea): bool =
  when defined(macosx) or defined(ios) or defined(linux):
    naTextAreaIsEditable(ta.nativeKey, ta.native)
  else:
    false

proc setAllowsUndo*(ta: TextArea, allow: bool) =
  ## Toggles the built-in per-keystroke text undo. Disable it when the
  ## app manages undo itself (e.g. at model level) so the two histories
  ## can't fight over the same keystrokes. No-op off macOS for now.
  when defined(macosx):
    naTextAreaSetAllowsUndo(ta.nativeKey, ta.native, allow)

proc onChanged*(ta: TextArea, handler: proc(e: TextAreaChangedEvent)): ListenerId =
  addListener[GuiEvent, TextAreaChangedEvent](ta, handler)

proc onFocus*(ta: TextArea, handler: proc(e: TextAreaFocusEvent)): ListenerId =
  addListener[GuiEvent, TextAreaFocusEvent](ta, handler)

proc onBlur*(ta: TextArea, handler: proc(e: TextAreaBlurEvent)): ListenerId =
  addListener[GuiEvent, TextAreaBlurEvent](ta, handler)

proc fireChange*(ta: TextArea) =
  ## Full-stack test hook.
  when defined(macosx) or defined(ios) or defined(linux):
    naTextAreaFireChange(ta.nativeKey)

proc fireFocus*(ta: TextArea, focused: bool) =
  ## Full-stack test hook: drives the focus/blur event path.
  when defined(macosx):
    naTextAreaFireFocus(ta.nativeKey, focused)
