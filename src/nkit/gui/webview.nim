## Native web view (WKWebView) for macOS and iOS.
##
## A leaf widget like `ImageView`: drop it into `row`/`column` trees
## (usually inside `expanded` or `sizedBox`, since a web page has no
## meaningful intrinsic size), or mount it directly with `setContent`.
## All navigations stay inside the view; JavaScript runs when
## `javaScriptEnabled` is true (default).
##
## Two-way JS bridge:
##
##   addMessageHandler(wv, "nkit")   # JS: window.webkit.messageHandlers.nkit.postMessage("hi")
##   evaluateJs(wv, "document.title", requestId = 1)  # async -> WebViewJsResultEvent
import std/tables
import nkit/foundation/id_allocator
import nkit/foundation/event
import nkit/foundation/event_emitter
import nkit/gui/view

when defined(ios):
  import nkit/platform/ios/uifunctions
elif defined(macosx):
  import nkit/platform/macos/nsfunctions

export view

const
  webviewStarted* = 0.cint
  webviewFinished* = 1.cint
  webviewFailed* = 2.cint
  webviewProgress* = 3.cint
  webviewMessage* = 4.cint
  webviewJsResult* = 5.cint
  webviewNavRequested* = 6.cint
  webviewPdfResult* = 7.cint
  webviewSnapshotResult* = 8.cint
  webviewCookiesResult* = 9.cint
  webviewJsAlert* = 10.cint
  webviewJsConfirm* = 11.cint
  webviewJsPrompt* = 12.cint
  webviewNewWindow* = 13.cint
  webviewFullscreen* = 14.cint

type
  NavigationType* = enum
    ntLink
    ntFormSubmit
    ntBackForward
    ntReload
    ntFormResubmit
    ntOther

  NavPolicy* = enum
    npAllowAll
    npAsk
    npBlockExternal

  WebHistoryItem* = object
    url*: string
    title*: string

  WebViewOptions* = object
    javaScriptEnabled*: bool = true
    persistentStore*: bool = true
    userAgent*: string = ""
    applicationNameForUserAgent*: string = ""
    backForwardGestures*: bool = true
    allowsMagnification*: bool = true

  WebViewStartedEvent* = ref object of GuiEvent
    webviewId*: Id
    url*: string

  WebViewFinishedEvent* = ref object of GuiEvent
    webviewId*: Id
    url*: string

  WebViewFailedEvent* = ref object of GuiEvent
    webviewId*: Id
    url*: string
    message*: string

  WebViewProgressEvent* = ref object of GuiEvent
    webviewId*: Id
    progress*: float64

  WebViewMessageEvent* = ref object of GuiEvent
    ## A `window.webkit.messageHandlers.<name>.postMessage(...)` call.
    webviewId*: Id
    name*: string
    body*: string

  WebViewJsResultEvent* = ref object of GuiEvent
    ## Completion of one `evaluateJs` call, correlated by `requestId`.
    webviewId*: Id
    requestId*: uint64
    result*: string
    isError*: bool

  WebViewNavigationEvent* = ref object of GuiEvent
    ## A navigation gated by `npAsk`. Reply with
    ## `allowNavigation` / `cancelNavigation`.
    webviewId*: Id
    url*: string
    navType*: NavigationType
    decisionId*: uint64

  WebViewAlertEvent* = ref object of GuiEvent
    ## JS `alert()`. Reply with `completeAlert`.
    webviewId*: Id
    message*: string
    completionId*: uint64

  WebViewConfirmEvent* = ref object of GuiEvent
    ## JS `confirm()`. Reply with `completeConfirm`.
    webviewId*: Id
    message*: string
    completionId*: uint64

  WebViewPromptEvent* = ref object of GuiEvent
    ## JS `prompt()`. Reply with `completePrompt`.
    webviewId*: Id
    message*: string
    defaultText*: string
    completionId*: uint64

  WebViewNewWindowEvent* = ref object of GuiEvent
    ## `window.open` / `target=_blank`. The shim stays on the current
    ## page; call `loadUrl` yourself when you want to follow it.
    webviewId*: Id
    url*: string
    navType*: NavigationType

  WebViewPdfEvent* = ref object of GuiEvent
    ## Completion of one `createPdf` call. On success `path` is a
    ## temp `.pdf` file (caller reads/deletes it); on failure
    ## `isError` is true and `message` explains.
    webviewId*: Id
    requestId*: uint64
    path*: string
    message*: string
    isError*: bool

  WebViewSnapshotEvent* = ref object of GuiEvent
    ## Completion of one `takeSnapshot` call. Same temp-file contract
    ## as `WebViewPdfEvent`, with a `.png` file.
    webviewId*: Id
    requestId*: uint64
    path*: string
    message*: string
    isError*: bool

  WebViewCookiesEvent* = ref object of GuiEvent
    ## Completion of one `getAllCookies` call. `json` is an array of
    ## `{name,value,domain,path,secure,httpOnly,expires}` objects.
    webviewId*: Id
    requestId*: uint64
    json*: string

  WebView* = ref object of View
    javaScriptEnabled*: bool
    persistentStore*: bool

