## macOS Dock tile API: badge, attention requests, progress overlay.
##
## macOS-only by design. Guard call sites with `when defined(macosx)`.
## Dock menus themselves are ordinary `Menu` values: build them with
## `menu.nim`, attach with `Application.setDockMenu`, mutate freely, then
## call `refreshDockMenu` to repaint the tile. Item clicks route through
## the existing `MenuItemClickedEvent` / `globalItemClickSink` path.

when defined(macosx):
  import ./application
  import ./menu
  import ./platform/macos/nsfunctions

  export application, menu

  type DockAttention* = enum
    daInformational
    daCritical

  proc getDockMenu*(app: Application): Menu =
    ## Returns the attached dock menu object, or nil when none.
    let key = app.getDockMenuKey()
    if key == 0:
      return nil
    findMenuByKey(key)

  proc refreshDockMenu*(app: Application) =
    ## Repaints the tile after mutating dock menu items.
    naDockDisplay()

  proc setDockBadge*(app: Application, label: string) =
    ## Shows a badge string on the Dock tile. Empty clears it.
    naDockSetBadge(label.cstring)

  proc getDockBadge*(app: Application): string =
    $naDockGetBadge()

  proc clearDockBadge*(app: Application) =
    naDockSetBadge(nil)

  proc hasDockBadge*(app: Application): bool =
    getDockBadge(app).len > 0

  proc requestDockAttention*(app: Application,
                             kind = daInformational): int =
    ## Bounces the Dock icon. Returns a request id for cancellation.
    int(naDockRequestAttention(kind == daCritical))

  proc cancelDockAttention*(app: Application, requestId: int) =
    naDockCancelAttention(cint(requestId))

  proc setDockProgress*(app: Application, fraction: float64) =
    ## Shows a determinate progress bar in the tile (0.0..1.0, clamped).
    naDockSetProgress(fraction)

  proc setDockProgressIndeterminate*(app: Application, on: bool) =
    ## Shows or hides a spinning indicator in the tile.
    naDockSetProgressIndeterminate(on)

  proc clearDockProgress*(app: Application) =
    ## Removes the progress overlay, restoring the plain app icon.
    naDockClearProgress()

  proc dockMenu*(items: varargs[string]): Menu =
    ## Builds a dock menu from labels in one call.
    result = newMenu()
    for label in items:
      result.addItem(newMenuItem(label))
