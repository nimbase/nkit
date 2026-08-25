import std/tables
import nkit/foundation/id_allocator
import nkit/foundation/event
import nkit/foundation/event_emitter
import nkit/gui/view

when defined(macosx) or defined(ios):
  import nkit/platform/macos/nsfunctions

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

  Input* = ref object of View
    style*: InputStyle

var liveInputs: Table[uint32, Input]

method typeName(e: InputChangedEvent): string = "InputChangedEvent"
method typeName(e: InputSubmittedEvent): string = "InputSubmittedEvent"

proc newInputChangedEvent*(inputId: Id): InputChangedEvent =
  result = InputChangedEvent(inputId: inputId)
  discard stamp(result)

proc newInputSubmittedEvent*(inputId: Id): InputSubmittedEvent =
  result = InputSubmittedEvent(inputId: inputId)
  discard stamp(result)

when defined(macosx) or defined(ios):
  proc inputEventTrampoline(widgetId: uint32, ctx: pointer) {.cdecl.} =
    let inp = liveInputs.getOrDefault(widgetId)
    if inp.isNil:
      return
    if ctx == nil:
      emitAsync(inp, newInputChangedEvent(inp.id))
    else:
      emitAsync(inp, newInputSubmittedEvent(inp.id))

var inputCallbacksArmed = false

proc ensureInputCallbacks*() =
  when defined(macosx) or defined(ios):
    if not inputCallbacksArmed:
      naInputSetEventCallback(inputEventTrampoline, nil)
      inputCallbacksArmed = true

proc newInput*(placeholder = "", style: InputStyle = istSingleLine): Input =
  ensureInputCallbacks()
  let vid = allocate(typeTagGuiWidget)
  when defined(macosx) or defined(ios):
    let nativePtr = naInputCreate(vid.uint32, cint(ord(style)))
  else:
    let nativePtr: pointer = nil
  result = Input(style: style)
  discard wrapView(result, nativePtr, vid)
  liveInputs[vid.uint32] = result
  when defined(macosx) or defined(ios):
    if placeholder.len > 0:
      naInputSetPlaceholder(result.native, placeholder.cstring)

proc newSearchField*(placeholder = ""): Input {.inline.} =
  newInput(placeholder, istSearch)

proc newPasswordField*(placeholder = ""): Input {.inline.} =
  newInput(placeholder, istSecure)

proc destroy*(inp: Input) =
  when defined(macosx) or defined(ios):
    naInputFree(inp.nativeKey, inp.native)
    inp.native = nil
  liveInputs.del(inp.nativeKey)
  shutdownEmitter[GuiEvent](inp)

proc setText*(inp: Input, text: string) =
  when defined(macosx) or defined(ios):
    naInputSetText(inp.native, text.cstring)

proc getText*(inp: Input): string =
  when defined(macosx) or defined(ios):
    $naInputGetText(inp.native)
  else:
    ""

proc setPlaceholder*(inp: Input, placeholder: string) =
  when defined(macosx) or defined(ios):
    naInputSetPlaceholder(inp.native, placeholder.cstring)

proc getPlaceholder*(inp: Input): string =
  when defined(macosx) or defined(ios):
    $naInputGetPlaceholder(inp.native)
  else:
    ""

proc setEditable*(inp: Input, editable: bool) =
  when defined(macosx) or defined(ios):
    naInputSetEditable(inp.native, editable)

proc isEditable*(inp: Input): bool =
  when defined(macosx) or defined(ios):
    naInputIsEditable(inp.native)
  else:
    false

proc focus*(inp: Input) =
  when defined(macosx) or defined(ios):
    naInputFocus(inp.nativeKey, inp.native)

proc onChanged*(inp: Input, handler: proc(e: InputChangedEvent)): ListenerId =
  addListener[GuiEvent, InputChangedEvent](inp, handler)

proc onSubmitted*(inp: Input, handler: proc(e: InputSubmittedEvent)): ListenerId =
  addListener[GuiEvent, InputSubmittedEvent](inp, handler)

proc fireChange*(inp: Input) =
  ## Full-stack test hook: fires the native change path.
  when defined(macosx) or defined(ios):
    naInputFireChange(inp.nativeKey)
