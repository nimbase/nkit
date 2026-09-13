## Simple browser — single WebView on the high-level DSL.
##
##   nim c -d:webkit -d:ssl --path:src -r examples/webview_dsl.nim
##
## Requires: libwebkitgtk-6.0-dev (or libwebkit2gtk-4.1-dev) + -d:webkit.
## Without -d:webkit this file intentionally fails at compile time.

import std/strutils
import ../src/nkit/gui/appdsl_gtk
import ../src/nkit/gui/webview
import ../src/nkit/gui/sugar
import ../src/nkit/gui/layout

dslWindowSize = size(1024.0, 768.0)

initApp("Browser — nkit WebView") do:
  state do:
    var browser = newWebView()
    var address = input("Enter URL…")
    setText(address, "https://example.com")
    var isLoading = false

    proc webNode(w: WebView): ViewNode = ViewNode(w)

    # representative customisation — mirrors WKWebViewConfiguration / WKPreferences
    browser.setCustomUserAgent("nkit-browser/1.0")
    browser.setJavaScriptEnabled(true)
    browser.setAllowsInlineMediaPlayback(true)
    browser.setEnableDeveloperExtras(true)
    browser.setInspectable(true)
    browser.setAutoLoadImages(true)

    # update address bar when page navigates
    browser.onNavigation proc(e: WebNavigationEvent) =
      case e.kind
      of wnkStarted:
        setText(address, e.url)
        isLoading = true
      of wnkCommitted:
        setText(address, e.url)
      of wnkFinished:
        isLoading = false
      of wnkFailed:
        isLoading = false
        echo "failed: " & e.url
      of wnkDecidePolicy:
        discard  # handled separately

    # allow all policy decisions (external links, new windows, etc.)
    browser.onDecidePolicy proc(e: WebPolicyEvent) =
      discard  # C side auto-allows; this fires for logging/inspection

    browser.onTerminated proc(e: WebTerminateEvent) =
      echo "web process terminated"

    proc goTo(url: string) =
      let u = if url.contains("://"): url else: "https://" & url
      browser.loadUrl(u)

  render do:
    let backBtn = button("◀", proc(e: ButtonClickEvent) = discard browser.goBack())
    let fwdBtn  = button("▶", proc(e: ButtonClickEvent) = discard browser.goForward())
    let reloadBtn = button("↻", proc(e: ButtonClickEvent) = browser.reload())
    let goBtn = button("Go", proc(e: ButtonClickEvent) =
      var url = getText(address)
      if url.len == 0: url = "https://example.com"
      goTo(url)
    )
    # Enter in address bar navigates
    discard address.onSubmitted(proc(e: InputSubmittedEvent) =
      var url = getText(address)
      if url.len == 0: url = "https://example.com"
      goTo(url)
    )

    let toolbar = row(
      backBtn, fwdBtn, reloadBtn,
      expanded(address),
      goBtn
    ).spacing(6).crossAlign(caCenter)

    let root = padding(
      column(
        toolbar,
        divider(),
        expanded(webNode(browser))
      ).spacing(8).crossAlign(caStretch),
      all(10.0)
    )

    goTo("https://example.com")
    root
