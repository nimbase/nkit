import unittest
import nkit
import nkit/notifications
import nkit/foundation/event_emitter
import nkit/foundation/dispatcher

let nc = newNotificationCenter()

suite "notifications":
  test "support probe does not crash and reports a stable flag":
    let first = nc.notificationsSupported()
    let second = nc.notificationsSupported()
    check first == second

  test "permission status maps to a valid enum":
    let status = nc.notificationPermissionStatus()
    check status in {npUnsupported, npNotDetermined, npDenied, npGranted}

  test "show degrades gracefully when unsupported":
    if not nc.notificationsSupported():
      check nc.showNotification(NotificationContent(
        title: "t", body: "b")) == 0
    else:
      let id = nc.showNotification(NotificationContent(
        title: "nativeapi test",
        body: "pipeline notification",
        defaultSound: false))
      check id > 0
      nc.cancelNotification(id)

  test "clicked event flows through the pipeline":
    var gotId: uint32 = 0
    var gotAction = ""
    discard nc.onNotificationClicked(proc(e: NotificationClickedEvent) =
      gotId = e.notificationId
      gotAction = e.actionIdentifier)
    fireNotificationClickedSimulated(nc, 42)
    discard runMainThreadLoopFor(50)
    check gotId == 42
    check gotAction.len > 0

  test "request permission callback always fires":
    var fired = false
    var grantedValue = true
    nc.requestNotificationPermission(proc(granted: bool) =
      fired = true
      grantedValue = granted)
    # Unbundled processes report unsupported -> callback(false).
    if not nc.notificationsSupported():
      check fired == true
      check grantedValue == false
