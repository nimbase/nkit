import std/[tables]
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
  ButtonStyle* = enum
    bsPush
    bsMomentaryPush
    bsToggle
    bsCheckBox
    bsRadio

  ControlState* = enum
    csOff
    csOn
    csMixed

  ButtonClickEvent* = ref object of GuiEvent
    buttonId*: Id

  Button* = ref object of View
    style*: ButtonStyle

var liveButtons: Table[uint32, Button]

method typeName(e: ButtonClickEvent): string = "ButtonClickEvent"

proc newButtonClickEvent*(buttonId: Id): ButtonClickEvent =
  result = ButtonClickEvent(buttonId: buttonId)
  discard stamp(result)

when defined(macosx) or defined(ios) or defined(linux):
  proc buttonEventTrampoline(widgetId: uint32, ctx: pointer) {.cdecl.} =
    let b = liveButtons.getOrDefault(widgetId)
    if not b.isNil:
      emitAsync(b, newButtonClickEvent(b.id))

var buttonCallbacksArmed = false

proc ensureButtonCallbacks*() =
  when defined(macosx) or defined(ios) or defined(linux):
    if not buttonCallbacksArmed:
      naButtonSetEventCallback(buttonEventTrampoline, nil)
      buttonCallbacksArmed = true

proc newButton*(title = "", style: ButtonStyle = bsPush): Button =
  ensureButtonCallbacks()
  let vid = allocate(typeTagGuiWidget)
  when defined(macosx) or defined(ios) or defined(linux):
    let nativePtr = naButtonCreate(vid.uint32, cint(ord(style)))
  else:
    let nativePtr: pointer = nil
  result = Button(style: style)
  discard wrapView(result, nativePtr, vid)
  liveButtons[vid.uint32] = result
  when defined(macosx) or defined(ios) or defined(linux):
    if title.len > 0:
      naButtonSetTitle(result.native, title.cstring)

proc destroy*(b: Button) =
  when defined(macosx) or defined(ios) or defined(linux):
    naButtonFree(b.nativeKey, b.native)
    b.native = nil
  liveButtons.del(b.nativeKey)
  shutdownEmitter[GuiEvent](b)

proc setTitle*(b: Button, title: string) =
  when defined(macosx) or defined(ios) or defined(linux):
    naButtonSetTitle(b.native, title.cstring)

proc getTitle*(b: Button): string =
  when defined(macosx) or defined(ios) or defined(linux):
    $naButtonGetTitle(b.native)
  else:
    ""

proc setState*(b: Button, state: ControlState) =
  when defined(macosx) or defined(ios) or defined(linux):
    naButtonSetState(b.native, cint(ord(state)))

proc setEnabled*(b: Button, enabled: bool) =
  when defined(macosx) or defined(ios) or defined(linux):
    naButtonSetEnabled(b.native, enabled)

proc isEnabled*(b: Button): bool =
  when defined(macosx) or defined(ios) or defined(linux):
    naButtonIsEnabled(b.native)
  else:
    false

proc getState*(b: Button): ControlState =
  when defined(macosx) or defined(ios) or defined(linux):
    ControlState(naButtonGetState(b.native))
  else:
    csOff

proc onClick*(b: Button, handler: proc(e: ButtonClickEvent)): ListenerId {.discardable.} =
  addListener[GuiEvent, ButtonClickEvent](b, handler)

proc fireClick*(b: Button) =
  ## Full-stack test hook: fires the native target as a real click would.
  when defined(macosx) or defined(ios) or defined(linux):
    naButtonFire(b.nativeKey)
