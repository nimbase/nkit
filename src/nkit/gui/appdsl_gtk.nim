## GTK/Linux backend hooks for the appdsl `initApp` macro.
## Same hook contract as appdsl_cocoa; uses only unified APIs so behaviour
## matches macOS (window sizing, work-area placement, layout mount, run loop).
import ../foundation/geometry
import ../application
import ../window
import ../display
import ../display_manager
import ./layout
import ./sugar
import ./appdsl
import ../alert
import ./popover
import ./split_view
import ./toolbar
import ./animate

export geometry, application, window, display, display_manager, layout, sugar,
       appdsl, alert, popover, split_view, toolbar, animate

var dslWindowSize* = size(800.0, 600.0)
  ## Window content size used by dslCreateWindow; override before
  ## initApplication for custom sizing.

proc dslCreateWindow*(title: string): Window =
  when defined(nkitTrace):
    proc log(msg: string) =
      let f = open("/tmp/nkit_nim.log", fmAppend)
      f.writeLine(msg)
      f.close()
    log("dslCreateWindow: initApplication")
  discard initApplication()
  when defined(nkitTrace): log("dslCreateWindow: newWindow")
  result = newWindow()
  when defined(nkitTrace): log("dslCreateWindow: setTitle")
  result.setTitle(title)
  when defined(nkitTrace): log("dslCreateWindow: setSize")
  result.setSize(dslWindowSize, false)
  when defined(nkitTrace): log("dslCreateWindow: getPrimaryDisplay")
  let wa = sharedDisplayManager().getPrimaryDisplay().getWorkArea()
  when defined(nkitTrace): log("dslCreateWindow: setPosition")
  setPosition(result, point(wa.x + 24.0,
                            wa.y + wa.height - dslWindowSize.height - 24.0))
  when defined(nkitTrace): log("dslCreateWindow: done")

proc dslColumn*(nodes: varargs[ViewNode]): ViewNode =
  result = column()
  for n in nodes:
    result.children.add(n)

proc dslMountAndRun*(win: Window, root: ViewNode) =
  when defined(nkitTrace):
    proc log(msg: string) =
      let f = open("/tmp/nkit_nim.log", fmAppend)
      f.writeLine(msg)
      f.close()
    log("dslMountAndRun: installLayout start")
  installLayout(win, root)
  when defined(nkitTrace): log("dslMountAndRun: installLayout done")
  win.show()
  when defined(nkitTrace): log("dslMountAndRun: show done, calling run")
  discard initApplication().run()
  when defined(nkitTrace): log("dslMountAndRun: run returned")
