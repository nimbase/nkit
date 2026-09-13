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

  TextArea* = ref object of View

var liveTextAreas: Table[uint32, TextArea]

method typeName(e: TextAreaChangedEvent): string = "TextAreaChangedEvent"

proc newTextAreaChangedEvent*(textAreaId: Id): TextAreaChangedEvent =
  result = TextAreaChangedEvent(textAreaId: textAreaId)
  discard stamp(result)

when defined(macosx) or defined(ios) or defined(linux):
  proc textAreaEventTrampoline(widgetId: uint32, ctx: pointer) {.cdecl.} =
    let ta = liveTextAreas.getOrDefault(widgetId)
    if not ta.isNil:
      emitAsync(ta, newTextAreaChangedEvent(ta.id))

var textAreaCallbacksArmed = false

proc ensureTextAreaCallbacks*() =
  when defined(macosx) or defined(ios) or defined(linux):
    if not textAreaCallbacksArmed:
      naTextAreaSetEventCallback(textAreaEventTrampoline, nil)
      textAreaCallbacksArmed = true

proc newTextArea*(text = ""): TextArea =
  ensureTextAreaCallbacks()
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

proc onChanged*(ta: TextArea, handler: proc(e: TextAreaChangedEvent)): ListenerId =
  addListener[GuiEvent, TextAreaChangedEvent](ta, handler)

proc fireChange*(ta: TextArea) =
  ## Full-stack test hook.
  when defined(macosx) or defined(ios) or defined(linux):
    naTextAreaFireChange(ta.nativeKey)
