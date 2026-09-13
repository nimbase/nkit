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
  InputStyle* = enum
    istSingleLine
    istSecure
    istSearch

  InputChangedEvent* = ref object of GuiEvent
    inputId*: Id

  InputSubmittedEvent* = ref object of GuiEvent
    inputId*: Id

  InputFocusEvent* = ref object of GuiEvent
    inputId*: Id

  InputBlurEvent* = ref object of GuiEvent
    inputId*: Id

  InputHoverEvent* = ref object of GuiEvent
    inputId*: Id
    entered*: bool

  InputKeyEvent* = ref object of GuiEvent
    inputId*: Id
    keyval*: uint32
    keycode*: uint32
    modifiers*: uint32
    isPressed*: bool

  Input* = ref object of View
    style*: InputStyle

var liveInputs: Table[uint32, Input]

method typeName(e: InputChangedEvent): string = "InputChangedEvent"
method typeName(e: InputSubmittedEvent): string = "InputSubmittedEvent"
method typeName(e: InputFocusEvent): string = "InputFocusEvent"
method typeName(e: InputBlurEvent): string = "InputBlurEvent"
method typeName(e: InputHoverEvent): string = "InputHoverEvent"
method typeName(e: InputKeyEvent): string = "InputKeyEvent"

proc newInputChangedEvent*(inputId: Id): InputChangedEvent =
  result = InputChangedEvent(inputId: inputId)
  discard stamp(result)

proc newInputSubmittedEvent*(inputId: Id): InputSubmittedEvent =
  result = InputSubmittedEvent(inputId: inputId)
  discard stamp(result)

proc newInputFocusEvent*(inputId: Id): InputFocusEvent =
  result = InputFocusEvent(inputId: inputId)
  discard stamp(result)

proc newInputBlurEvent*(inputId: Id): InputBlurEvent =
  result = InputBlurEvent(inputId: inputId)
  discard stamp(result)

proc newInputHoverEvent*(inputId: Id, entered: bool): InputHoverEvent =
  result = InputHoverEvent(inputId: inputId, entered: entered)
  discard stamp(result)

proc newInputKeyEvent*(inputId: Id, keyval, keycode, mods: uint32,
                       pressed: bool): InputKeyEvent =
  result = InputKeyEvent(inputId: inputId, keyval: keyval, keycode: keycode,
                         modifiers: mods, isPressed: pressed)
  discard stamp(result)

when defined(macosx) or defined(ios) or defined(linux):
  proc inputEventTrampoline(widgetId: uint32, ctx: pointer) {.cdecl.} =
    let inp = liveInputs.getOrDefault(widgetId)
    if inp.isNil:
      return
    if ctx == nil:
      emitAsync(inp, newInputChangedEvent(inp.id))
    else:
      emitAsync(inp, newInputSubmittedEvent(inp.id))

  proc inputFocusTrampoline(widgetId: uint32, focused: bool, ctx: pointer) {.cdecl.} =
    let inp = liveInputs.getOrDefault(widgetId)
    if inp.isNil: return
    if focused:
      emitAsync(inp, newInputFocusEvent(inp.id))
    else:
      emitAsync(inp, newInputBlurEvent(inp.id))

  proc inputHoverTrampoline(widgetId: uint32, entered: bool, ctx: pointer) {.cdecl.} =
    let inp = liveInputs.getOrDefault(widgetId)
    if inp.isNil: return
    emitAsync(inp, newInputHoverEvent(inp.id, entered))

  proc inputKeyTrampoline(widgetId: uint32, keyval, keycode, mods: uint32,
                          pressed: bool, ctx: pointer) {.cdecl.} =
    let inp = liveInputs.getOrDefault(widgetId)
    if inp.isNil: return
    emitAsync(inp, newInputKeyEvent(inp.id, keyval, keycode, mods, pressed))

var inputCallbacksArmed = false
var inputFocusArmed = false
var inputHoverArmed = false
var inputKeyArmed = false

proc ensureInputCallbacks*() =
  when defined(macosx) or defined(ios) or defined(linux):
    if not inputCallbacksArmed:
      naInputSetEventCallback(inputEventTrampoline, nil)
      inputCallbacksArmed = true

proc ensureInputFocusCallbacks*() =
  when defined(macosx) or defined(ios) or defined(linux):
    if not inputFocusArmed:
      naInputSetFocusCallback(inputFocusTrampoline, nil)
      inputFocusArmed = true

proc ensureInputHoverCallbacks*() =
  when defined(macosx) or defined(ios) or defined(linux):
    if not inputHoverArmed:
      naInputSetHoverCallback(inputHoverTrampoline, nil)
      inputHoverArmed = true

