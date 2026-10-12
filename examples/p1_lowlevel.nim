## P1 services on the low-level API: raw stacks, direct module calls,
## constraint fills. Same interface as p1_flutter.nim / p1_dsl.nim.
import nkit
import nkit/gui/view
import nkit/gui/theme
import nkit/gui/stack
import nkit/gui/label
import nkit/gui/button
import nkit/gui/input
import nkit/gui/split_view
import nkit/gui/toolbar
import nkit/gui/popover
import nkit/gui/animate
import nkit/alert
import std/[syncio, strutils]

template trace(msg: untyped) =
  stderr.writeLine("[p1-low] ", msg)
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
var statusLabel: Label = nil

proc noteStatus(msg: string) =
  itemName = msg
  setText(statusLabel, "last action: " & msg)

# ---------- toolbar ----------
let tb = attachToolbar(win)

proc showAlertItem() =
  let dlg = newAlertDialog("Delete workspace?",
                           "All unsaved changes will be lost.", asWarning)
  dlg.addButton("Cancel")
  dlg.addButton("Move to Trash", proc(id: AlertID) =
    noteStatus("moved to trash"), isDefault = true)
  dlg.open()

proc showRenameItem() =
  let nameInput = newInput("Layer 1")
  let dlg = newAlertDialog("Rename layer", "Enter a new name.")
  dlg.withContent(ViewNode(nameInput))
  dlg.addButton("Rename", proc(id: AlertID) =
    noteStatus("renamed: " & getText(nameInput)), isDefault = true)
  dlg.open()

discard tb.addItem("Alert", "exclamationmark.triangle", showAlertItem)
discard tb.addItem("Rename", "square.and.pencil", showRenameItem)

# ---------- split panes ----------
let sv = newVerticalSplitView()

# Left pane: Library
let sidePane = newPlainView()
let sideStack = newStack(stVertical, spacing = 10.0)
sideStack.setPadding(16.0)
let sideTitle = newLabel("Library")
sideTitle.setFontSize(17.0)
sideTitle.setFontWeight(fwSemibold)
addArranged(sideStack, sideTitle)
for i in 1 .. 3:
  let idx = i
  let btn = newButton("Item " & $idx, bsPush)
  onClick(btn, proc(e: ButtonClickEvent) =
    noteStatus("item " & $idx))
  addArranged(sideStack, btn)
installPaneLayout(win, sidePane, sideStack)
sv.addPane(sidePane)
sv.setHoldingPriority(0, 260.0)

# Right pane: main content
let mainPane = newPlainView()
let mainStack = newStack(stVertical, spacing = 14.0)
mainStack.setPadding(20.0)

let heading = newLabel("Native services")
heading.setFontSize(24.0)
heading.setFontWeight(fwBold)
addArranged(mainStack, heading)

let box = newPlainView()
setBackgroundColor(box, systemIndigo())
setCornerRadius(box, 10.0)
box.constrainSize(0.0, 64.0)
addArranged(mainStack, box)

let animRow = newStack(stHorizontal, spacing = 8.0)
let fadeOutBtn = newButton("Fade out", bsPush)
onClick(fadeOutBtn, proc(e: ButtonClickEvent) = fadeOut(box))
let fadeInBtn = newButton("Fade in", bsPush)
onClick(fadeInBtn, proc(e: ButtonClickEvent) = fadeIn(box))
let slideBtn = newButton("Slide right", bsPush)
onClick(slideBtn, proc(e: ButtonClickEvent) =
  let f = box.getFrameRect()
  moveTo(box, f.x + 40.0, f.y, 300))
addArranged(animRow, fadeOutBtn)
addArranged(animRow, fadeInBtn)
addArranged(animRow, slideBtn)
addArranged(mainStack, View(animRow))

var pop: Popover = nil
let popBtn = newButton("Show popover", bsPush)
onClick(popBtn, proc(e: ButtonClickEvent) =
  if not pop.isNil and pop.isShown():
    return
  if not pop.isNil:
    pop.destroy()
  pop = newPopover(240.0, 130.0)
  setBackgroundColor(pop, controlBackgroundColor())
  let hint = newLabel("Anchored NSPopover holding any widget tree.")
  hint.setWraps(true)
  addSubview(pop, hint)
  fillParent(hint, left = 16.0, top = 40.0, right = 16.0)
  pop.show(popBtn, peBottom))
addArranged(mainStack, popBtn)

statusLabel = newLabel("last action: nothing yet")
statusLabel.setTextColor(secondaryLabelColor())
addArranged(mainStack, statusLabel)

installPaneLayout(win, mainPane, mainStack)
sv.addPane(mainPane)

# ---------- boot ----------
setContent(win, View(sv))
win.show()
dispatchAfterMain(300) do ():
  trace("ready")

discard app.run()
