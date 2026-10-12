# Plan: P0 Platform Services Milestone (macOS)

Five new platform modules following house conventions (C shim in
`widgets/*.m` + `{.importc}` in `nsfunctions.nim` + Nim wrapper + cdecl
trampoline callbacks + umbrella export + tests).

## 1. Clipboard (`src/nativeapi/clipboard.nim` + `widgets/clipboard.m`)  - S

```nim
setClipboardText(s) / getClipboardText(): string
setClipboardImage(img: Image) / getClipboardImage(): Image    # nil when absent
setClipboardFiles(paths) / getClipboardFiles(): seq[string]
clearClipboard() / clipboardChangeCount(): int                # for polling
```
NSPasteboard `clearContents` + typed writes (`NSPasteboardTypeString/PNG/FileURL`).
Tests: full round-trips incl. change-count bump (save/restore user clipboard
around the suite).

## 2. File dialogs (`src/nativeapi/file_dialog.nim` + `widgets/filedialog.m`)  - S/M

```nim
newOpenFileDialog(title = "")
  .setAllowsMultiple(true).setCanChooseDirectories(true)
  .setFilters(@["png", "jpg"]).setInitialDirectory(path)
open(): seq[string]                    # modal, empty = cancelled

newSaveFileDialog(title = "", defaultName = "").setNameField(s)
open(): string                         # "" = cancelled
```
Mirrors existing `MessageDialog` blocking-open style. Tests cover
construction/filters only (panels need human interaction); real picking
verified manually in the demo app.

## 3. Local notifications (`src/nativeapi/notifications.nim` + `widgets/notifications.m`)  - M

```nim
notificationPermissionStatus(): Permission       # notDetermined/denied/granted
requestNotificationPermission(cb: proc(granted: bool))
showNotification(NotificationContent): uint32     # title/body/sound/subtitle
cancelNotification(id)
onNotificationClicked(handler)                    # UNUserNotificationCenterDelegate
notificationsSupported(): bool
```
Known macOS constraint: `UNUserNotificationCenter` demands a bundle
identifier; unbundled CLI binaries throw. Wrap access in `@try`, expose
`notificationsSupported()`, degrade gracefully, document `.app` bundling.
Event pipeline tested by invoking the response trampoline directly.

## 4. Drag & drop (`src/nativeapi/drag_drop.nim` + view shim extension)  - M

- `view.m`: switch plain-view construction from bare `NSView` to an
  `NAPlainView` subclass (transparent change) with opt-in `dropEnabled`
  and drag-destination overrides
- Callback delivers `(widgetId, paths[])` through a single cdecl slot;
  Nim side gets a router table like `hover_router`
- Public API: `enableFileDrop(v: View, handler: proc(paths: seq[string]))`,
  `disableFileDrop(v)`
- Files-first scope; text drops later. Tests: registration flags +
  simulated trampoline delivery

## 5. Mouse monitors (`src/nativeapi/mouse_monitor.nim` + `widgets/mouse_monitor.m`)  - S

```nim
startGlobalMouseMonitor(kinds): MonitorToken   # system-wide (excludes own app - macOS rule)
startLocalMouseMonitor(kinds): MonitorToken    # our windows
stopMonitor(token)
onMouseMove/onMouseButton handlers             # MouseEvent(kind, screenPos)
```
Mirrors `keyboard_monitor.nim` structure exactly. Pipeline tests via direct
trampoline simulation.

## Deliverables

- Umbrella exports for all five; `examples/p0_services.nim` demoing
  everything: copy/paste buttons, open/save pickers, notify button,
  bordered drop zone, live mouse-position readout
- New test files wired into `clue test`

## Build order

clipboard -> file dialogs -> mouse monitors -> drag & drop -> notifications
(highest risk last)

## Flags

- Notifications may be no-ops until bundled as `.app` (graceful degradation)
- Modal dialogs untestable-headless by nature; manual QA via demo app
- Global mouse monitor intentionally ignores own-app events per macOS rules
