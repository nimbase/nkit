import unittest
import nkit
import nkit/gui/view
import nkit/gui/webview
import nkit/gui/sugar

suite "webview":
  test "create and destroy":
    let wv = newWebView()
    defer:
      destroy(wv)
    check wv.javaScriptEnabled
    check getUrl(wv) == ""
    check getTitle(wv) == ""
    check getProgress(wv) == 0.0
    check not isLoading(wv)
    check not canGoBack(wv)
    check not canGoForward(wv)

  test "load calls do not crash headless":
    let wv = newWebView()
    defer:
      destroy(wv)
    loadHtml(wv, "<html><body><h1>hi</h1></body></html>")
    loadUrl(wv, "https://example.com")
    reload(wv)
    stopLoading(wv)
    goBack(wv)
    goForward(wv)
    addMessageHandler(wv, "nkit")
    evaluateJs(wv, "1 + 1", requestId = 7)

  test "message event routes through native path":
    let wv = newWebView()
    defer:
      destroy(wv)
    var got = 0
    var gotName = ""
    var gotBody = ""
    discard onMessage(wv, proc(e: WebViewMessageEvent) =
      inc got
      gotName = e.name
      gotBody = e.body
      check e.webviewId == wv.id)
    fireTestEvent(wv, webviewMessage, "nkit", """{"ping":1}""")
    discard runMainThreadLoopFor(100)
    check got == 1
    check gotName == "nkit"
    check gotBody == """{"ping":1}"""

  test "finished and failed events carry url":
    let wv = newWebView()
    defer:
      destroy(wv)
    var finishedUrl = ""
    var failedMsg = ""
    discard onLoadFinished(wv, proc(e: WebViewFinishedEvent) =
      finishedUrl = e.url)
    discard onLoadFailed(wv, proc(e: WebViewFailedEvent) =
      failedMsg = e.message)
    fireTestEvent(wv, webviewFinished, "https://example.com")
    fireTestEvent(wv, webviewFailed, "https://example.com", "net down")
    discard runMainThreadLoopFor(100)
    check finishedUrl == "https://example.com"
    check failedMsg == "net down"

  test "progress and js result events route":
    let wv = newWebView()
    defer:
      destroy(wv)
    var progress = -1.0
    var jsResult = ""
    var jsReq: uint64 = 0
    var jsErr = true
    discard onProgress(wv, proc(e: WebViewProgressEvent) =
      progress = e.progress)
    discard onJsResult(wv, proc(e: WebViewJsResultEvent) =
      jsResult = e.result
      jsReq = e.requestId
      jsErr = e.isError)
    fireTestEvent(wv, webviewProgress, num = 0.5)
    fireTestEvent(wv, webviewJsResult, "Example Domain", num2 = 42)
    discard runMainThreadLoopFor(100)
    check abs(progress - 0.5) < 0.001
    check jsResult == "Example Domain"
    check jsReq == 42
    check not jsErr

  test "sugar constructor and node wiring":
    var node = webview(html = "<h1>hi</h1>")
    let wv = WebView(node.view)
    defer:
      destroy(wv)
    var msgs = 0
    discard onMessage(node, proc(e: WebViewMessageEvent) =
      inc msgs)
    discard onLoadFinished(node, proc(e: WebViewFinishedEvent) =
      discard)
    discard onProgress(node, proc(e: WebViewProgressEvent) =
      discard)
    discard onJsResult(node, proc(e: WebViewJsResultEvent) =
      discard)
    fireTestEvent(wv, webviewMessage, "nkit", "hi")
    discard runMainThreadLoopFor(100)
    check msgs == 1
