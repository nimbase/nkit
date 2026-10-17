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

- Native widgets on macOS, iOS, and Linux using platform UI frameworks
- Unified clipboard, notifications, dialogs, and system services
- Global keyboard/mouse monitors and hotkey support
- Secure storage with Keychain and libsecret integration
- Dark and light theme with customizable accent colors
- Flexible layout system with flex, alignment, and spacing controls
- Three API tiers: low-level shims, compositional sugar, or macro DSL
- Built-in WebView with full configuration support
- Menu bar and system tray integration
- Display management and multi-monitor handling
- Cross-platform CLI for scaffolding, building, running and packaging apps
- Disk image packaging for macOS, including drag-to-install volumes and an optional pkg installer

### CLI application
```
$ nkit -h

Development
  init <?name:string>                  Scaffold nkit.yaml, a nimble file and a starter app
          --here:bool
  build <?platform:any[ios,macos]>     Produces an .app bundle under build/, including nkit.yaml
                                       assets and icon (Apple platforms). Omitting the platform
                                       builds for the host desktop target (macOS on Mac, Linux on
                                       Linux)
          --pkgr:any[nimble,clue]
                   --release:bool
  run <platform:any[ios,macos]> <?device:string> Targets the booted simulator, or a device by name
          --udid:string
Diagnostics
  devices                              List iOS Simulator devices known to Xcode
          --available:bool
Simulator runtimes
  runtimes.list                        Show the runtimes installed on this machine
  runtimes.install <name:string>       Download e.g. "iOS 18" or "watchOS 10"
  logs <platform:any[ios,macos]>       Stream simulator logs for the app process
          --udid:string
Distribution
  bundle <?app:filepath>               Package a macOS .app into a .dmg (macOS only) Takes the app
                                       bundle to package: nkit bundle path/to/App.app. Needs no
                                       nkit.yaml, and with no argument takes the single .app under
                                       build/macos. Repeat -f and -d to add several files or
                                       directories to the volume root, alongside the app and the
                                       Applications shortcut. -f .VolumeIcon.icns sets a custom
                                       volume icon. --pkg also builds a pkg installer from the app
                                       (needs a nkit.yaml for the identifier and version) and adds
                                       it to the volume; --sign names the identity pkgbuild signs
                                       it with.
                           -f:string[]
                       --file:string[]
                           -d:string[]
                        --dir:string[]
                             -o:string
                          --out:string
                      --volname:string
          --format:any[ULFO,UDZO,UDBZ]
                   --fs:any[HFS+,APFS]
                --no-applications:bool
                            --pkg:bool
                         --sign:string
  clean                                Remove the build directory
```

#### Packaging a macOS app
`nkit build macos` produces `build/macos/<name>.app`. `nkit bundle` turns an `.app` bundle into
a compressed disk image, the shape a `.dmg` is normally distributed in.

`bundle` reads no project configuration at all: there is nothing to initialise and no
`nkit.yaml` in scope. You name the bundle to package, and with no argument it takes the
single `.app` under `build/macos`. It also works on an app built by other means.

```sh
$ nkit bundle build/macos/Counter.app -f README.md -d licenses
```

The mounted volume holds the app, every file and directory you added, and a shortcut to
`/Applications` for dragging the app across. Files and directories are placed at the volume
root under their own name, so `-d licenses` becomes `<volume>/licenses`. Passing
`-f .VolumeIcon.icns` sets a custom volume icon, which is how `create-dmg` does it too.

`bundle --pkg` additionally builds a macOS installer package from the app with `pkgbuild`
and places the resulting `<name>.pkg` at the volume root next to the app, so one `.dmg`
offers both drag-to-install and the guided installer. The component package installs the
app to `/Applications`; its identifier and version come from `nkit.yaml` (`bundle_id` and
`version`), which is why `--pkg` only works inside a project directory while plain
`bundle` works on any `.app`. The package is unsigned unless `--sign` names an installer
identity to sign it with.

```sh
$ nkit bundle --pkg
$ nkit bundle --pkg --sign "Developer ID Installer: Example"
```

| Argument | Default | Purpose |
| --- | --- | --- |
| `<app>` | the sole `.app` under `build/macos` | The `.app` bundle to package |
| `-f`, `--file` | none | Add a file to the volume root; repeat for more |
| `-d`, `--dir` | none | Add a directory to the volume root; repeat for more |
| `-o`, `--out` | beside the app, `<name>.dmg` | Where to write the image |
| `--volname` | the app name | Name the mounted volume |
| `--format` | hdiutil's choice | `ULFO` (lzfse), `UDZO` (zlib) or `UDBZ` |
| `--fs` | derived from the source | `HFS+` or `APFS` |
| `--no-applications` | off | Leave out the `/Applications` shortcut |
| `--pkg` | off | Build a pkg installer from the app and add it to the volume (needs `nkit.yaml`) |
| `--sign` | none | Installer identity `pkgbuild` signs the package with |

`--format` and `--fs` are only passed to `hdiutil` when you ask for them, so the defaults
track macOS rather than being frozen into this tool. The image is written beside the app,
which keeps it inside `build/` and lets `nkit clean` remove it along with the scratch
directory used to assemble the volume. Icon positions inside the mounted window are
Finder's own default; there is no Finder scripting involved, which keeps the command
scriptable and free of Automation permission prompts.

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
| Linux | Active development |
| iOS | Active development |
| Android | Active development |

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
