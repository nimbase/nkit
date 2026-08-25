import nkit/foundation/event
import nkit/foundation/event_emitter
import nkit/platform/macos/nsfunctions

type
  NotificationEvent* = ref object of Event

  NotificationPermission* = enum
    npUnsupported
    npNotDetermined
    npDenied
    npGranted

  NotificationContent* = object
    title*: string
    subtitle*: string
    body*: string
    defaultSound*: bool

  NotificationClickedEvent* = ref object of NotificationEvent
    notificationId*: uint32
    actionIdentifier*: string

  NotificationCenter* = ref object of EventEmitter[NotificationEvent]
    supportedValue: bool

var notifSink: proc(id: uint32, action: string) {.closure.}

when defined(macosx) or defined(ios):
  var notifAuthSink*: proc(granted: bool) {.closure.}

  proc notifAuthTrampoline(granted: cint, ctx: pointer) {.cdecl.} =
    if not notifAuthSink.isNil:
      notifAuthSink(granted != 0)

  proc notifResponseTrampoline(id: cuint, action: cstring, ctx: pointer) {.cdecl.} =
    if not notifSink.isNil:
      notifSink(uint32(id), $action)

method typeName(e: NotificationClickedEvent): string =
  "NotificationClickedEvent"

proc newNotificationClickedEvent*(id: uint32,
                                  action: string): NotificationClickedEvent =
  result = NotificationClickedEvent(notificationId: id,
                                    actionIdentifier: action)
  discard stamp(result)

proc newNotificationCenter*(): NotificationCenter =
  result = NotificationCenter(supportedValue: false)
  initEmitter(result)
  when defined(macosx) or defined(ios):
    result.supportedValue = naNotificationsSupported()
    if result.supportedValue:
      naNotificationsSetResponseCallback(notifResponseTrampoline, nil)

proc notificationsSupported*(nc: NotificationCenter): bool =
  when defined(macosx) or defined(ios):
    naNotificationsSupported()
  else:
    false

proc notificationPermissionStatus*(nc: NotificationCenter): NotificationPermission =
  when defined(macosx) or defined(ios):
    case naNotificationsAuthStatus()
    of -1: npUnsupported
    of 0: npNotDetermined
    of 1: npDenied
    else: npGranted
  else:
    npUnsupported

proc requestNotificationPermission*(nc: NotificationCenter,
                                    cb: proc(granted: bool)) =
  ## Asks the user for notification authorization; cb fires once.
  when defined(macosx) or defined(ios):
    let selfRef = nc
    notifAuthSink = proc(granted: bool) =
      cb(granted)
    if selfRef.notificationsSupported():
      naNotificationsRequestAuth(notifAuthTrampoline, nil)
    else:
      cb(false)
  else:
    cb(false)

proc showNotification*(nc: NotificationCenter,
                       content: NotificationContent): uint32 =
  ## Schedules a banner. Returns the id, or 0 when unsupported.
  when defined(macosx) or defined(ios):
    if not nc.notificationsSupported():
      return 0
    naNotificationsShow(content.title.cstring,
                        content.subtitle.cstring,
                        content.body.cstring,
                        content.defaultSound)
  else:
    0

proc cancelNotification*(nc: NotificationCenter, id: uint32) =
  when defined(macosx) or defined(ios):
    if nc.notificationsSupported():
      naNotificationsCancel(id)

proc fireNotificationClickedSimulated*(nc: NotificationCenter,
                                       id: uint32, action = "clicked") =
  ## Test hook: delivers a click response through the normal pipeline.
  when defined(macosx) or defined(ios):
    notifResponseTrampoline(cuint(id), action.cstring, nil)

proc onNotificationClicked*(nc: NotificationCenter,
                            handler: proc(e: NotificationClickedEvent)): ListenerId =
  let selfRef = nc
  if notifSink.isNil:
    notifSink = proc(id: uint32, action: string) =
      emit(selfRef, newNotificationClickedEvent(id, action))
  addListener[NotificationEvent, NotificationClickedEvent](nc, handler)
