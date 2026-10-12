## Menu-bar demo: full App/Edit/Window/Help bar with working
## responder-chain actions. Type in the text area, then Cut/Copy/Paste
## from the Edit menu; About/Preferences report to the console.
import nkit
import nkit/gui/sugar

when defined(macosx):
  import nkit/menubar

  let app = initApplication()

  let win = newWindow()
  win.setTitle("MenuBar Demo")
  win.setSize(size(560.0, 400.0), false)

  let std = mainMenuBar(app, "MenuBar Demo")

  # A custom File menu spliced between App and Edit.
  let fileM = newMenu()
  let newItem = newMenuItem("New Window")
  newItem.setAccelerator(keyboardAccelerator("N", modMeta))
  fileM.addItem(newItem)
  discard std.bar.addTopMenu("File", fileM, at = 1)
  discard newItem.addListener(proc(e: MenuItemClickedEvent) =
    echo "new window requested")

  discard std.app.aboutItem.addListener(proc(e: MenuItemClickedEvent) =
    echo "about: MenuBar Demo 1.0")
  discard std.app.prefsItem.addListener(proc(e: MenuItemClickedEvent) =
    echo "preferences opened")

  let notes = textarea("Type here, then use Edit > Cut/Copy/Paste.", 200.0)

  layout(
    padding(
      column(
        h1("Menu bar demo"),
        p("Every Edit item works through the responder chain."),
        expanded(notes)
      ).spacing(12).crossAlign(caStretch),
      all(16.0)
    )
  )

  win.show()
  discard app.run()
else:
  echo "menubar_demo needs macOS"
