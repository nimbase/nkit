import nkit/foundation/event

type
  ShortcutId* = distinct uint32

  ShortcutScope* = enum
    ssGlobal
    ssApplication

func `==`*(a, b: ShortcutId): bool {.borrow.}

type ShortcutOptions* = object
  accelerator*: string
  callback*: proc() {.closure.}
  description*: string
  scope*: ShortcutScope
  enabled*: bool

proc defaultShortcutOptions*(accelerator: string): ShortcutOptions =
  ShortcutOptions(
    accelerator: accelerator,
    callback: nil,
    description: "",
    scope: ssGlobal,
    enabled: true)

type
  ShortcutEvent* = ref object of Event
    shortcutId*: ShortcutId
    accelerator*: string
  ShortcutActivatedEvent* = ref object of ShortcutEvent
  ShortcutRegisteredEvent* = ref object of ShortcutEvent
  ShortcutUnregisteredEvent* = ref object of ShortcutEvent
  ShortcutRegistrationFailedEvent* = ref object of ShortcutEvent
    errorMessage*: string

method typeName(e: ShortcutEvent): string = "ShortcutEvent"
method typeName(e: ShortcutActivatedEvent): string = "ShortcutActivatedEvent"
method typeName(e: ShortcutRegisteredEvent): string = "ShortcutRegisteredEvent"
method typeName(e: ShortcutUnregisteredEvent): string = "ShortcutUnregisteredEvent"
method typeName(e: ShortcutRegistrationFailedEvent): string = "ShortcutRegistrationFailedEvent"

proc newShortcutEvent*[T: ShortcutEvent](id: ShortcutId, accelerator: string): T =
  result = T(shortcutId: id, accelerator: accelerator)
  discard stamp(result)

proc newShortcutRegistrationFailedEvent*(id: ShortcutId,
                                         accelerator: string,
                                         errorMessage: string): ShortcutRegistrationFailedEvent =
  result = ShortcutRegistrationFailedEvent(
    shortcutId: id,
    accelerator: accelerator,
    errorMessage: errorMessage)
  discard stamp(result)
