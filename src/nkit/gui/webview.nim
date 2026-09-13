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

type
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

  WebView* = ref object of View
    javaScriptEnabled*: bool

var liveWebViews: Table[uint32, WebView]

method typeName(e: WebViewStartedEvent): string = "WebViewStartedEvent"
method typeName(e: WebViewFinishedEvent): string = "WebViewFinishedEvent"
method typeName(e: WebViewFailedEvent): string = "WebViewFailedEvent"
method typeName(e: WebViewProgressEvent): string = "WebViewProgressEvent"
method typeName(e: WebViewMessageEvent): string = "WebViewMessageEvent"
method typeName(e: WebViewJsResultEvent): string = "WebViewJsResultEvent"

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
  result = WebView(javaScriptEnabled: javaScriptEnabled)
  discard wrapView(result, nativePtr, vid)
  liveWebViews[vid.uint32] = result

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

proc fireTestEvent*(wv: WebView, kind: cint, arg1 = "", arg2 = "",
                    num = 0.0, num2 = 0'u64) =
  ## Full-stack test hook: replays an event without a live page load.
  when defined(macosx) or defined(ios):
    naWebviewFire(wv.nativeKey, kind, arg1.cstring, arg2.cstring, num, num2)
