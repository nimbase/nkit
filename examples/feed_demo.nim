## Feed-reader demo: update banner card plus feed rows with
## refresh/delete icon buttons, and a toolbar.
import nkit
import nkit/gui/sugar

proc logIt(msg: string): proc(e: ButtonClickEvent) =
  result = proc(e: ButtonClickEvent) =
    echo msg

let app = initApplication()

let win = newWindow()
win.setTitle("Feeds")
win.setSize(size(560.0, 480.0), false)

let tb = attachToolbar(win)
discard tb.addItem("Refresh all", "arrow.clockwise", proc() = echo "refresh all")
discard tb.addFlexibleSpace()
discard tb.addItem("Add feed", "plus", proc() = echo "add feed")

let banner = infoBanner("w.circle", "Software update",
  "Whatever 0.3.0 is installed.", "Check for Updates",
  logIt("checking updates..."))

let feeds = column(
  feedRow("p.circle", "Product Hunt - The best new products, every day",
    "Product Hunt - 42 unread - ok",
    onRefresh = logIt("refresh ph"), onDelete = logIt("delete ph")),
  feedRow("t.circle", "TechCrunch",
    "TechCrunch - 15 unread - ok",
    onRefresh = logIt("refresh tc"), onDelete = logIt("delete tc")),
  feedRow("v.circle", "The Verge",
    "The Verge - 8 unread - ok",
    onRefresh = logIt("refresh verge"), onDelete = logIt("delete verge")),
  feedRow("n.circle", "Nim programming language forum thread activity",
    "Nim forum - 7 unread - ok",
    onRefresh = logIt("refresh nim"), onDelete = logIt("delete nim"))
).spacing(8).crossAlign(caStretch)

layout(
  padding(
    scroll(column(banner, feeds).spacing(12).crossAlign(caStretch)),
    all(16.0)
  )
)

win.show()
discard app.run()
