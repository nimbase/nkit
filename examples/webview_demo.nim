## WebView demo: a bare WKWebView filling the whole window.
import nkit
import nkit/gui/sugar

let app = initApplication()

let win = newWindow()
win.setTitle("WebView demo")
win.setSize(size(900.0, 640.0), false)

var page = webview("https://example.com")

# The page node itself is the layout root, so it tracks the window size.
layout(page)

win.show()
discard app.run()