proc ensureInputKeyCallbacks*() =
  when defined(macosx) or defined(ios) or defined(linux):
    if not inputKeyArmed:
      naInputSetKeyCallback(inputKeyTrampoline, nil)
      inputKeyArmed = true

proc newInput*(placeholder = "", style: InputStyle = istSingleLine): Input =
  ensureInputCallbacks()
  ensureInputFocusCallbacks()
  ensureInputHoverCallbacks()
  ensureInputKeyCallbacks()
  let vid = allocate(typeTagGuiWidget)
  when defined(macosx) or defined(ios) or defined(linux):
    let nativePtr = naInputCreate(vid.uint32, cint(ord(style)))
  else:
    let nativePtr: pointer = nil
  result = Input(style: style)
  discard wrapView(result, nativePtr, vid)
  liveInputs[vid.uint32] = result
  when defined(macosx) or defined(ios) or defined(linux):
    if placeholder.len > 0:
      naInputSetPlaceholder(result.native, placeholder.cstring)

proc newSearchField*(placeholder = ""): Input {.inline.} =
  newInput(placeholder, istSearch)

proc newPasswordField*(placeholder = ""): Input {.inline.} =
  newInput(placeholder, istSecure)

proc destroy*(inp: Input) =
  when defined(macosx) or defined(ios) or defined(linux):
    naInputFree(inp.nativeKey, inp.native)
    inp.native = nil
  liveInputs.del(inp.nativeKey)
  shutdownEmitter[GuiEvent](inp)

proc setText*(inp: Input, text: string) =
  when defined(macosx) or defined(ios) or defined(linux):
    naInputSetText(inp.native, text.cstring)

proc getText*(inp: Input): string =
  when defined(macosx) or defined(ios) or defined(linux):
    $naInputGetText(inp.native)
  else:
    ""

proc setPlaceholder*(inp: Input, placeholder: string) =
  when defined(macosx) or defined(ios) or defined(linux):
    naInputSetPlaceholder(inp.native, placeholder.cstring)

proc getPlaceholder*(inp: Input): string =
  when defined(macosx) or defined(ios) or defined(linux):
    $naInputGetPlaceholder(inp.native)
  else:
    ""

proc setEditable*(inp: Input, editable: bool) =
  when defined(macosx) or defined(ios) or defined(linux):
    naInputSetEditable(inp.native, editable)

proc isEditable*(inp: Input): bool =
  when defined(macosx) or defined(ios) or defined(linux):
    naInputIsEditable(inp.native)
  else:
    false

proc focus*(inp: Input) =
  when defined(macosx) or defined(ios) or defined(linux):
    naInputFocus(inp.nativeKey, inp.native)

proc onChanged*(inp: Input, handler: proc(e: InputChangedEvent)): ListenerId =
  addListener[GuiEvent, InputChangedEvent](inp, handler)

proc onSubmitted*(inp: Input, handler: proc(e: InputSubmittedEvent)): ListenerId =
  addListener[GuiEvent, InputSubmittedEvent](inp, handler)

proc onFocus*(inp: Input, handler: proc(e: InputFocusEvent)): ListenerId =
  addListener[GuiEvent, InputFocusEvent](inp, handler)

proc onBlur*(inp: Input, handler: proc(e: InputBlurEvent)): ListenerId =
  addListener[GuiEvent, InputBlurEvent](inp, handler)

proc onHover*(inp: Input, handler: proc(e: InputHoverEvent)): ListenerId =
  addListener[GuiEvent, InputHoverEvent](inp, handler)

proc onKey*(inp: Input, handler: proc(e: InputKeyEvent)): ListenerId =
  addListener[GuiEvent, InputKeyEvent](inp, handler)

proc fireChange*(inp: Input) =
  ## Full-stack test hook: fires the native change path.
  when defined(macosx) or defined(ios) or defined(linux):
    naInputFireChange(inp.nativeKey)

proc fireSubmit*(inp: Input) =
  ## Full-stack test hook: fires the native submit path.
  when defined(macosx) or defined(ios) or defined(linux):
    naInputFireSubmit(inp.nativeKey)

proc fireFocus*(inp: Input, focused: bool) =
  ## Full-stack test hook: fires the native focus path.
  when defined(linux):
    naInputFireFocus(inp.nativeKey, focused)

proc fireHover*(inp: Input, entered: bool) =
  ## Full-stack test hook: fires the native hover path.
  when defined(linux):
    naInputFireHover(inp.nativeKey, entered)
