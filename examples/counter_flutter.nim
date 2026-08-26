## Counter app on the flutter-style API: sugar widget constructors,
## the layout solver, fluent options. Same interface as
## counter_lowlevel.nim and counter_dsl.nim.
import nkit
import nkit/gui/sugar
import std/[syncio, strutils]

template trace(msg: untyped) =
  stderr.writeLine("[counter-flutter] ", msg)
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
var countLabel = text("0", 48.0, fwLight)
var statusText = p("press increment to start")

# ---------- events ----------
let plusBtn = button("increment", proc(e: ButtonClickEvent) =
  inc clicks
  setText(countLabel, $clicks)
  setText(statusText, "clicked " & $clicks & "x"))

let resetBtn = button("reset", proc(e: ButtonClickEvent) =
  clicks = 0
  setText(countLabel, "0")
  setText(statusText, "counter cleared"))

# ---------- ui ----------
layout(
  padding(
    column(
      h1("Counter"),
      expanded(centered(countLabel)),
      row(plusBtn, resetBtn).spacing(12).crossAlign(caStretch),
      centered(statusText)
    ).spacing(16),
    all(24.0)
  )
)
# ---------- boot ----------
win.show()
trace("ready")

discard app.run()
trace("done")
