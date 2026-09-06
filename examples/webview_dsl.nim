## WebKit WebView demo on the high-level DSL.
## Isolated WebViews by default, shared context demo, full customisation surface.
##
##   nim c -d:webkit --path:src -r examples/webview_dsl.nim        # real WebKit
##   nim c --path:src -r examples/webview_dsl.nim                  # stubs (no WebKit)
##
## Requires: libwebkitgtk-6.0-dev or libwebkit2gtk-4.1-dev for -d:webkit.

import std/[times, strutils]
import ../src/nkit/gui/appdsl_gtk
import ../src/nkit/gui/webview      # specific import per project rule
import ../src/nkit/gui/sugar        # column/row/text/button/input/bar etc. (not view's webview)
import ../src/nkit/gui/layout

dslWindowSize = size(1100.0, 750.0)

initApp("WebView DSL — nkit") do:
  state do:
    # ── contexts: isolated (default) vs shared
    let sharedCtx = newWebContext()                 # reused for shared pool demo

    # ── main WebView (isolated)
    var mainWeb = newWebView()                      # isolated: newWebContext internally
    var sharedWeb1 = newSharedWebView(sharedCtx)    # shared pool
    var sharedWeb2 = newSharedWebView(sharedCtx)

    # ── URL bar
    var urlInput = input("https://example.com")
    var statusLabel = text("idle")
    var titleLabel = text("WebView DSL", 14.0, fwSemibold)

    # helper to wrap WebView as layout node
    proc webNode(w: WebView): ViewNode = ViewNode(w)

    # ── custom scheme: nkit://app/*
    for w in [mainWeb, sharedWeb1, sharedWeb2]:
      w.registerUriScheme("nkit")
      w.addScriptMessageHandler("nimBridge")
      # inject JS at document start
      discard w.addUserScript(
        "window.nkitReady=true; console.log('nkit user script injected');",
        witStart, false
      )
      # inject CSS
      discard w.addUserStyleSheet("body{ font-family: sans-serif; }", false)
      w.setEnableDeveloperExtras(true)
      w.setTransparentBackground(false)
      w.setCustomUserAgent("nkit-webview-demo/1.0")
      w.setJavaScriptEnabled(true)
      w.setAllowsInlineMediaPlayback(true)
      w.setInspectable(true)
      w.setMinimumFontSize(12)
      w.setDefaultFontSize(16)
      w.setAutoLoadImages(true)
      w.setPreferredContentMode(wcmDesktop)
      w.setZoomLevel(1.0)

    # per-webview config tweaks to show customisation parity
    sharedWeb1.setBackgroundColor(250, 250, 255, 255)
    sharedWeb2.setBackgroundColor(255, 250, 250, 255)
    mainWeb.setBackgroundColor(255, 255, 255, 255)

    # ── event wiring
    proc wireWebView(w: WebView, tag: string) =
      w.onNavigation proc(e: WebNavigationEvent) =
        setText(statusLabel, tag & " " & $e.kind & " " & e.url)
        if e.kind == wnkFinished:
          setText(titleLabel, tag & " — " & w.getTitle())
      w.onProgress proc(e: WebProgressEvent) =
        # update shared progress bar from mainWeb only
        if w == mainWeb:
          # bar expects 0..100
          let pct = e.progress * 100.0
          # sugar bar is a ViewNode; reach native via view
          # we recreate bar value via progress view API directly
          # (sugar bar is not mutable, so we keep label)
          setText(statusLabel, "loading " & $int(pct) & "%")
      w.onMessage proc(e: WebMessageEvent) =
        setText(statusLabel, "msg " & e.handler & ": " & e.body)
        # echo to stdout
        echo "[" & tag & "] message handler=" & e.handler & " body=" & e.body
      w.onScheme proc(e: WebSchemeEvent) =
        # nkit://app/hello -> serve HTML
        if e.url == "nkit://app/hello":
          schemeFinish(e.requestId, "text/html", "<h1>Hello from Nim scheme handler</h1><p>url=" & e.url & "</p>")
        else:
          schemeFinish(e.requestId, "text/html", "<h1>nkit scheme</h1><p>" & e.url & "</p>")
      w.onTerminated proc(e: WebTerminateEvent) =
        setText(statusLabel, tag & " web process terminated")

    wireWebView(mainWeb, "[main]")
    wireWebView(sharedWeb1, "[shared1]")
    wireWebView(sharedWeb2, "[shared2]")

    # initial loads
    mainWeb.loadUrl("https://example.com")
    sharedWeb1.loadHtml("<h1>Shared 1</h1><p>Shares cookies/cache with Shared 2</p><button onclick=\"window.webkit.messageHandlers.nimBridge.postMessage('hello from shared1')\">Send msg</button>", "nkit://app/hello")
    sharedWeb2.loadHtml("<h1>Shared 2</h1><p>Same WebContext as Shared 1</p>", "nkit://app/hello")

  render do:
    # top bar: back/forward/reload + URL input + go
    let backBtn = button("◀", proc(e: ButtonClickEvent) = discard mainWeb.goBack())
    let fwdBtn  = button("▶", proc(e: ButtonClickEvent) = discard mainWeb.goForward())
    let reloadBtn = button("↻", proc(e: ButtonClickEvent) = mainWeb.reload())
    let goBtn = button("Go", proc(e: ButtonClickEvent) =
      let url = getText(urlInput)
      if url.len > 0:
        let full = if url.contains("://"): url else: "https://" & url
        mainWeb.loadUrl(full)
        setText(statusLabel, "navigating to " & full)
    )
    let jsBtn = button("Run JS", proc(e: ButtonClickEvent) =
      mainWeb.evaluateJavaScript("document.title + ' | js:' + (1+2)", proc(res: string, isErr: bool) =
        setText(statusLabel, if isErr: "js error: " & res else: "js: " & res)
      )
    )
    let injectBtn = button("Inject HTML", proc(e: ButtonClickEvent) =
      mainWeb.loadHtml("<h1>Injected via Nim</h1><p>time=" & $epochTime() & "</p><button onclick=\"window.webkit.messageHandlers.nimBridge.postMessage('injected button')\">Ping Nim</button>", "https://example.com/")
    )

    # controls row
    let controls = row(
      backBtn, fwdBtn, reloadBtn,
      expanded(urlInput),
      goBtn, jsBtn, injectBtn
    ).spacing(6).crossAlign(caCenter)

    # main area: expanded webview + side shared views
    let mainArea = expanded(webNode(mainWeb))

    let sideTabs = column(
      text("Shared context (same cookies/cache)", 12.0, fwSemibold),
      expanded(webNode(sharedWeb1)),
      divider(),
      expanded(webNode(sharedWeb2))
    ).spacing(6)

    # status row
    let statusRow = row(
      expanded(statusLabel),
      titleLabel
    ).spacing(12)

    padding(
      column(
        controls,
        divider(),
        row(
          mainArea,
          sideTabs
        ).spacing(8),
        divider(),
        statusRow
      ).spacing(8),
      all(10.0)
    )
