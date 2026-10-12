## P0 platform services showcase: clipboard, file dialogs,
## notifications, file drag-and-drop, mouse monitors.
import nkit
import nkit/gui/view
import nkit/gui/theme
import nkit/gui/button
import nkit/gui/layout
import std/[syncio, strutils]

template trace(msg: untyped) =
  stderr.writeLine("[p0] ", msg)
  stderr.flushFile()

let app = initApplication()

let win = newWindow()
win.setTitle("P0 Platform Services")
win.setSize(size(560.0, 420.0), false)
block:
  let wa = sharedDisplayManager().getPrimaryDisplay().getWorkArea()
  setPosition(win, point(wa.x + 24.0, wa.y + wa.height - 420.0 - 24.0))

# ---------- services ----------
let clip = sharedClipboard()
let notif = newNotificationCenter()
let mouseMon = newMouseMonitor()

proc toast(msg: string) =
  discard show(sharedToastManager(), "P0", msg, durationMs = 2200.0)

# ---------- ui ----------
let root = column().spacing(14).crossAlign(caStretch)

root.children.add h1("Platform services")
root.children.add p("Clipboard, dialogs, notifications, drop zone, mouse monitor")

let clipStatus = p("clipboard idle")
root.children.add padding(
    row(
      button("Copy", proc(e: ButtonClickEvent) =
        clip.setClipboardText("Hello from nativeapi P0 demo!")
        setText(clipStatus, "copied text to the pasteboard")),
      button("Paste", proc(e: ButtonClickEvent) =
        let value = clip.getClipboardText()
        setText(clipStatus,
                if value.len > 0: "pasteboard: " & value else: "no text")),
      expanded(ViewNode(clipStatus))
    ).spacing(8),
    only(left = 16.0))

root.children.add padding(
    row(
      button("Open...", proc(e: ButtonClickEvent) =
        let dlg = newOpenFileDialog("Pick a file")
        dlg.setFilters(@["nim", "txt", "md"])
        dlg.setInitialDirectory("/tmp")
        let picked = dlg.open()
        toast(if picked.len > 0: "picked: " & picked[0] else: "cancelled")),
      button("Save as...", proc(e: ButtonClickEvent) =
        let dlg = newSaveFileDialog("Save report", "report.txt")
        let path = dlg.open()
        toast(if path.len > 0: "would save to " & path else: "cancelled"))
    ).spacing(8),
    only(left = 16.0))

var notifStatusText = if notif.notificationsSupported():
    "notifications available"
  else:
    "notifications need a bundled .app"
let notifyStatus = p(notifStatusText)
root.children.add padding(
    row(
      button("Notify", proc(e: ButtonClickEvent) =
        if not notif.notificationsSupported():
          toast("bundle the app as .app to enable notifications")
          return
        let id = notif.showNotification(NotificationContent(
          title: "nativeapi",
          body: "Local notification from the P0 demo",
          defaultSound: true))
        setText(notifyStatus,
                if id > 0: "notification scheduled" else: "scheduling failed")),
      expanded(ViewNode(notifyStatus))
    ).spacing(8),
    only(left = 16.0))

# Drop zone
let zone = newPlainView()
setBackgroundColor(zone, controlBackgroundColor())
setBorder(zone, separatorColor(), 1.0)
setCornerRadius(zone, 10.0)
enableFileDrop(zone, proc(paths: seq[string]) =
  toast("dropped " & $paths.len & " file(s): " &
        (if paths.len > 0: paths[0] else: "")))
block:
  let hint = p("Drop files here")
  addSubview(zone, hint.view)
  fillParent(hint.view)
root.children.add expanded(ViewNode(zone))

# Mouse readout
let mouseLabel = p("mouse monitor off")
discard onMouseMove(mouseMon, proc(e: MouseEvent) =
  setText(mouseLabel,
          ($e.kind)[2 ..^ 1].toLowerAscii() & " @ " &
          $int(e.position.x) & "," & $int(e.position.y)))
discard onMouseButton(mouseMon, proc(e: MouseEvent) =
  trace("button event kind=" & $e.kind & " clicks=" & $e.clickCount))
discard mouseMon.startLocal()
setText(mouseLabel, "move the mouse inside this window")
root.children.add centered(ViewNode(mouseLabel))

installLayout(win, root)
win.show()
trace("p0 services ready")

discard app.run()

mouseMon.stop()
