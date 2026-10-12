## WebView extended demo: options, history, policy, dialogs, page tools.
##
## Run headfully: `clue build examples/webview_ex_demo.nim` then launch the
## binary from a terminal. Print/PDF/snapshot write to $TMPDIR.
import nkit
import nkit/gui/sugar

when defined(macosx):
  let app = initApplication()

  let win = newWindow()
  win.setTitle("WebView extended demo")
  win.setSize(size(1000.0, 700.0), false)

  var page = webviewEx(WebViewOptions(
    javaScriptEnabled: true,
    persistentStore: true,
    applicationNameForUserAgent: "NkitDemo/1.0",
    backForwardGestures: true,
    allowsMagnification: true))
  let wv = WebView(page.view)

  loadUrl(wv, "https://example.com")
  addMessageHandler(wv, "nkit")
  addUserScript(wv, "window.__nkitDemo = true;")
  wv.setNavigationPolicyMode(npAsk)

  discard onNavigationRequested(wv, proc(e: WebViewNavigationEvent) =
    echo "nav: " & e.url & " (" & $e.navType & ")"
    allowNavigation(e.decisionId))

  discard onJsAlert(wv, proc(e: WebViewAlertEvent) =
    echo "js alert: " & e.message
    completeAlert(e.completionId))

  discard onJsConfirm(wv, proc(e: WebViewConfirmEvent) =
    echo "js confirm: " & e.message
    completeConfirm(e.completionId, true))

  discard onJsPrompt(wv, proc(e: WebViewPromptEvent) =
    echo "js prompt: " & e.message
    completePrompt(e.completionId, e.defaultText))

  discard onNewWindow(wv, proc(e: WebViewNewWindowEvent) =
    echo "new window: " & e.url
    loadUrl(wv, e.url))

  discard onPdfResult(wv, proc(e: WebViewPdfEvent) =
    if e.isError:
      echo "pdf failed: " & e.message
    else:
      echo "pdf at: " & e.path)

  discard onSnapshotResult(wv, proc(e: WebViewSnapshotEvent) =
    if e.isError:
      echo "snapshot failed: " & e.message
    else:
      echo "snapshot at: " & e.path)

  discard onCookiesResult(wv, proc(e: WebViewCookiesEvent) =
    echo "cookies: " & e.json)

  # Right-click on the page shows a custom menu instead of the web menu.
  let pageMenu = newMenu()
  pageMenu.addItem(newMenuItem("Back"))
  pageMenu.addItem(newMenuItem("Reload"))
  setContextMenu(wv, pageMenu)
  wv.setDefaultWebContextMenuEnabled(false)

  layout(page)
  win.show()
  discard app.run()
else:
  echo "webview_ex_demo needs macOS"
