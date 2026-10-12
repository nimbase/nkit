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

when defined(macosx):
  suite "webview extended":
    test "create_ex options round trip":
      let wv = newWebViewEx(WebViewOptions(
        javaScriptEnabled: true, persistentStore: false,
        userAgent: "NkitTest/1.0", backForwardGestures: false,
        allowsMagnification: true))
      defer:
        destroy(wv)
      check not wv.persistentStore
      check getUserAgent(wv) == "NkitTest/1.0"
      check not getBackForwardGestures(wv)
      wv.setUserAgent("")
      check getUserAgent(wv) == ""
      wv.setUserAgent("NkitTest/2.0")
      check getUserAgent(wv) == "NkitTest/2.0"
      wv.setBackForwardGestures(true)
      check getBackForwardGestures(wv)
      wv.setPageZoom(1.25)
      check abs(getPageZoom(wv) - 1.25) < 0.01
      wv.setPageZoom(1.0)

    test "navigation extras callable headless":
      let wv = newWebView()
      defer:
        destroy(wv)
      reloadFromOrigin(wv)
      loadFileUrl(wv, "/tmp/index.html")
      loadData(wv, "<h1>hi</h1>")
      check getBackList(wv).len == 0
      check getForwardList(wv).len == 0
      check not goToHistoryOffset(wv, -1)
      check not goToHistoryOffset(wv, 1)

    test "policy mode round trip and decide callable":
      let wv = newWebView()
      defer:
        destroy(wv)
      check getNavigationPolicyMode(wv) == npAllowAll
      wv.setNavigationPolicyMode(npAsk)
      check getNavigationPolicyMode(wv) == npAsk
      allowNavigation(999999'u64)
      cancelNavigation(999999'u64)
      wv.setNavigationPolicyMode(npBlockExternal)
      check getNavigationPolicyMode(wv) == npBlockExternal
      wv.setNavigationPolicyMode(npAllowAll)

    test "navigation event routes with type and decision":
      let wv = newWebView()
      defer:
        destroy(wv)
      var url = ""
      var navType = ntOther
      var did: uint64 = 0
      discard onNavigationRequested(wv, proc(e: WebViewNavigationEvent) =
        url = e.url
        navType = e.navType
        did = e.decisionId)
      fireTestEvent(wv, webviewNavRequested, "https://example.com/x", "link",
        num2 = 4242'u64)
      discard runMainThreadLoopFor(100)
      check url == "https://example.com/x"
      check navType == ntLink
      check did == 4242'u64
      check parseNavigationType("formSubmit") == ntFormSubmit
      check parseNavigationType("bogus") == ntOther

    test "js bridge extras callable":
      let wv = newWebView()
      defer:
        destroy(wv)
      addMessageHandler(wv, "extra")
      removeMessageHandler(wv, "extra")
      removeMessageHandler(wv, "missing")
      addUserScript(wv, "window.__nkit = 1;")
      removeAllUserScripts(wv)
      addContentRule(wv, """[{"trigger":{"url-filter":".*"},"action":{"type":"block"}}]""",
        "test-block")
      removeAllContentRules(wv)
      removeAllMessageHandlers(wv)

    test "alert confirm prompt newWindow route":
      let wv = newWebView()
      defer:
        destroy(wv)
      var alertMsg = ""
      var alertCid: uint64 = 0
      var confirmMsg = ""
      var promptText = ""
      var newUrl = ""
      discard onJsAlert(wv, proc(e: WebViewAlertEvent) =
        alertMsg = e.message
        alertCid = e.completionId)
      discard onJsConfirm(wv, proc(e: WebViewConfirmEvent) =
        confirmMsg = e.message)
      discard onJsPrompt(wv, proc(e: WebViewPromptEvent) =
        promptText = e.defaultText)
      discard onNewWindow(wv, proc(e: WebViewNewWindowEvent) =
        newUrl = e.url)
      fireTestEvent(wv, webviewJsAlert, "hello", num2 = 11'u64)
      fireTestEvent(wv, webviewJsConfirm, "sure?", num2 = 12'u64)
      fireTestEvent(wv, webviewJsPrompt, "name?", "bob", num2 = 13'u64)
      fireTestEvent(wv, webviewNewWindow, "https://example.com/new", "link")
      discard runMainThreadLoopFor(100)
      check alertMsg == "hello"
      check alertCid == 11'u64
      check confirmMsg == "sure?"
      check promptText == "bob"
      check newUrl == "https://example.com/new"
      completeAlert(999999'u64)
      completeConfirm(999999'u64, true)
      completePrompt(999999'u64, "x")
      cancelPrompt(999999'u64)

    test "pdf snapshot cookies route":
      let wv = newWebView()
      defer:
        destroy(wv)
      var pdfPath = ""
      var pdfErr = false
      var pdfReq: uint64 = 0
      var snapPath = ""
      var cookiesJson = ""
      discard onPdfResult(wv, proc(e: WebViewPdfEvent) =
        pdfPath = e.path
        pdfErr = e.isError
        pdfReq = e.requestId)
      discard onSnapshotResult(wv, proc(e: WebViewSnapshotEvent) =
        snapPath = e.path)
      discard onCookiesResult(wv, proc(e: WebViewCookiesEvent) =
        cookiesJson = e.json)
      fireTestEvent(wv, webviewPdfResult, "/tmp/x.pdf", "", num2 = 91'u64)
      fireTestEvent(wv, webviewSnapshotResult, "/tmp/y.png", "", num2 = 92'u64)
      fireTestEvent(wv, webviewCookiesResult, """[{"name":"a"}]""",
        num2 = 93'u64)
      discard runMainThreadLoopFor(100)
      check pdfPath == "/tmp/x.pdf"
      check not pdfErr
      check pdfReq == 91'u64
      check snapPath == "/tmp/y.png"
      check cookiesJson == """[{"name":"a"}]"""

    test "pdf snapshot cookies callable headless":
      let wv = newWebView()
      defer:
        destroy(wv)
      createPdf(wv, 1'u64)
      takeSnapshot(wv, 2'u64)
      getAllCookies(wv, 3'u64)
      setCookie(wv, "sess", "abc", "example.com")
      deleteCookie(wv, "sess")
      clearWebsiteData(wv)
      clearAllWebsiteData(wv)

    test "find routes boolean through jsResult":
      let wv = newWebView()
      defer:
        destroy(wv)
      var found = ""
      var foundReq: uint64 = 0
      discard onJsResult(wv, proc(e: WebViewJsResultEvent) =
        if e.requestId == 77'u64:
          found = e.result
          foundReq = e.requestId)
      findInPage(wv, "hello", requestId = 78'u64)
      hideFindHighlight(wv)
      fireTestEvent(wv, webviewJsResult, "true", num2 = 77'u64)
      discard runMainThreadLoopFor(100)
      check found == "true"
      check foundReq == 77'u64

    test "web context menu toggle and custom menu attach":
      let wv = newWebView()
      defer:
        destroy(wv)
      check getDefaultWebContextMenuEnabled(wv)
      wv.setDefaultWebContextMenuEnabled(false)
      check not getDefaultWebContextMenuEnabled(wv)
      let menu = newMenu()
      menu.addItem(newMenuItem("Back"))
      setContextMenu(wv, menu)
      check hasContextMenu(wv)
      wv.setDefaultWebContextMenuEnabled(true)
      check getDefaultWebContextMenuEnabled(wv)
      menu.free()