var liveWebViews: Table[uint32, WebView]

method typeName(e: WebViewStartedEvent): string = "WebViewStartedEvent"
method typeName(e: WebViewFinishedEvent): string = "WebViewFinishedEvent"
method typeName(e: WebViewFailedEvent): string = "WebViewFailedEvent"
method typeName(e: WebViewProgressEvent): string = "WebViewProgressEvent"
method typeName(e: WebViewMessageEvent): string = "WebViewMessageEvent"
method typeName(e: WebViewJsResultEvent): string = "WebViewJsResultEvent"
method typeName(e: WebViewNavigationEvent): string = "WebViewNavigationEvent"
method typeName(e: WebViewAlertEvent): string = "WebViewAlertEvent"
method typeName(e: WebViewConfirmEvent): string = "WebViewConfirmEvent"
method typeName(e: WebViewPromptEvent): string = "WebViewPromptEvent"
method typeName(e: WebViewNewWindowEvent): string = "WebViewNewWindowEvent"
method typeName(e: WebViewPdfEvent): string = "WebViewPdfEvent"
method typeName(e: WebViewSnapshotEvent): string = "WebViewSnapshotEvent"
method typeName(e: WebViewCookiesEvent): string = "WebViewCookiesEvent"

proc newWebViewStartedEvent*(webviewId: Id, url: string): WebViewStartedEvent =
  result = WebViewStartedEvent(webviewId: webviewId, url: url)
  discard stamp(result)

proc newWebViewFinishedEvent*(webviewId: Id,
                              url: string): WebViewFinishedEvent =
  result = WebViewFinishedEvent(webviewId: webviewId, url: url)
  discard stamp(result)

proc newWebViewFailedEvent*(webviewId: Id, url,
                            message: string): WebViewFailedEvent =
  result = WebViewFailedEvent(webviewId: webviewId, url: url, message: message)
  discard stamp(result)

proc newWebViewProgressEvent*(webviewId: Id,
                              progress: float64): WebViewProgressEvent =
  result = WebViewProgressEvent(webviewId: webviewId, progress: progress)
  discard stamp(result)

proc newWebViewMessageEvent*(webviewId: Id, name,
                             body: string): WebViewMessageEvent =
  result = WebViewMessageEvent(webviewId: webviewId, name: name, body: body)
  discard stamp(result)

proc newWebViewJsResultEvent*(webviewId: Id, requestId: uint64, jsResult: string,
                              isError: bool): WebViewJsResultEvent =
  result = WebViewJsResultEvent(webviewId: webviewId, requestId: requestId,
                                result: jsResult, isError: isError)
  discard stamp(result)

proc parseNavigationType*(s: string): NavigationType =
  case s
  of "link": ntLink
  of "formSubmit": ntFormSubmit
  of "backForward": ntBackForward
  of "reload": ntReload
  of "formResubmit": ntFormResubmit
  else: ntOther

