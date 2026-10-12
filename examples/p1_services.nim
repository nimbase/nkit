## P1 native services showcase: alerts v2, popovers, split view,
## window toolbar, animations.
import nkit
import nkit/gui/view
import nkit/gui/theme
import nkit/gui/button
import nkit/gui/layout
import std/[syncio, strutils]

template trace(msg: untyped) =
  stderr.writeLine("[p1] ", msg)
  stderr.flushFile()

let app = initApplication()

let win = newWindow()
win.setTitle("P1 Native Services")
win.setSize(size(680.0, 460.0), false)
block:
  let wa = sharedDisplayManager().getPrimaryDisplay().getWorkArea()
  setPosition(win, point(wa.x + 24.0, wa.y + wa.height - 460.0 - 24.0))

proc toast(msg: string) =
  discard show(sharedToastManager(), "P1", msg, durationMs = 2200.0)

# ---------- toolbar ----------
let tb = attachToolbar(win)
discard tb.addItem("Alert", "exclamationmark.triangle", proc() =
  let alert = newAlertDialog("Delete workspace?",
                             "All unsaved changes will be lost.", asWarning)
  alert.addButton("Cancel")
  alert.addButton("Move to Trash", proc(id: AlertID) =
    trace("alert closed; choice=trashed")
    toast("moved to trash"), isDefault = true)
  alert.open())
discard tb.addItem("Input", "square.and.pencil", proc() =
  let nameInput = newInput("Layer 1")
  let alert = newAlertDialog("Rename layer", "Enter a new name.")
  alert.withContent(ViewNode(nameInput))
  alert.addButton("Rename", proc(id: AlertID) =
    toast("renamed to: " & getText(nameInput)), isDefault = true)
  alert.open())

# ---------- split panes ----------
let split = newVerticalSplitView()

let sidePane = column().crossAlign(caStretch).spacing(10)
sidePane.children.add h2("Library")
for i in 1 .. 3:
  let idx = i
  sidePane.children.add centered(
      button("Item " & $idx, proc(e: ButtonClickEvent) =
        toast("picked item " & $idx)))
split.addPane(sidePane.view)
split.setHoldingPriority(0, 260.0)

let mainPane = column().spacing(14).crossAlign(caStretch)
mainPane.children.add h1("Native services")

let fadeTarget = sizedBox(0.0, 64.0,
    padding(ViewNode(p("animated box")), 12.0))
setBackgroundColor(fadeTarget.view, systemIndigo())
setCornerRadius(fadeTarget.view, 10.0)
mainPane.children.add fadeTarget

mainPane.children.add row(
    button("Fade out", proc(e: ButtonClickEvent) = fadeOut(fadeTarget.view)),
    button("Fade in", proc(e: ButtonClickEvent) = fadeIn(fadeTarget.view)),
    button("Slide right", proc(e: ButtonClickEvent) =
      let f = fadeTarget.view.getFrameRect()
      moveTo(fadeTarget.view, f.x + 40.0, f.y, 300))
).spacing(8)

var pop: Popover = nil
let popBtn = button("Show popover")
onClick(popBtn, proc(e: ButtonClickEvent) =
  if not pop.isNil and pop.isShown():
    return
  if not pop.isNil:
    pop.destroy()
  pop = newPopover(240.0, 150.0)
  setBackgroundColor(pop, controlBackgroundColor())
  block:
    let hint = p("Anchored NSPopover holding any widget tree.")
    addSubview(pop, hint.view)
    fillParent(hint.view, left = 16.0, top = 48.0, right = 16.0)
  block:
    let closer = button("Close", proc(e2: ButtonClickEvent) =
      pop.close())
    addSubview(pop, closer.view)
    fillParent(closer.view, left = 16.0, top = 90.0)
  pop.show(popBtn.view, peBottom))
mainPane.children.add row(expanded(ViewNode(popBtn))).spacing(8)

split.addPane(mainPane.view)

installLayout(win, split)
win.show()
trace("p1 services ready")

discard app.run()

if not pop.isNil:
  pop.destroy()
