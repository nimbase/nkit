import std/tables
import nkit/foundation/id_allocator
import nkit/foundation/event
import nkit/foundation/event_emitter
import nkit/gui/view
import nkit/platform/macos/nsfunctions

export view

type
  ToastVariant* = enum
    tvInfo
    tvSuccess
    tvWarning
    tvError

  ToastDismissedEvent* = ref object of GuiEvent
    toastId*: uint32

  ToastManager* = ref object of EventEmitter[GuiEvent]
    activeCount: int

var sharedToastInstance*: ToastManager
var toastCallbacksArmed = false

method typeName(e: ToastDismissedEvent): string = "ToastDismissedEvent"

proc newToastDismissedEvent*(toastId: uint32): ToastDismissedEvent =
  result = ToastDismissedEvent(toastId: toastId)
  discard stamp(result)

when defined(macosx) or defined(ios):
  proc toastDismissTrampoline(toastId: uint32, ctx: pointer) {.cdecl.} =
    if not sharedToastInstance.isNil:
      dec sharedToastInstance.activeCount
      emitAsync(sharedToastInstance, newToastDismissedEvent(toastId))

proc ensureToastCallbacks*() =
  when defined(macosx) or defined(ios):
    if not toastCallbacksArmed:
      naToastSetDismissCallback(toastDismissTrampoline, nil)
      toastCallbacksArmed = true

proc sharedToastManager*(): ToastManager =
  if sharedToastInstance.isNil:
    sharedToastInstance = ToastManager(activeCount: 0)
    initEmitter(sharedToastInstance)
    ensureToastCallbacks()
  result = sharedToastInstance

proc show*(tm: ToastManager, title: string, message = "", durationMs = 4000.0,
           width = 300.0): uint32 =
  ## Shows a floating toast notification in the bottom-right corner of the screen.
  when defined(macosx) or defined(ios):
    let offset = float64(tm.activeCount) * 92.0
    let id = naToastShow(title.cstring, message.cstring, durationMs, offset, width)
    inc tm.activeCount
    result = id
  else:
    result = 0

proc close*(tm: ToastManager, toastId: uint32) =
  when defined(macosx) or defined(ios):
    naToastClose(toastId)

proc activeToasts*(tm: ToastManager): int =
  when defined(macosx) or defined(ios):
    int(naToastActiveCount())
  else:
    0

proc onDismissed*(tm: ToastManager, handler: proc(e: ToastDismissedEvent)): ListenerId =
  addListener[GuiEvent, ToastDismissedEvent](tm, handler)
