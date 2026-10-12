## P1 services on the flutter-style API: sugar constructors, the layout
## solver, splitView helper. Same interface as p1_lowlevel.nim / p1_dsl.nim.
import nkit
import nkit/gui/sugar
import std/[syncio, strutils]

template trace(msg: untyped) =
  stderr.writeLine("[p1-flutter] ", msg)
  stderr.flushFile()

let app = initApplication()

let win = newWindow()
win.setTitle("P1 Services")
win.setSize(size(680.0, 460.0), false)
block:
  let wa = sharedDisplayManager().getPrimaryDisplay().getWorkArea()
  setPosition(win, point(wa.x + 24.0, wa.y + wa.height - 460.0 - 24.0))

# ---------- state ----------
var itemName = "nothing yet"
let statusText = p("last action: nothing yet")

proc syncStatus() =
  setText(statusText, "last action: " & itemName)

# ---------- toolbar ----------
proc showAlertDialog() =
  showAlert("Delete workspace?",
            "All unsaved changes will be lost.", asWarning)
    .addButton("Cancel")
    .addButton("Move to Trash", proc(id: AlertID) =
      itemName = "moved to trash"; syncStatus(); id.close(),
      isDefault = true)
    .open()

proc showRenameDialog() =
  let nameInput = input("Layer 1")
  showAlert("Rename layer", "Enter a new name.")
    .withContent(nameInput)
    .addButton("Rename", proc(id: AlertID) =
      itemName = "renamed: " & getText(nameInput)
      syncStatus(); id.close(), isDefault = true)
    .open()

let tb = attachToolbar(win)
discard tb.addItem("Alert", "exclamationmark.triangle", showAlertDialog)
discard tb.addItem("Rename", "square.and.pencil", showRenameDialog)

# ---------- popover ----------
let popBtn = button("Show popover",
  showPopover(
    p("Anchored NSPopover holding any widget tree."), size(240.0, 130.0)))

# ---------- animated box ----------
let box = sizedBox(0.0, 64.0, padding(ViewNode(p("animated box")), 12.0))
setBackgroundColor(box.view, systemIndigo())
setCornerRadius(box.view, 10.0)

# ---------- build ----------
let sv = verticalSplitView(
  column(h2("Library"),
    button("Item 1", proc(e: ButtonClickEvent) =
      itemName = "item 1"; syncStatus()),
    button("Item 2", proc(e: ButtonClickEvent) =
      itemName = "item 2"; syncStatus()),
    button("Item 3", proc(e: ButtonClickEvent) =
      itemName = "item 3"; syncStatus())
  ).spacing(10),
  column(
    h1("Native services"),
    box,
    row(button("Fade out", proc(e: ButtonClickEvent) = fadeOut(box.view)),
        button("Fade in", proc(e: ButtonClickEvent) = fadeIn(box.view)),
        button("Slide right", proc(e: ButtonClickEvent) =
          let f = box.view.getFrameRect()
          moveTo(box.view, f.x + 40.0, f.y, 300))).spacing(8),
    ViewNode(popBtn),
    ViewNode(statusText)
  ).spacing(14)
)

# ---------- boot ----------
setContent(win, sv.view)
win.show()
trace("ready")

discard app.run()
