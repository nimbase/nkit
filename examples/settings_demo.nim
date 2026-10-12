## Settings-style demo: icon sidebar, toolbar with search, and
## router-driven pages. The Appearance page shows form rows with
## sliders, a segmented control, a dropdown and color wells.
import nkit
import nkit/gui/sugar
import std/strformat

let app = initApplication()

let win = newWindow()
win.setTitle("Settings")
win.setSize(size(860.0, 600.0), false)

const paths = ["/general", "/appearance", "/web", "/bookmarks", "/history"]

var sbNode = sidebar(@["General", "Appearance", "Web", "Bookmarks", "History"])
let sb = Sidebar(sbNode.view)
let host = newPlainView()
let router = newRouter()

proc showPage(i: int) =
  sb.selectIndex(i)

discard onSelect(sbNode, proc(e: SidebarSelectEvent) =
  router.go(paths[e.itemIndex]))

let tb = attachToolbar(win)
discard tb.addItem("General", "gear", proc() = showPage(0))
discard tb.addItem("Appearance", "paintpalette", proc() = showPage(1))
discard tb.addSeparator()
discard tb.addSearch("Filter settings", proc(text: string, submitted: bool) =
  echo "filter: " & text)
tb.setAllowsCustomization(true)

proc placeholderPage(title, body: string): ViewNode =
  scroll(column(h1(title), p(body)).spacing(12).crossAlign(caStretch))

let fillPick = pick(@["Color", "Gradient", "Image"])
let kindSeg = segmented(@["Linear", "Radial"])

let appearanceForm = column(
  h1("Appearance"),
  formRow("Fill With", fillPick),
  sliderRow("Page Corners", 10.5, 0.0, 25.0,
    formatValue = proc(v: float64): string = fmt"{v:.1f} pt"),
  h2("Gradient"),
  p("Stops are applied in order along the gradient."),
  formRow("Kind", kindSeg),
  sliderRow("Angle", 180.0, 0.0, 360.0,
    formatValue = proc(v: float64): string = fmt"{v:.0f}*"),
  colorStopRow("#1482ca", "11% along", color(0x14, 0x82, 0xca),
    onColor = proc(c: Color) = echo fmt"stop 1: {c.r:02x}{c.g:02x}{c.b:02x}"),
  colorStopRow("#3b62a7", "61% along", color(0x3b, 0x62, 0xa7),
    onColor = proc(c: Color) = echo fmt"stop 2: {c.r:02x}{c.g:02x}{c.b:02x}"),
  row(button("Add Stop", proc(e: ButtonClickEvent) = echo "add stop"))
).spacing(12).crossAlign(caStretch)
let appearancePage = scroll(appearanceForm)

router.route("/general", proc(p: RouteParams): ViewNode =
  placeholderPage("General", "General settings live here."))
router.route("/appearance", proc(p: RouteParams): ViewNode = appearancePage)
router.route("/web", proc(p: RouteParams): ViewNode =
  placeholderPage("Web", "Web settings live here."))
router.route("/bookmarks", proc(p: RouteParams): ViewNode =
  placeholderPage("Bookmarks", "Bookmark settings live here."))
router.route("/history", proc(p: RouteParams): ViewNode =
  placeholderPage("History", "History settings live here."))

layout(
  padding(
    row(
      column(
        sizedBox(width = 200.0, child = sbNode),
        spacer()
      ),
      expanded(toNode(host))
    ).spacing(16).crossAlign(caStretch),
    all(16.0)
  )
)

mountRouter(router, host, "/appearance")
showPage(1)

win.show()
discard app.run()
