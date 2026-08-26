## Counter app on the low-level widget API: raw views, stacks,
## constraint fills, manual wiring. Compare with counter_flutter.nim
## and counter_dsl.nim which build the exact same interface.
import nkit
import nkit/gui/view
import nkit/gui/theme
import nkit/gui/stack
import nkit/gui/label
import nkit/gui/button
import nkit/foundation/dispatcher
import std/[syncio, strutils]

template trace(msg: untyped) =
  stderr.writeLine("[counter-low] ", msg)
  stderr.flushFile()

let app = initApplication()

let win = newWindow()
win.setTitle("Counter")
win.setSize(size(420.0, 320.0), false)
block:
  let wa = sharedDisplayManager().getPrimaryDisplay().getWorkArea()
  setPosition(win, point(wa.x + 24.0, wa.y + wa.height - 320.0 - 24.0))

# ---------- state ----------
var clicks = 0
var countLabel = newLabel("0")
var statusLabel = newLabel("press increment to start")

# ---------- ui ----------
let root = newStack(stVertical, spacing = 16.0)
root.setPadding(24.0)

let titleLabel = newLabel("Counter")
titleLabel.setFontSize(22.0)
titleLabel.setFontWeight(fwBold)
titleLabel.setTextColor(labelColor())
addArranged(root, titleLabel)

countLabel.setFontSize(48.0)
countLabel.setFontWeight(fwLight)
countLabel.setAlignment(laCenter)
countLabel.setContentHugging(1, 10.0)
addArranged(root, countLabel)

let buttonRow = newStack(stHorizontal, spacing = 12.0)
let plusBtn = newButton("increment", bsPush)
let resetBtn = newButton("reset", bsPush)
addArranged(buttonRow, plusBtn)
addArranged(buttonRow, resetBtn)
addArranged(root, View(buttonRow))

statusLabel.setFontSize(13.0)
statusLabel.setTextColor(secondaryLabelColor())
statusLabel.setAlignment(laCenter)
addArranged(root, statusLabel)

# ---------- events ----------
proc renderCount() =
  setText(countLabel, $clicks)

discard onClick(plusBtn, proc(e: ButtonClickEvent) =
  inc clicks
  renderCount()
  setText(statusLabel, "clicked " & $clicks & "x"))

discard onClick(resetBtn, proc(e: ButtonClickEvent) =
  clicks = 0
  renderCount()
  setText(statusLabel, "counter cleared"))

# ---------- boot ----------
setContent(win, View(root))
win.show()

dispatchAfterMain(300) do ():
  layoutNow(root)
  trace("ready")

discard app.run()
trace("done")

destroy(statusLabel)
destroy(buttonRow)
destroy(countLabel)
destroy(titleLabel)
destroy(root)
free(win)
