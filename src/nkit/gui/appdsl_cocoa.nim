import nkit/foundation/geometry
import nkit/application
import nkit/window
import nkit/display
import nkit/display_manager
import nkit/gui/layout
import nkit/gui/sugar
import nkit/gui/appdsl
import nkit/alert
import nkit/gui/popover
import nkit/gui/split_view
import nkit/gui/toolbar
import nkit/gui/animate

export geometry, application, window, display, display_manager, layout, sugar,
       appdsl, alert, popover, split_view, toolbar, animate

var dslWindowSize* = size(800.0, 600.0)
  ## Window content size used by dslCreateWindow; override before
  ## initApplication for custom sizing.

proc dslCreateWindow*(title: string): Window =
  discard initApplication()
  result = newWindow()
  result.setTitle(title)
  result.setSize(dslWindowSize, false)
  let wa = sharedDisplayManager().getPrimaryDisplay().getWorkArea()
  setPosition(result, point(wa.x + 24.0,
                            wa.y + wa.height - dslWindowSize.height - 24.0))

proc dslColumn*(nodes: varargs[ViewNode]): ViewNode =
  result = column()
  for n in nodes:
    result.children.add(n)

proc dslMountAndRun*(win: Window, root: ViewNode) =
  installLayout(win, root)
  win.show()
  discard initApplication().run()
