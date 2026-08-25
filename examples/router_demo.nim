## Router demo: GoRouter-style navigation between native views.
## Left pane holds nav buttons constrained between 180 and 260 points;
## the right pane hosts the router, swapping pages on push/pop.
import nkit
import nkit/gui/sugar

let app = initApplication()

let win = newWindow()
win.setTitle("Router")
win.setSize(size(760.0, 480.0), false)
block:
  let wa = sharedDisplayManager().getPrimaryDisplay().getWorkArea()
  setPosition(win, point(wa.x + 24.0, wa.y + wa.height - 480.0 - 24.0))

# ---------- routes ----------
var statusText: ViewNode = nil

proc homePage(params: RouteParams): ViewNode =
  padding(
    column(
      h1("Home"),
      p("Use the navigator to move around."),
      p("Push /products/42 or /archive/2026-08-25/nkit-router."),
      p("Push /nowhere to see the fallback page.")
    ).spacing(10),
    all(16.0)
  )

proc productPage(params: RouteParams): ViewNode =
  padding(
    column(
      h1("Product " & params.get("productId")),
      p("matched {productId: id} -> [0-9]+"),
      p("query tab: " & params.get("tab", "(none)"))
    ).spacing(10),
    all(16.0)
  )

proc archivePage(params: RouteParams): ViewNode =
  padding(
    column(
      h1("Archive entry"),
      p("day: " & params.get("day")),
      p("slug: " & params.get("entry"))
    ).spacing(10),
    all(16.0)
  )

proc notFoundPage(params: RouteParams): ViewNode =
  padding(
    column(
      h1("404"), p("No route matches the current path.")
    ).spacing(10),
    all(16.0)
  )

var router = newRouter()
router.route("/", homePage)
router.route("/products/{productId: id}", productPage)
router.route("/archive/{day: date}/{entry: slug}", archivePage)
router.notFound(notFoundPage)

# ---------- sidebar ----------
proc syncStatus() =
  setText(statusText,
    "path " & router.currentPath() & " | depth " & $router.depth())

proc navButton(title, target: string): ViewNode =
  button(title, proc(e: ButtonClickEvent) =
    router.push(target)
    syncStatus())

statusText = p("path / | depth 1")

let sidebar = column(
  h2("Navigator"),
  navButton("Home", "/"),
  navButton("Product 42", "/products/42?tab=specs"),
  navButton("Bad product id", "/products/abc"),
  navButton("Archive entry", "/archive/2026-08-25/nkit-router"),
  navButton("Missing page", "/nowhere"),
  button("Back", proc(e: ButtonClickEvent) =
    discard router.pop()
    syncStatus()),
  spacer(),
  statusText
).spacing(8)

# ---------- layout ----------
let sv = newVerticalSplitView()

let sidePane = newPlainView()
installPaneLayout(win, sidePane, padding(sidebar, all(16.0)))
sv.addPane(sidePane)
sv.setPaneConstraints(0, minWidth = 180.0, maxWidth = 260.0)

let hostPane = newPlainView()
sv.addPane(hostPane)

# ---------- boot ----------
setContent(win, sv)
win.show()
mountRouter(router, hostPane)
discard app.run()