proc newWebViewNavigationEvent*(webviewId: Id, url: string,
                                navType: NavigationType,
                                decisionId: uint64): WebViewNavigationEvent =
  result = WebViewNavigationEvent(webviewId: webviewId, url: url,
                                  navType: navType, decisionId: decisionId)
  discard stamp(result)

proc newWebViewAlertEvent*(webviewId: Id, message: string,
                           completionId: uint64): WebViewAlertEvent =
  result = WebViewAlertEvent(webviewId: webviewId, message: message,
                             completionId: completionId)
  discard stamp(result)

proc newWebViewConfirmEvent*(webviewId: Id, message: string,
                             completionId: uint64): WebViewConfirmEvent =
  result = WebViewConfirmEvent(webviewId: webviewId, message: message,
                               completionId: completionId)
  discard stamp(result)

proc newWebViewPromptEvent*(webviewId: Id, message, defaultText: string,
                            completionId: uint64): WebViewPromptEvent =
  result = WebViewPromptEvent(webviewId: webviewId, message: message,
                              defaultText: defaultText,
                              completionId: completionId)
  discard stamp(result)

proc newWebViewNewWindowEvent*(webviewId: Id, url: string,
                               navType: NavigationType): WebViewNewWindowEvent =
  result = WebViewNewWindowEvent(webviewId: webviewId, url: url,
                                 navType: navType)
  discard stamp(result)

proc newWebViewPdfEvent*(webviewId: Id, requestId: uint64, path, message: string,
                         isError: bool): WebViewPdfEvent =
  result = WebViewPdfEvent(webviewId: webviewId, requestId: requestId,
                           path: path, message: message, isError: isError)
  discard stamp(result)

proc newWebViewSnapshotEvent*(webviewId: Id, requestId: uint64, path,
                              message: string,
                              isError: bool): WebViewSnapshotEvent =
  result = WebViewSnapshotEvent(webviewId: webviewId, requestId: requestId,
                                path: path, message: message, isError: isError)
  discard stamp(result)

proc newWebViewCookiesEvent*(webviewId: Id, requestId: uint64,
                             json: string): WebViewCookiesEvent =
  result = WebViewCookiesEvent(webviewId: webviewId, requestId: requestId,
                               json: json)
  discard stamp(result)

when defined(macosx) or defined(ios):
  proc webviewEventTrampoline(widgetId: uint32, kind: cint, arg1, arg2: cstring,
                              num: float64, num2: uint64,
                              ctx: pointer) {.cdecl.} =
    let wv = liveWebViews.getOrDefault(widgetId)
    if wv.isNil:
      return
    # Copy native strings synchronously; the buffers are only valid
    # for the duration of this call.
    let a1 = if arg1.isNil: "" else: $arg1
    let a2 = if arg2.isNil: "" else: $arg2
    case kind
    of webviewStarted:
      emitAsync(wv, newWebViewStartedEvent(wv.id, a1))
    of webviewFinished:
      emitAsync(wv, newWebViewFinishedEvent(wv.id, a1))
    of webviewFailed:
      emitAsync(wv, newWebViewFailedEvent(wv.id, a1, a2))
    of webviewProgress:
      emitAsync(wv, newWebViewProgressEvent(wv.id, num))
    of webviewMessage:
      emitAsync(wv, newWebViewMessageEvent(wv.id, a1, a2))
    of webviewJsResult:
      emitAsync(wv, newWebViewJsResultEvent(wv.id, num2, a1, num != 0.0))
    of webviewNavRequested:
      emitAsync(wv, newWebViewNavigationEvent(wv.id, a1,
        parseNavigationType(a2), num2))
    of webviewJsAlert:
      emitAsync(wv, newWebViewAlertEvent(wv.id, a1, num2))
    of webviewJsConfirm:
      emitAsync(wv, newWebViewConfirmEvent(wv.id, a1, num2))
    of webviewJsPrompt:
      emitAsync(wv, newWebViewPromptEvent(wv.id, a1, a2, num2))
    of webviewNewWindow:
      emitAsync(wv, newWebViewNewWindowEvent(wv.id, a1,
        parseNavigationType(a2)))
    of webviewPdfResult:
      emitAsync(wv, newWebViewPdfEvent(wv.id, num2, a1, a2, num != 0.0))
    of webviewSnapshotResult:
      emitAsync(wv, newWebViewSnapshotEvent(wv.id, num2, a1, a2, num != 0.0))
    of webviewCookiesResult:
      emitAsync(wv, newWebViewCookiesEvent(wv.id, num2, a1))
    else:
      discard

