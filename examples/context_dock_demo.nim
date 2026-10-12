## Context-menu + Dock demo: right-click menus on views and the full
## Dock tile API (badge, attention, progress, dock menu).
##
## Run headfully. Right-click the label for its menu, right-click
## elsewhere for the window menu. The dock menu counts clicks.
import nkit
import nkit/gui/sugar

when defined(macosx):
  import nkit/dock

  let app = initApplication()

  let win = newWindow()
  win.setTitle("Context + Dock demo")
  win.setSize(size(520.0, 380.0), false)

  # --- Dock menu with a live counter --------------------------------------
  var dockClicks = 0
  let dockM = dockMenu("Say hi", "Reset counter")
  app.setDockMenu(dockM)
  let dockItems = dockM.getAllItems()
  discard dockItems[0].addListener(proc(e: MenuItemClickedEvent) =
    inc dockClicks
    app.setDockBadge($dockClicks)
    app.refreshDockMenu())
  discard dockItems[1].addListener(proc(e: MenuItemClickedEvent) =
    dockClicks = 0
    app.clearDockBadge()
    app.clearDockProgress())

  discard app.addListener(proc(e: ApplicationDockReopenEvent) =
    echo "dock reopen, clicks so far: " & $dockClicks)

  discard app.requestDockAttention(daInformational)
  app.setDockProgress(0.3)

  # --- Right-click menus ---------------------------------------------------
  let labelMenu = newMenu()
  labelMenu.addItem(newMenuItem("Copy"))
  labelMenu.addItem(newMenuItem("Inspect"))
  discard labelMenu.addListener(proc(e: MenuOpenedEvent) =
    echo "label menu opening")

  let winMenu = newMenu()
  winMenu.addItem(newMenuItem("Window action"))
  win.setContextMenu(winMenu)

  layout(
    padding(
      column(
        h1("Context + Dock"),
        withContextMenu(text("right-click me"), labelMenu),
        p("right-click elsewhere for the window menu")
      ).spacing(16),
      all(24.0)
    )
  )

  win.show()
  discard app.run()
else:
  echo "context_dock_demo needs macOS"
