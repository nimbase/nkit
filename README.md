<p align="center">
  <img src="https://raw.githubusercontent.com/nimbase/nkit/main/.github/nkit.png" alt="Nim Kit - Unified system APIs across multiple platforms" width="80px" height="80px"><br>
  Unified system APIs across multiple platforms<br>
  Android &bullet; iOS &bullet; Linux &bullet; macOS &bullet; Windows
</p>

<p align="center">
  <code>nimble install nkit</code>
</p>

<p align="center">
  <a href="https://nimbase.github.io/nkit/">API reference</a><br>
  <img src="https://github.com/nimbase/nkit/workflows/test/badge.svg" alt="Github Actions">  <img src="https://github.com/nimbase/nkit/workflows/docs/badge.svg" alt="Github Actions">
</p>

## About

nkit is a Nim toolkit for building desktop and mobile applications that look
and behave like real native applications. Instead of drawing its own widgets,
it talks to the platform's own UI framework through small C and Objective-C
shims, so every button, menu, alert or tray icon you create is the genuine
OS control your users already know.

The same philosophy applies below the GUI layer: clipboard, dialogs,
notifications, global shortcuts, secure storage, display queries and friends
are thin, unified wrappers over the platform services, exposed through one
idiomatic Nim surface.


## Features

- Unified system APIs across multiple platforms from a single import
- Cross-platform desktop and mobile development in pure Nim
- Based on simple C and Objective-C shims, compiled directly into your binary
- No dynamic bridge, no FFI generator, no Objective-C runtime reflection
- Access to low-level system APIs and bindings when you need full control
- Native system GUI built on AppKit today, with other platforms on the way
- Three API tiers so you can pick the right altitude per screen:
  raw views, Flutter-style composition, or a macro DSL
- A pure-Nim layout solver (rows, columns, flex, padding, alignment)
  that drives native views and stays portable across backends
- Beautiful macro-based application DSL with state and render blocks

## One app, three APIs

The same counter app, written against each of the three tiers.

### Low-level: direct control
You touch exactly what the shim exposes, one call at
a time. Nothing hides allocation, event registration or geometry from you.
Best for wrapping your own custom controls, auditing hot paths, or porting
an existing ObjC/C++ design line by line.

```nim
import nkit
import nkit/gui/view
import nkit/gui/theme
import nkit/gui/stack
import nkit/gui/label
import nkit/gui/button

let app = initApplication()

let win = newWindow()
win.setTitle("Counter")
win.setSize(size(420.0, 320.0), false)

var clicks = 0
let countLabel = newLabel("0")
countLabel.setFontSize(48.0)
countLabel.setFontWeight(fwLight)

let root = newStack(stVertical, spacing = 16.0)
root.setPadding(24.0)

let plusBtn = newButton("increment", bsPush)
discard onClick(plusBtn, proc(e: ButtonClickEvent) =
  inc clicks
  setText(countLabel, $clicks))

addArranged(root, countLabel)
addArranged(root, plusBtn)

setContent(win, View(root))
win.show()
discard app.run()
```

### Flutter-style: compositional sugar
Widgets are values. Constructors like `button`,
`h1`, `slider`, `card` return nodes that compose into `row`/`column`
trees laid out by a portable solver with flex, spacing and nine-point
alignment. Handlers wire at construction, `setText`/`getText` route by
runtime type, and the whole tree stays backend agnostic. Best for everyday
screen building where you want structure without ceremony.

```nim
import nkit
import nkit/gui/sugar

let app = initApplication()

let win = newWindow()
win.setTitle("Counter")
win.setSize(size(420.0, 320.0), false)

var clicks = 0
var countLabel = text("0", 48.0, fwLight)
var statusText = p("press increment to start")

layout(
  padding(
    column(
      h1("Counter"),
      expanded(centered(countLabel)),
      row(
        button("increment", proc(e: ButtonClickEvent) =
          inc clicks
          setText(countLabel, $clicks)),
        button("reset", proc(e: ButtonClickEvent) =
          clicks = 0
          setText(countLabel, "0"))
      ).spacing(12).crossAlign(caStretch),
      centered(statusText)
    ).spacing(16),
    all(24.0)
  )
)

win.show()
discard app.run()
```

### Macro DSL: state and render blocks
The boilerplate disappears. `initApp` creates the
window, applies your size, runs the render block once, mounts the last
expression as the root and starts the run loop. State lives in one block,
UI in another, which keeps screens readable and encourages keeping widget
references in scope. Best for full applications and quick prototypes that
should still ship as real native windows.

```nim
import nkit/gui/appdsl_cocoa

initApp("Counter") do:
  state do:
    var clicks = 0
    var countLabel = text("0", 48.0, fwLight)
    var statusText = p("press increment to start")

  render do:
    padding(
      column(
        h1("Counter"),
        expanded(centered(countLabel)),
        row(
          button("increment", proc(e: ButtonClickEvent) =
            inc clicks
            setText(countLabel, $clicks)
            setText(statusText, "clicked " & $clicks & "x")),
          button("reset", proc(e: ButtonClickEvent) =
            clicks = 0
            setText(countLabel, "0")
            setText(statusText, "counter cleared"))
        ).spacing(12).crossAlign(caStretch),
        centered(statusText)
      ).spacing(16),
      all(24.0)
    )
```

All three tiers interoperate freely: a DSL app can drop to the low level
for one tricky view, and low-level apps can adopt sugar constructors
incrementally.

## Roadmap

Platform support:

| Platform | Status |
| --- | --- |
| macOS (Cocoa/AppKit) | Done, active development |
| Windows | Planned |
| Linux | Planned |
| iOS | Planned |
| Android | Planned |

Planned work:

- Windows and Linux implementations of the existing service contracts
  (window, dialogs, clipboard, notifications, menus, tray)
- Backend ports of the layout host layer, reusing the pure-Nim solver
- More composite widgets (tables, trees, rich text)
- Multi-window and multi-display ergonomics
- Packaging story for bundling, icons and code signing

### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](https://github.com/nimbase/nkit/issues)
- 👋 Wanna help? [Fork it!](https://github.com/nimbase/nkit/fork)

### 🎩 License
MIT license | (c) 2026 George Lemon for Nimbase Community.
