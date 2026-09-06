import ./foundation/event
import ./foundation/keyboard
import ./foundation/event_emitter

when defined(ios):
  import ./platform/ios/uifunctions
elif defined(macosx):
  import ./platform/macos/nsfunctions
elif defined(linux):
  import ./platform/linux/gfunctions

type KeyboardMonitor* = ref object of EventEmitter[KeyboardEvent]
  running*: bool

var globalKeyboardSink: proc(kind: int, keycode: int, modifiers: uint32) {.closure.}

when defined(macosx) or defined(linux):
  proc keyboardTrampoline(kind: cint, keycode: cint, modifiers: cuint, ctx: pointer) {.cdecl.} =
    if not globalKeyboardSink.isNil:
      globalKeyboardSink(int(kind), int(keycode), uint32(modifiers))

proc newKeyboardMonitor*(): KeyboardMonitor =
  result = KeyboardMonitor(running: false)
  initEmitter(result)

proc start*(km: KeyboardMonitor): bool =
  if km.running:
    return true
  when defined(macosx) or defined(linux):
    let selfRef = km
    if globalKeyboardSink.isNil:
      globalKeyboardSink = proc(kind: int, keycode: int, modifiers: uint32) =
        case kind
        of 0:
          selfRef.emit(newKeyPressedEvent(keycode))
        of 1:
          selfRef.emit(newKeyReleasedEvent(keycode))
        of 2:
          selfRef.emit(newModifierKeysChangedEvent(modifiers))
        else:
          discard
    if naKeyboardStart(keyboardTrampoline, nil):
      km.running = true
      return true
    return false
  else:
    false

proc stop*(km: KeyboardMonitor) =
  when defined(macosx) or defined(linux):
    if km.running:
      naKeyboardStop()
      km.running = false

proc isMonitoring*(km: KeyboardMonitor): bool =
  when defined(macosx) or defined(linux):
    naKeyboardIsRunning()
  else:
    false