var webviewCallbacksArmed = false

proc ensureWebViewCallbacks*() =
  when defined(macosx) or defined(ios):
    if not webviewCallbacksArmed:
      naWebviewSetEventCallback(webviewEventTrampoline, nil)
      webviewCallbacksArmed = true

proc newWebView*(javaScriptEnabled = true): WebView =
  ensureWebViewCallbacks()
  let vid = allocate(typeTagGuiWidget)
  when defined(macosx) or defined(ios):
    let nativePtr = naWebviewCreate(vid.uint32, javaScriptEnabled)
  else:
    let nativePtr: pointer = nil
  result = WebView(javaScriptEnabled: javaScriptEnabled, persistentStore: true)
  discard wrapView(result, nativePtr, vid)
  liveWebViews[vid.uint32] = result

when defined(macosx):
  proc newWebViewEx*(opts: WebViewOptions): WebView =
    ## Extended constructor: private store, custom UA, gestures.
    ensureWebViewCallbacks()
    let vid = allocate(typeTagGuiWidget)
    let ua = if opts.userAgent.len > 0: opts.userAgent.cstring else: nil
    let appName = if opts.applicationNameForUserAgent.len > 0:
      opts.applicationNameForUserAgent.cstring
    else:
      nil
    let nativePtr = naWebviewCreateEx(vid.uint32, opts.javaScriptEnabled,
      opts.persistentStore, ua, appName)
    result = WebView(javaScriptEnabled: opts.javaScriptEnabled,
      persistentStore: opts.persistentStore)
    discard wrapView(result, nativePtr, vid)
    liveWebViews[vid.uint32] = result
    naWebviewSetBackForwardGestures(result.native, opts.backForwardGestures)
    naWebviewSetAllowsMagnification(result.native, opts.allowsMagnification)

proc destroy*(wv: WebView) =
  when defined(macosx) or defined(ios):
    naWebviewFree(wv.nativeKey, wv.native)
    wv.native = nil
  liveWebViews.del(wv.nativeKey)
  shutdownEmitter[GuiEvent](wv)

proc loadUrl*(wv: WebView, url: string) =
  when defined(macosx) or defined(ios):
    naWebviewLoadUrl(wv.native, url.cstring)

proc loadHtml*(wv: WebView, html: string, baseUrl = "") =
  when defined(macosx) or defined(ios):
    naWebviewLoadHtml(wv.native, html.cstring, baseUrl.cstring)

proc reload*(wv: WebView) =
  when defined(macosx) or defined(ios):
    naWebviewReload(wv.native)

proc stopLoading*(wv: WebView) =
  when defined(macosx) or defined(ios):
    naWebviewStop(wv.native)

proc goBack*(wv: WebView) =
  when defined(macosx) or defined(ios):
    naWebviewGoBack(wv.native)

proc goForward*(wv: WebView) =
  when defined(macosx) or defined(ios):
    naWebviewGoForward(wv.native)

proc canGoBack*(wv: WebView): bool =
  when defined(macosx) or defined(ios):
    naWebviewCanGoBack(wv.native)
  else:
    false

proc canGoForward*(wv: WebView): bool =
  when defined(macosx) or defined(ios):
    naWebviewCanGoForward(wv.native)
  else:
    false

