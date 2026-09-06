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
  SwitchToggledEvent* = ref object of GuiEvent
    switchId*: Id
    isOn*: bool

  SwitchWidget* = ref object of View

var liveSwitches: Table[uint32, SwitchWidget]

method typeName(e: SwitchToggledEvent): string = "SwitchToggledEvent"

proc newSwitchToggledEvent*(switchId: Id, isOn: bool): SwitchToggledEvent =
  result = SwitchToggledEvent(switchId: switchId, isOn: isOn)
  discard stamp(result)

when defined(macosx) or defined(ios) or defined(linux):
  proc switchEventTrampoline(widgetId: uint32, ctx: pointer) {.cdecl.} =
    let sw = liveSwitches.getOrDefault(widgetId)
    if not sw.isNil:
      emitAsync(sw, newSwitchToggledEvent(sw.id, naSwitchGetState(sw.native)))

var switchCallbacksArmed = false

proc ensureSwitchCallbacks*() =
  when defined(macosx) or defined(ios) or defined(linux):
    if not switchCallbacksArmed:
      naSwitchSetEventCallback(switchEventTrampoline, nil)
      switchCallbacksArmed = true

proc newSwitch*(isOn = false): SwitchWidget =
  ensureSwitchCallbacks()
  let vid = allocate(typeTagGuiWidget)
  when defined(macosx) or defined(ios) or defined(linux):
    let nativePtr = naSwitchCreate(vid.uint32)
  else:
    let nativePtr: pointer = nil
  result = SwitchWidget()
  discard wrapView(result, nativePtr, vid)
  liveSwitches[vid.uint32] = result
  when defined(macosx) or defined(ios) or defined(linux):
    if isOn:
      naSwitchSetState(result.native, true)

proc destroy*(sw: SwitchWidget) =
  when defined(macosx) or defined(ios) or defined(linux):
    naSwitchFree(sw.nativeKey, sw.native)
    sw.native = nil
  liveSwitches.del(sw.nativeKey)
  shutdownEmitter[GuiEvent](sw)

proc setState*(sw: SwitchWidget, on: bool) =
  when defined(macosx) or defined(ios) or defined(linux):
    naSwitchSetState(sw.native, on)

proc getState*(sw: SwitchWidget): bool =
  when defined(macosx) or defined(ios) or defined(linux):
    naSwitchGetState(sw.native)
  else:
    false

proc onToggled*(sw: SwitchWidget, handler: proc(e: SwitchToggledEvent)): ListenerId {.discardable.} =
  addListener[GuiEvent, SwitchToggledEvent](sw, handler)

proc fireToggle*(sw: SwitchWidget) =
  ## Full-stack test hook.
  when defined(macosx) or defined(ios) or defined(linux):
    naSwitchFire(sw.nativeKey)
