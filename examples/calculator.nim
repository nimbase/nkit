import nkit
import nkit/gui/view
import nkit/gui/theme
import nkit/gui/button
import nkit/gui/label
import nkit/gui/layout
import std/[syncio, strutils]

template trace(msg: untyped) =
  stderr.writeLine("[calc] ", msg)
  stderr.flushFile()

# ---------- calculator state ----------
var displayValue = "0"
var accumulator = 0.0
var pendingOp = ""
var enteringNumber = false

let displayLabel = newLabel("0")
displayLabel.setFontSize(30.0)
displayLabel.setFontWeight(fwLight)
displayLabel.setAlignment(laRight)
displayLabel.setTextColor(labelColor())

proc renderDisplay() =
  setText(displayLabel, displayValue)

proc applyOp(a: float64, b: float64, op: string): float64 =
  case op
  of "+": a + b
  of "-": a - b
  of "x": a * b
  of "/":
    if b != 0.0: a / b else: 0.0
  else: b

proc digitPressed(d: string) =
  if enteringNumber:
    if displayValue == "0":
      displayValue = d
    else:
      displayValue &= d
  else:
    displayValue = d
    enteringNumber = true
  renderDisplay()

proc dotPressed() =
  if not enteringNumber:
    displayValue = "0"
    enteringNumber = true
  if "." notin displayValue:
    displayValue &= "."
  renderDisplay()

proc currentValue(): float64 =
  parseFloat(displayValue)

proc opPressed(op: string) =
  if pendingOp.len > 0 and enteringNumber:
    accumulator = applyOp(accumulator, currentValue(), pendingOp)
    displayValue = formatFloat(accumulator, ffDecimal, 6)
    displayValue = displayValue.strip(leading = false, trailing = true,
                                      chars = {'0'})
    displayValue = displayValue.strip(leading = false, trailing = true,
                                      chars = {'.'})
    renderDisplay()
  else:
    accumulator = currentValue()
  pendingOp = op
  enteringNumber = false

proc equalsPressed() =
  if pendingOp.len > 0:
    displayValue = formatFloat(applyOp(accumulator, currentValue(), pendingOp),
                               ffDecimal, 6)
    displayValue = displayValue.strip(leading = false, trailing = true,
                                      chars = {'0'})
    displayValue = displayValue.strip(leading = false, trailing = true,
                                      chars = {'.'})
    if displayValue.len == 0:
      displayValue = "0"
    pendingOp = ""
    enteringNumber = false
    renderDisplay()

proc clearPressed() =
  displayValue = "0"
  accumulator = 0.0
  pendingOp = ""
  enteringNumber = false
  renderDisplay()

proc signPressed() =
  if displayValue.startsWith("-"):
    displayValue = displayValue[1 ..^ 1]
  elif displayValue != "0":
    displayValue = "-" & displayValue
  renderDisplay()

proc percentPressed() =
  displayValue = formatFloat(currentValue() / 100.0, ffDecimal, 6)
  displayValue = displayValue.strip(leading = false, trailing = true,
                                    chars = {'0'})
  displayValue = displayValue.strip(leading = false, trailing = true,
                                    chars = {'.'})
  if displayValue.len == 0:
    displayValue = "0"
  renderDisplay()

proc calcButton(title: string, onTap: proc()): ViewNode =
  let b = newButton(title, bsPush)
  discard onClick(b, proc(e: ButtonClickEvent) =
    onTap())
  result = ViewNode(b)

# ---------- ui ----------
let app = initApplication()

let win = newWindow()
win.setTitle("Calculator")
win.setSize(size(340.0, 500.0), false)
win.center()
win.show()

let root = column().spacing(12.0).crossAlign(caStretch)

# display panel
let displayPanel = sizedBox(0.0, 88.0, padding(ViewNode(displayLabel), 16.0, 8.0))
root.children.add(displayPanel)

# button grid: 5 rows, each row expanded equally, buttons expanded equally
proc digitRow(a, b, c, d: ViewNode): ViewNode =
  row(expanded(a), expanded(b), expanded(c), expanded(d)).spacing(8.0).
      crossAlign(caStretch)

let grid = column(
  expanded(digitRow(
    calcButton("C", clearPressed),
    calcButton("+/-", signPressed),
    calcButton("%", percentPressed),
    calcButton("/", proc() = opPressed("/")))),
  expanded(digitRow(
    calcButton("7", proc() = digitPressed("7")),
    calcButton("8", proc() = digitPressed("8")),
    calcButton("9", proc() = digitPressed("9")),
    calcButton("x", proc() = opPressed("x")))),
  expanded(digitRow(
    calcButton("4", proc() = digitPressed("4")),
    calcButton("5", proc() = digitPressed("5")),
    calcButton("6", proc() = digitPressed("6")),
    calcButton("-", proc() = opPressed("-")))),
  expanded(digitRow(
    calcButton("1", proc() = digitPressed("1")),
    calcButton("2", proc() = digitPressed("2")),
    calcButton("3", proc() = digitPressed("3")),
    calcButton("+", proc() = opPressed("+")))),
  expanded(row(expanded(calcButton("0", proc() = digitPressed("0")), 2.0),
               expanded(calcButton(".", dotPressed)),
               expanded(calcButton("=", equalsPressed))).spacing(8.0).
               crossAlign(caStretch))
).spacing(8.0).crossAlign(caStretch)

root.children.add(expanded(grid, 1.0))

layout do:
  root

trace("calculator ready; resize the window to watch the grid relayout")
discard app.run()
trace("run loop finished")