proc getUrl*(wv: WebView): string =
  when defined(macosx) or defined(ios):
    $naWebviewGetUrl(wv.native)
  else:
    ""

proc getTitle*(wv: WebView): string =
  when defined(macosx) or defined(ios):
    $naWebviewGetTitle(wv.native)
  else:
    ""

proc getProgress*(wv: WebView): float64 =
  when defined(macosx) or defined(ios):
    naWebviewGetProgress(wv.native)
  else:
    0.0

proc isLoading*(wv: WebView): bool =
  when defined(macosx) or defined(ios):
    naWebviewIsLoading(wv.native)
  else:
    false

proc evaluateJs*(wv: WebView, script: string, requestId = 0'u64) =
  ## Runs `script` asynchronously. The outcome arrives as a
  ## `WebViewJsResultEvent` carrying `requestId`.
  when defined(macosx) or defined(ios):
    naWebviewEvaluateJs(wv.native, script.cstring, requestId)

proc addMessageHandler*(wv: WebView, name = "nkit") =
  ## Exposes `window.webkit.messageHandlers.<name>.postMessage(...)` to the
  ## page. Messages arrive as `WebViewMessageEvent`.
  when defined(macosx) or defined(ios):
    naWebviewAddMessageHandler(wv.native, name.cstring)

proc onLoadStarted*(wv: WebView,
                    handler: proc(e: WebViewStartedEvent)): ListenerId =
  addListener[GuiEvent, WebViewStartedEvent](wv, handler)

proc onLoadFinished*(wv: WebView,
                     handler: proc(e: WebViewFinishedEvent)): ListenerId =
  addListener[GuiEvent, WebViewFinishedEvent](wv, handler)

proc onLoadFailed*(wv: WebView,
                   handler: proc(e: WebViewFailedEvent)): ListenerId =
  addListener[GuiEvent, WebViewFailedEvent](wv, handler)

proc onProgress*(wv: WebView,
                 handler: proc(e: WebViewProgressEvent)): ListenerId =
  addListener[GuiEvent, WebViewProgressEvent](wv, handler)

proc onMessage*(wv: WebView,
                handler: proc(e: WebViewMessageEvent)): ListenerId =
  addListener[GuiEvent, WebViewMessageEvent](wv, handler)

proc onJsResult*(wv: WebView,
                 handler: proc(e: WebViewJsResultEvent)): ListenerId =
  addListener[GuiEvent, WebViewJsResultEvent](wv, handler)

proc onNavigationRequested*(wv: WebView,
    handler: proc(e: WebViewNavigationEvent)): ListenerId =
  addListener[GuiEvent, WebViewNavigationEvent](wv, handler)

proc onJsAlert*(wv: WebView,
    handler: proc(e: WebViewAlertEvent)): ListenerId =
  addListener[GuiEvent, WebViewAlertEvent](wv, handler)

proc onJsConfirm*(wv: WebView,
    handler: proc(e: WebViewConfirmEvent)): ListenerId =
  addListener[GuiEvent, WebViewConfirmEvent](wv, handler)

proc onJsPrompt*(wv: WebView,
    handler: proc(e: WebViewPromptEvent)): ListenerId =
  addListener[GuiEvent, WebViewPromptEvent](wv, handler)

proc onNewWindow*(wv: WebView,
    handler: proc(e: WebViewNewWindowEvent)): ListenerId =
  addListener[GuiEvent, WebViewNewWindowEvent](wv, handler)

proc onPdfResult*(wv: WebView,
    handler: proc(e: WebViewPdfEvent)): ListenerId =
  addListener[GuiEvent, WebViewPdfEvent](wv, handler)

proc onSnapshotResult*(wv: WebView,
    handler: proc(e: WebViewSnapshotEvent)): ListenerId =
  addListener[GuiEvent, WebViewSnapshotEvent](wv, handler)

proc onCookiesResult*(wv: WebView,
    handler: proc(e: WebViewCookiesEvent)): ListenerId =
  addListener[GuiEvent, WebViewCookiesEvent](wv, handler)

proc fireTestEvent*(wv: WebView, kind: cint, arg1 = "", arg2 = "",
                    num = 0.0, num2 = 0'u64) =
  ## Full-stack test hook: replays an event without a live page load.
  when defined(macosx) or defined(ios):
    naWebviewFire(wv.nativeKey, kind, arg1.cstring, arg2.cstring, num, num2)

when defined(macosx):
  proc removeMessageHandler*(wv: WebView, name: string) =
    naWebviewRemoveMessageHandler(wv.native, name.cstring)

  proc removeAllMessageHandlers*(wv: WebView) =
    naWebviewRemoveAllMessageHandlers(wv.native)

  proc addUserScript*(wv: WebView, source: string, atDocumentEnd = true,
                      mainFrameOnly = true) =
    ## Injects `source` into every page load.
    naWebviewAddUserScript(wv.native, source.cstring, atDocumentEnd,
      mainFrameOnly)

  proc removeAllUserScripts*(wv: WebView) =
    naWebviewRemoveAllUserScripts(wv.native)

  proc addContentRule*(wv: WebView, json, identifier: string) =
    ## Compiles a WebKit content-blocker rule list and attaches it.
    naWebviewAddContentRule(wv.native, json.cstring, identifier.cstring)

  proc removeAllContentRules*(wv: WebView) =
    naWebviewRemoveAllContentRules(wv.native)

  proc setUserAgent*(wv: WebView, ua: string) =
    ## Empty string restores the default user agent.
    naWebviewSetUserAgent(wv.native, ua.cstring)

  proc getUserAgent*(wv: WebView): string =
    ## Returns the custom UA override, or "" when using the default.
    $naWebviewGetUserAgent(wv.native)

  proc setBackForwardGestures*(wv: WebView, enabled: bool) =
    naWebviewSetBackForwardGestures(wv.native, enabled)

  proc getBackForwardGestures*(wv: WebView): bool =
    naWebviewGetBackForwardGestures(wv.native)

  proc setMagnification*(wv: WebView, m: float64, cx = 0.0, cy = 0.0) =
    naWebviewSetMagnification(wv.native, m, cx, cy)

  proc getMagnification*(wv: WebView): float64 =
    naWebviewGetMagnification(wv.native)

  proc setAllowsMagnification*(wv: WebView, allowed: bool) =
    naWebviewSetAllowsMagnification(wv.native, allowed)

  proc setPageZoom*(wv: WebView, zoom: float64) =
    naWebviewSetPageZoom(wv.native, zoom)

  proc getPageZoom*(wv: WebView): float64 =
    naWebviewGetPageZoom(wv.native)

  proc reloadFromOrigin*(wv: WebView) =
    naWebviewReloadFromOrigin(wv.native)

  proc loadFileUrl*(wv: WebView, path, readAccessDir = "") =
    let access = if readAccessDir.len > 0: readAccessDir.cstring else: nil
    naWebviewLoadFileUrl(wv.native, path.cstring, access)

  proc loadData*(wv: WebView, data, mimeType = "text/html",
                 encoding = "utf-8", baseUrl = "about:blank") =
    naWebviewLoadData(wv.native, data.cstring, mimeType.cstring,
      encoding.cstring, baseUrl.cstring)

  proc getBackList*(wv: WebView): seq[WebHistoryItem] =
    let n = int(naWebviewBackCount(wv.native))
    for i in 0 ..< n:
      result.add(WebHistoryItem(
        url: $naWebviewHistoryUrl(wv.native, false, cint(i)),
        title: $naWebviewHistoryTitle(wv.native, false, cint(i))))

  proc getForwardList*(wv: WebView): seq[WebHistoryItem] =
    let n = int(naWebviewForwardCount(wv.native))
    for i in 0 ..< n:
      result.add(WebHistoryItem(
        url: $naWebviewHistoryUrl(wv.native, true, cint(i)),
        title: $naWebviewHistoryTitle(wv.native, true, cint(i))))

  proc goToHistoryOffset*(wv: WebView, offset: int): bool =
    ## Negative = back, positive = forward. False when out of range.
    naWebviewGoToOffset(wv.native, cint(offset))

  proc setNavigationPolicyMode*(wv: WebView, mode: NavPolicy) =
    naWebviewSetPolicyMode(wv.native, cint(ord(mode)))

  proc getNavigationPolicyMode*(wv: WebView): NavPolicy =
    NavPolicy(int(naWebviewGetPolicyMode(wv.native)))

  proc allowNavigation*(decisionId: uint64) =
    naWebviewDecideNavigation(decisionId, true)

  proc cancelNavigation*(decisionId: uint64) =
    naWebviewDecideNavigation(decisionId, false)

  proc completeAlert*(completionId: uint64) =
    naWebviewCompleteAlert(completionId)

  proc completeConfirm*(completionId: uint64, confirmed: bool) =
    naWebviewCompleteConfirm(completionId, confirmed)

  proc completePrompt*(completionId: uint64, text: string) =
    naWebviewCompletePrompt(completionId, text.cstring, false)

  proc cancelPrompt*(completionId: uint64) =
    naWebviewCompletePrompt(completionId, nil, true)

  proc createPdf*(wv: WebView, requestId: uint64) =
    ## Renders the page to a temp `.pdf`. Result arrives as
    ## `WebViewPdfEvent` carrying `requestId`.
    naWebviewCreatePdf(wv.native, requestId)

  proc takeSnapshot*(wv: WebView, requestId: uint64) =
    ## Captures the view to a temp `.png`. Result arrives as
    ## `WebViewSnapshotEvent` carrying `requestId`.
    naWebviewSnapshot(wv.native, requestId)

  proc getAllCookies*(wv: WebView, requestId: uint64) =
    ## Lists cookies as JSON. Result arrives as `WebViewCookiesEvent`.
    naWebviewGetCookies(wv.native, requestId)

  proc setCookie*(wv: WebView, name, value: string, domain = "",
                  path = "/", maxAgeSec = 0.0) =
    let d = if domain.len > 0: domain.cstring else: nil
    naWebviewSetCookie(wv.native, name.cstring, value.cstring, d,
      path.cstring, maxAgeSec)

  proc deleteCookie*(wv: WebView, name: string) =
    naWebviewDeleteCookie(wv.native, name.cstring)

  proc clearWebsiteData*(wv: WebView, includeCookies = true,
                         includeCache = true, includeStorage = true,
                         sinceUnix = 0.0) =
    naWebviewClearWebsiteData(wv.native, includeCookies, includeCache,
      includeStorage, sinceUnix)

  proc clearAllWebsiteData*(wv: WebView) =
    naWebviewClearAllWebsiteData(wv.native)

  proc findInPage*(wv: WebView, text: string, requestId: uint64,
                   backwards = false, caseSensitive = false, wraps = true) =
    ## Searches the page via `window.find`. The boolean result ("true" /
    ## "false") arrives as a `WebViewJsResultEvent` carrying `requestId`.
    naWebviewFind(wv.native, text.cstring, backwards, caseSensitive, wraps,
      requestId)

  proc hideFindHighlight*(wv: WebView) =
    ## Clears the selection left by `findInPage`.
    naWebviewHideFind(wv.native)

  proc printPage*(wv: WebView) =
    ## Opens the standard print panel. Manual QA only: it blocks, so
    ## never call it from headless tests.
    naWebviewPrint(wv.native)

  proc setDefaultWebContextMenuEnabled*(wv: WebView, enabled: bool) =
    ## When false, right-clicks skip the standard web menu and show the
    ## Nim menu attached with `setContextMenu` instead (or nothing when
    ## no menu is attached). Default true.
    naWebviewSetContextMenuEnabled(wv.native, enabled)

  proc getDefaultWebContextMenuEnabled*(wv: WebView): bool =
    naWebviewGetContextMenuEnabled(wv.native)
