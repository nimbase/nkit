import std/[tables]
import ../foundation/id_allocator
import ../foundation/event
import ../foundation/event_emitter
import ../foundation/geometry
import ../window
import ../window_manager
import ./view
when defined(linux):
  import ../platform/linux/gfunctions
elif defined(macosx):
  import ../platform/macos/nsfunctions
elif defined(ios):
  import ../platform/ios/uifunctions

when defined(ios):
  import ../platform/ios/uifunctions
elif defined(macosx):
  import ../platform/macos/nsfunctions
elif defined(linux):
  import ../platform/linux/gfunctions

export view

# ── enums mirroring WKWebKit ────────────────────────────────────────
type
  WebInjectionTime* = enum
    witStart = 0
    witEnd = 1
  WebContentMode* = enum
    wcmRecommended = 0
    wcmMobile = 1
    wcmDesktop = 2
  WebMediaTypes* = enum
    wmtNone = 0
    wmtAudio = 1
    wmtVideo = 2
    wmtAll = 3
  WebDataDetectorTypes* = enum
    wdtNone = 0
    wdtPhoneNumber = 1
    wdtLink = 2
    wdtAddress = 4
    wdtCalendarEvent = 8
  WebWebsiteDataTypes* = enum
    wdtCookies = 1
    wdtDiskCache = 2
    wdtMemoryCache = 4
    wdtOfflineCache = 8
    wdtSessionStorage = 16
    wdtLocalStorage = 32
    wdtWebSQL = 64
    wdtIndexedDB = 128
    wdtAll = 0
  WebCookieAcceptPolicy* = enum
    wcapAlways = 0
    wcapNever = 1
    wcapNoThirdParty = 2
  WebTlsErrorsPolicy* = enum
    wtepIgnore = 0
    wtepFail = 1
  WebDialogKind* = enum
    wdkAlert = 0
    wdkConfirm = 1
    wdkPrompt = 2
  WebPermissionKind* = enum
    wpkUnknown = 0
    wpkGeolocation = 1
    wpkNotification = 2
    wpkMediaKeySystem = 3
  WebNavigationKind* = enum
    wnkDecidePolicy = 0
    wnkStarted = 1
    wnkCommitted = 2
    wnkFinished = 3
    wnkFailed = 4
  WebPolicyDecisionKind* = enum
    wpdkNavigationAction = 0
    wpdkResponse = 1
    wpdkNewWindowAction = 2

# ── events ──────────────────────────────────────────────────────────
type
  WebNavigationEvent* = ref object of GuiEvent
    webViewId*: Id
    kind*: WebNavigationKind
    url*: string
  WebProgressEvent* = ref object of GuiEvent
    webViewId*: Id
    progress*: float
  WebMessageEvent* = ref object of GuiEvent
    webViewId*: Id
    handler*: string
    body*: string
  WebDialogEvent* = ref object of GuiEvent
    webViewId*: Id
    kind*: WebDialogKind
    message*: string
    defaultText*: string
  WebPermissionEvent* = ref object of GuiEvent
    webViewId*: Id
    origin*: string
    permission*: WebPermissionKind
  WebTerminateEvent* = ref object of GuiEvent
    webViewId*: Id
  WebPolicyEvent* = ref object of GuiEvent
    webViewId*: Id
    decisionId*: uint32
    decisionType*: WebPolicyDecisionKind
    url*: string
  WebSchemeEvent* = ref object of GuiEvent
    webViewId*: Id
    scheme*: string
    url*: string
    requestId*: uint32

method typeName*(e: WebNavigationEvent): string = "WebNavigationEvent"
method typeName*(e: WebProgressEvent): string = "WebProgressEvent"
method typeName*(e: WebMessageEvent): string = "WebMessageEvent"
method typeName*(e: WebDialogEvent): string = "WebDialogEvent"
method typeName*(e: WebPermissionEvent): string = "WebPermissionEvent"
method typeName*(e: WebTerminateEvent): string = "WebTerminateEvent"
method typeName*(e: WebPolicyEvent): string = "WebPolicyEvent"
method typeName*(e: WebSchemeEvent): string = "WebSchemeEvent"

# ── WebContext (WKProcessPool + WKWebsiteDataStore) ────────────────
type WebContext* = ref object
  native*: pointer
  ephemeral*: bool

proc newWebContext*(ephemeral = false): WebContext =
  when defined(linux):
    let p = if ephemeral: naWebContextCreateEphemeral() else: naWebContextCreate()
    result = WebContext(native: p, ephemeral: ephemeral)
  else:
    result = WebContext(native: nil, ephemeral: ephemeral)

proc newEphemeralWebContext*(): WebContext = newWebContext(true)

proc destroy*(ctx: WebContext) =
  when defined(linux):
    if not ctx.native.isNil: naWebContextFree(ctx.native)
  ctx.native = nil

proc setCacheEnabled*(ctx: WebContext, v: bool) =
  when defined(linux):
    if not ctx.native.isNil: naWebContextSetCacheEnabled(ctx.native, v)
proc setDiskCacheEnabled*(ctx: WebContext, v: bool) =
  when defined(linux):
    if not ctx.native.isNil: naWebContextSetDiskCacheEnabled(ctx.native, v)
proc clearWebsiteData*(ctx: WebContext, typesMask: int = 0) =
  when defined(linux):
    if not ctx.native.isNil: naWebContextClearWebsiteData(ctx.native, cint(typesMask))
proc setItpEnabled*(ctx: WebContext, v: bool) =
  when defined(linux):
    if not ctx.native.isNil: naWebContextSetItpEnabled(ctx.native, v)
proc setTlsErrorsPolicy*(ctx: WebContext, p: WebTlsErrorsPolicy) =
  when defined(linux):
    if not ctx.native.isNil: naWebContextSetTlsErrorsPolicy(ctx.native, cint(ord(p)))

# cookie store per context
proc setCookie*(ctx: WebContext, url, cookie: string) =
  when defined(linux):
    if not ctx.native.isNil: naWebContextCookieSet(ctx.native, url.cstring, cookie.cstring)
proc getCookie*(ctx: WebContext, url: string): string =
  when defined(linux):
    if not ctx.native.isNil: $naWebContextCookieGet(ctx.native, url.cstring)
    else: ""
  else: ""
proc deleteCookie*(ctx: WebContext, url, name: string) =
  when defined(linux):
    if not ctx.native.isNil: naWebContextCookieDelete(ctx.native, url.cstring, name.cstring)
proc setCookieAcceptPolicy*(ctx: WebContext, p: WebCookieAcceptPolicy) =
  when defined(linux):
    if not ctx.native.isNil: naWebContextSetCookieAcceptPolicy(ctx.native, cint(ord(p)))
proc getCookieAcceptPolicy*(ctx: WebContext): WebCookieAcceptPolicy =
  when defined(linux):
    if not ctx.native.isNil: WebCookieAcceptPolicy(naWebContextGetCookieAcceptPolicy(ctx.native))
    else: wcapAlways
  else: wcapAlways
proc setPersistentStoragePath*(ctx: WebContext, path: string) =
  when defined(linux):
    if not ctx.native.isNil: naWebContextSetPersistentStoragePath(ctx.native, path.cstring)

# async cookie/data callbacks (simplified: global)
var cookieCallbacks: Table[uint32, proc(json: string)]
var dataCallbacks: Table[uint32, proc(json: string)]
var nextCookieReq: uint32 = 1
when defined(linux):
  proc cookieTrampoline(req: uint32, json: cstring, ctx: pointer) {.cdecl.} =
    let cb = cookieCallbacks.getOrDefault(req)
    if not cb.isNil: cb($json)
    cookieCallbacks.del(req)
  proc dataTrampoline(req: uint32, json: cstring, ctx: pointer) {.cdecl.} =
    let cb = dataCallbacks.getOrDefault(req)
    if not cb.isNil: cb($json)
    dataCallbacks.del(req)
  var cookieCbArmed = false
  var dataCbArmed = false
  proc ensureCookieCb() =
    if not cookieCbArmed:
      naWebContextSetCookieCallback(cookieTrampoline, nil)
      cookieCbArmed = true
  proc ensureDataCb() =
    if not dataCbArmed:
      naWebContextSetDataRecordsCallback(dataTrampoline, nil)
      dataCbArmed = true

proc getAllCookies*(ctx: WebContext, cb: proc(json: string)) =
  when defined(linux):
    ensureCookieCb()
    let req = nextCookieReq; inc nextCookieReq
    cookieCallbacks[req] = cb
    if not ctx.native.isNil: naWebContextCookieGetAll(ctx.native, req)
    else: cb("[]")
  else: cb("[]")

proc fetchDataRecords*(ctx: WebContext, typesMask: int, cb: proc(json: string)) =
  when defined(linux):
    ensureDataCb()
    let req = nextCookieReq; inc nextCookieReq
    dataCallbacks[req] = cb
    if not ctx.native.isNil: naWebContextFetchDataRecords(ctx.native, cint(typesMask), req)
    else: cb("[]")
  else: cb("[]")

# ── WebView ─────────────────────────────────────────────────────────
type WebView* = ref object of View
  context*: WebContext
  ownsContext*: bool
  fitContainer*: View
  fitToolbar*: View
  fitWindowId*: WindowId

var liveWebViews: Table[uint32, WebView]
var jsCallbacks: Table[uint32, proc(resultJson: string, isError: bool)]
var pdfCallbacks: Table[uint32, proc(success: bool)]
var snapCallbacks: Table[uint32, proc(imageHandle: int64)]
var nextJsReq: uint32 = 1
var nextPdfReq: uint32 = 1
var nextSnapReq: uint32 = 1

when defined(linux):
  proc navTrampoline(wid: uint32, kind: cint, url: cstring, ctx: pointer) {.cdecl.} =
    let w = liveWebViews.getOrDefault(wid)
    if w.isNil: return
    let k = WebNavigationKind(kind)
    emitAsync(w, WebNavigationEvent(webViewId: w.id, kind: k, url: $url))
  proc progTrampoline(wid: uint32, progress: float64, ctx: pointer) {.cdecl.} =
    let w = liveWebViews.getOrDefault(wid)
    if w.isNil: return
    emitAsync(w, WebProgressEvent(webViewId: w.id, progress: progress))
  proc msgTrampoline(wid: uint32, handler: cstring, body: cstring, ctx: pointer) {.cdecl.} =
    let w = liveWebViews.getOrDefault(wid)
    if w.isNil: return
    emitAsync(w, WebMessageEvent(webViewId: w.id, handler: $handler, body: $body))
  proc decideTrampoline(wid: uint32, did: uint32, dtype: cint, url: cstring, ctx: pointer) {.cdecl.} =
    let w = liveWebViews.getOrDefault(wid)
    if w.isNil: return
    let ev = WebPolicyEvent(
      webViewId: w.id,
      decisionId: did,
      decisionType: WebPolicyDecisionKind(dtype),
      url: $url
    )
    emitAsync(w, ev)
  proc termTrampoline(wid: uint32, ctx: pointer) {.cdecl.} =
    let w = liveWebViews.getOrDefault(wid)
    if w.isNil: return
    emitAsync(w, WebTerminateEvent(webViewId: w.id))
  proc scriptTrampoline(wid: uint32, req: uint32, res: cstring, isErr: bool, ctx: pointer) {.cdecl.} =
    let cb = jsCallbacks.getOrDefault(req)
    if not cb.isNil:
      cb($res, isErr)
      jsCallbacks.del(req)
  proc schemeTrampoline(wid: uint32, scheme: cstring, url: cstring, req: uint32, ctx: pointer) {.cdecl.} =
    let w = liveWebViews.getOrDefault(wid)
    if w.isNil: return
    emitAsync(w, WebSchemeEvent(webViewId: w.id, scheme: $scheme, url: $url, requestId: req))
  proc pdfTrampoline(wid: uint32, req: uint32, ok: bool, ctx: pointer) {.cdecl.} =
    let cb = pdfCallbacks.getOrDefault(req)
    if not cb.isNil:
      cb(ok)
      pdfCallbacks.del(req)
  proc snapTrampoline(wid: uint32, req: uint32, handle: int64, ctx: pointer) {.cdecl.} =
    let cb = snapCallbacks.getOrDefault(req)
    if not cb.isNil:
      cb(handle)
      snapCallbacks.del(req)
  proc dupCstr(s: string): cstring =
    let n = s.len
    let p = cast[cstring](alloc(n+1))
    if n > 0: copyMem(p, s.cstring, n)
    cast[ptr UncheckedArray[char]](p)[n] = '\0'
    p
  proc dialogTrampoline(wid: uint32, kind: cint, msg: cstring, def: cstring, ctx: pointer): cstring {.cdecl.} =
    let w = liveWebViews.getOrDefault(wid)
    if w.isNil: return nil
    var ev = WebDialogEvent(webViewId: w.id, kind: WebDialogKind(kind), message: $msg, defaultText: $def)
    emitAsync(w, ev)
    if kind == 0: return nil
    elif kind == 1: return dupCstr("true")
    else: return dupCstr($def)
  proc permTrampoline(wid: uint32, origin: cstring, perm: cint, ctx: pointer): bool {.cdecl.} =
    let w = liveWebViews.getOrDefault(wid)
    if w.isNil: return false
    emitAsync(w, WebPermissionEvent(webViewId: w.id, origin: $origin, permission: WebPermissionKind(perm)))
    return false

var webCallbacksArmed = false
proc ensureWebCallbacks() =
  when defined(linux):
    if not webCallbacksArmed:
      naWebViewSetNavigationCallback(navTrampoline, nil)
      naWebViewSetProgressCallback(progTrampoline, nil)
      naWebViewSetMessageCallback(msgTrampoline, nil)
      naWebViewSetDecidePolicyCallback(decideTrampoline, nil)
      naWebViewSetTerminateCallback(termTrampoline, nil)
      naWebViewSetScriptResultCallback(scriptTrampoline, nil)
      naWebViewSetSchemeCallback(schemeTrampoline, nil)
      naWebViewSetPdfCallback(pdfTrampoline, nil)
      naWebViewSetSnapshotCallback(snapTrampoline, nil)
      naWebViewSetDialogCallback(dialogTrampoline, nil)
      naWebViewSetPermissionCallback(permTrampoline, nil)
      webCallbacksArmed = true

proc newWebView*(context: WebContext = nil): WebView =
  ensureWebCallbacks()
  let vid = allocate(typeTagGuiWidget)
  var ctx = context
  var owns = false
  if ctx.isNil:
    ctx = newWebContext()
    owns = true
  when defined(linux):
    let nativePtr = if not ctx.native.isNil:
      naWebViewCreateWithContext(vid.uint32, ctx.native)
    else:
      naWebViewCreate(vid.uint32)
  else:
    let nativePtr: pointer = nil
  result = WebView(context: ctx, ownsContext: owns)
  discard wrapView(result, nativePtr, vid)
  liveWebViews[vid.uint32] = result

proc newSharedWebView*(sharedCtx: WebContext): WebView =
  ## Shared process-pool/data-store: reuse same WebKitWebContext.
  doAssert(not sharedCtx.isNil, "sharedCtx required")
  ensureWebCallbacks()
  let vid = allocate(typeTagGuiWidget)
  when defined(linux):
    let nativePtr = naWebViewCreateWithContext(vid.uint32, sharedCtx.native)
  else:
    let nativePtr: pointer = nil
  result = WebView(context: sharedCtx, ownsContext: false)
  discard wrapView(result, nativePtr, vid)
  liveWebViews[vid.uint32] = result

proc destroy*(w: WebView) =
  when defined(linux):
    if not w.native.isNil:
      naWebViewFree(w.nativeKey, w.native)
      w.native = nil
  liveWebViews.del(w.nativeKey)
  if w.ownsContext and not w.context.isNil:
    destroy(w.context)
  shutdownEmitter[GuiEvent](w)

# ── loading ──
proc loadUrl*(w: WebView, url: string) =
  when defined(linux):
    if not w.native.isNil: naWebViewLoadUrl(w.native, url.cstring)
proc loadHtml*(w: WebView, html: string, baseUri = "") =
  when defined(linux):
    if not w.native.isNil: naWebViewLoadHtml(w.native, html.cstring, baseUri.cstring)
proc loadData*(w: WebView, data: string, mimeType = "text/html", encoding = "UTF-8", baseUri = "") =
  when defined(linux):
    if not w.native.isNil: naWebViewLoadData(w.native, data.cstring, cint(data.len), mimeType.cstring, encoding.cstring, baseUri.cstring)
proc loadFileUrl*(w: WebView, fileUrl: string, readAccessUrl = "") =
  when defined(linux):
    if not w.native.isNil: naWebViewLoadFileUrl(w.native, fileUrl.cstring, readAccessUrl.cstring)
proc reload*(w: WebView) =
  when defined(linux):
    if not w.native.isNil: naWebViewReload(w.native)
proc reloadFromOrigin*(w: WebView) =
  when defined(linux):
    if not w.native.isNil: naWebViewReloadFromOrigin(w.native)
proc stopLoading*(w: WebView) =
  when defined(linux):
    if not w.native.isNil: naWebViewStopLoading(w.native)

# navigation stack
proc goBack*(w: WebView): bool =
  when defined(linux):
    if not w.native.isNil: naWebViewGoBack(w.native) else: false
  else: false
proc goForward*(w: WebView): bool =
  when defined(linux):
    if not w.native.isNil: naWebViewGoForward(w.native) else: false
  else: false
proc canGoBack*(w: WebView): bool =
  when defined(linux):
    if not w.native.isNil: naWebViewCanGoBack(w.native) else: false
  else: false
proc canGoForward*(w: WebView): bool =
  when defined(linux):
    if not w.native.isNil: naWebViewCanGoForward(w.native) else: false
  else: false
proc goToBackForwardIndex*(w: WebView, idx: int): bool =
  when defined(linux):
    if not w.native.isNil: naWebViewGoToBackForwardIndex(w.native, cint(idx)) else: false
  else: false
proc backForwardCount*(w: WebView): int =
  when defined(linux):
    if not w.native.isNil: int(naWebViewBackForwardCount(w.native)) else: 0
  else: 0
proc backForwardCurrentIndex*(w: WebView): int =
  when defined(linux):
    if not w.native.isNil: int(naWebViewBackForwardCurrentIndex(w.native)) else: -1
  else: -1
proc backForwardItemAt*(w: WebView, idx: int): tuple[url: string, title: string, ok: bool] =
  when defined(linux):
    if w.native.isNil: return ("","",false)
    var u = newString(4096)
    var t = newString(4096)
    let ok = naWebViewBackForwardItemAt(w.native, cint(idx), u.cstring, t.cstring, 4096)
    if ok:
      return ($cstring(u.cstring), $cstring(t.cstring), true)
    return ("","",false)
  else: ("","",false)

# state
proc getUrl*(w: WebView): string =
  when defined(linux):
    if not w.native.isNil: $naWebViewGetUrl(w.native) else: ""
  else: ""
proc getTitle*(w: WebView): string =
  when defined(linux):
    if not w.native.isNil: $naWebViewGetTitle(w.native) else: ""
  else: ""
proc getProgress*(w: WebView): float =
  when defined(linux):
    if not w.native.isNil: naWebViewGetProgress(w.native) else: 0.0
  else: 0.0
proc isLoading*(w: WebView): bool =
  when defined(linux):
    if not w.native.isNil: naWebViewIsLoading(w.native) else: false
  else: false
proc hasOnlySecureContent*(w: WebView): bool =
  when defined(linux):
    if not w.native.isNil: naWebViewHasOnlySecureContent(w.native) else: true
  else: true

# ── configuration setters/getters (all WKWebViewConfiguration/WKPreferences) ──
proc setCustomUserAgent*(w: WebView, ua: string) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetCustomUserAgent(w.native, ua.cstring)
proc getCustomUserAgent*(w: WebView): string =
  when defined(linux):
    if not w.native.isNil: $naWebViewGetCustomUserAgent(w.native) else: ""
  else: ""
proc setApplicationNameForUserAgent*(w: WebView, appName: string) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetApplicationNameForUserAgent(w.native, appName.cstring)
proc setAllowsBackForwardGestures*(w: WebView, v: bool) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetAllowsBackForwardGestures(w.native, v)
proc getAllowsBackForwardGestures*(w: WebView): bool =
  when defined(linux):
    if not w.native.isNil: naWebViewGetAllowsBackForwardGestures(w.native) else: false
  else: false
proc setAllowsLinkPreview*(w: WebView, v: bool) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetAllowsLinkPreview(w.native, v)
proc getAllowsLinkPreview*(w: WebView): bool =
  when defined(linux):
    if not w.native.isNil: naWebViewGetAllowsLinkPreview(w.native) else: true
  else: true
proc setInspectable*(w: WebView, v: bool) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetInspectable(w.native, v)
proc isInspectable*(w: WebView): bool =
  when defined(linux):
    if not w.native.isNil: naWebViewIsInspectable(w.native) else: false
  else: false
proc setJavaScriptEnabled*(w: WebView, v: bool) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetJavaScriptEnabled(w.native, v)
proc isJavaScriptEnabled*(w: WebView): bool =
  when defined(linux):
    if not w.native.isNil: naWebViewIsJavaScriptEnabled(w.native) else: true
  else: true
proc setJavaScriptCanOpenWindows*(w: WebView, v: bool) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetJavaScriptCanOpenWindows(w.native, v)
proc isJavaScriptCanOpenWindows*(w: WebView): bool =
  when defined(linux):
    if not w.native.isNil: naWebViewIsJavaScriptCanOpenWindows(w.native) else: false
  else: false
proc setAllowsInlineMediaPlayback*(w: WebView, v: bool) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetAllowsInlineMediaPlayback(w.native, v)
proc getAllowsInlineMediaPlayback*(w: WebView): bool =
  when defined(linux):
    if not w.native.isNil: naWebViewGetAllowsInlineMediaPlayback(w.native) else: false
  else: false
proc setMediaTypesRequiringUserAction*(w: WebView, mask: int) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetMediaTypesRequiringUserAction(w.native, cint(mask))
proc getMediaTypesRequiringUserAction*(w: WebView): int =
  when defined(linux):
    if not w.native.isNil: int(naWebViewGetMediaTypesRequiringUserAction(w.native)) else: 0
  else: 0
proc setMinimumFontSize*(w: WebView, s: int) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetMinimumFontSize(w.native, cint(s))
proc getMinimumFontSize*(w: WebView): int =
  when defined(linux):
    if not w.native.isNil: int(naWebViewGetMinimumFontSize(w.native)) else: 0
  else: 0
proc setDefaultFontSize*(w: WebView, s: int) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetDefaultFontSize(w.native, cint(s))
proc setSerifFontFamily*(w: WebView, f: string) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetSerifFontFamily(w.native, f.cstring)
proc setSansSerifFontFamily*(w: WebView, f: string) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetSansSerifFontFamily(w.native, f.cstring)
proc setMonospaceFontFamily*(w: WebView, f: string) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetMonospaceFontFamily(w.native, f.cstring)
proc setDefaultCharset*(w: WebView, c: string) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetDefaultCharset(w.native, c.cstring)
proc setAutoLoadImages*(w: WebView, v: bool) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetAutoLoadImages(w.native, v)
proc getAutoLoadImages*(w: WebView): bool =
  when defined(linux):
    if not w.native.isNil: naWebViewGetAutoLoadImages(w.native) else: true
  else: true
proc setAllowsContentJavaScript*(w: WebView, v: bool) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetAllowsContentJavaScript(w.native, v)
proc getAllowsContentJavaScript*(w: WebView): bool =
  when defined(linux):
    if not w.native.isNil: naWebViewGetAllowsContentJavaScript(w.native) else: true
  else: true
proc setPreferredContentMode*(w: WebView, m: WebContentMode) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetPreferredContentMode(w.native, cint(ord(m)))
proc getPreferredContentMode*(w: WebView): WebContentMode =
  when defined(linux):
    if not w.native.isNil: WebContentMode(naWebViewGetPreferredContentMode(w.native)) else: wcmRecommended
  else: wcmRecommended
proc setDataDetectorTypes*(w: WebView, mask: int) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetDataDetectorTypes(w.native, cint(mask))
proc getDataDetectorTypes*(w: WebView): int =
  when defined(linux):
    if not w.native.isNil: int(naWebViewGetDataDetectorTypes(w.native)) else: 0
  else: 0
proc setZoomLevel*(w: WebView, lvl: float) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetZoomLevel(w.native, lvl)
proc getZoomLevel*(w: WebView): float =
  when defined(linux):
    if not w.native.isNil: naWebViewGetZoomLevel(w.native) else: 1.0
  else: 1.0
proc setMagnification*(w: WebView, m: float) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetMagnification(w.native, m)
proc getMagnification*(w: WebView): float =
  when defined(linux):
    if not w.native.isNil: naWebViewGetMagnification(w.native) else: 1.0
  else: 1.0
proc setBackgroundColor*(w: WebView, r,g,b,a: uint8) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetBackgroundColor(w.native, r,g,b,a)
proc setTransparentBackground*(w: WebView, v: bool) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetTransparentBackground(w.native, v)
proc setEnableDeveloperExtras*(w: WebView, v: bool) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetEnableDeveloperExtras(w.native, v)
proc setEnableCaretBrowsing*(w: WebView, v: bool) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetEnableCaretBrowsing(w.native, v)
proc setEnableSmoothScrolling*(w: WebView, v: bool) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetEnableSmoothScrolling(w.native, v)
proc setEnableMediaStream*(w: WebView, v: bool) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetEnableMediaStream(w.native, v)
proc setEnableMediasource*(w: WebView, v: bool) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetEnableMediasource(w.native, v)
proc setEnableWebaudio*(w: WebView, v: bool) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetEnableWebaudio(w.native, v)
proc setEnableWebrtc*(w: WebView, v: bool) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetEnableWebrtc(w.native, v)
proc setEnableEncryptedMedia*(w: WebView, v: bool) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetEnableEncryptedMedia(w.native, v)
proc setEnableSiteSpecificQuirks*(w: WebView, v: bool) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetEnableSiteSpecificQuirks(w.native, v)
proc setMuted*(w: WebView, v: bool) =
  when defined(linux):
    if not w.native.isNil: naWebViewSetMuted(w.native, v)
proc isMuted*(w: WebView): bool =
  when defined(linux):
    if not w.native.isNil: naWebViewIsMuted(w.native) else: false
  else: false

# ── user scripts / style sheets / message handlers ──
proc addUserScript*(w: WebView, source: string, inj: WebInjectionTime = witEnd, forMainFrameOnly = false): uint32 =
  when defined(linux):
    if not w.native.isNil: naWebViewAddUserScript(w.native, source.cstring, cint(ord(inj)), forMainFrameOnly) else: 0
  else: 0
proc addUserScriptWithWorld*(w: WebView, source: string, inj: WebInjectionTime, forMainFrameOnly: bool, world: string): uint32 =
  when defined(linux):
    if not w.native.isNil: naWebViewAddUserScriptWithWorld(w.native, source.cstring, cint(ord(inj)), forMainFrameOnly, world.cstring) else: 0
  else: 0
proc removeUserScript*(w: WebView, id: uint32) =
  when defined(linux):
    if not w.native.isNil: naWebViewRemoveUserScript(w.native, id)
proc removeAllUserScripts*(w: WebView) =
  when defined(linux):
    if not w.native.isNil: naWebViewRemoveAllUserScripts(w.native)
proc addUserStyleSheet*(w: WebView, source: string, forMainFrameOnly = false): uint32 =
  when defined(linux):
    if not w.native.isNil: naWebViewAddUserStyleSheet(w.native, source.cstring, forMainFrameOnly) else: 0
  else: 0
proc removeUserStyleSheet*(w: WebView, id: uint32) =
  when defined(linux):
    if not w.native.isNil: naWebViewRemoveUserStyleSheet(w.native, id)
proc removeAllUserStyleSheets*(w: WebView) =
  when defined(linux):
    if not w.native.isNil: naWebViewRemoveAllUserStyleSheets(w.native)
proc addScriptMessageHandler*(w: WebView, name: string) =
  when defined(linux):
    if not w.native.isNil: naWebViewAddScriptMessageHandler(w.native, name.cstring)
proc addScriptMessageHandlerWithReply*(w: WebView, name: string) =
  when defined(linux):
    if not w.native.isNil: naWebViewAddScriptMessageHandlerWithReply(w.native, name.cstring)
proc removeScriptMessageHandler*(w: WebView, name: string) =
  when defined(linux):
    if not w.native.isNil: naWebViewRemoveScriptMessageHandler(w.native, name.cstring)
proc removeAllScriptMessageHandlers*(w: WebView) =
  when defined(linux):
    if not w.native.isNil: naWebViewRemoveAllScriptMessageHandlers(w.native)

# ── JavaScript ──
proc evaluateJavaScript*(w: WebView, script: string, cb: proc(json: string, isError: bool)) =
  when defined(linux):
    if w.native.isNil: cb("null", true); return
    let req = nextJsReq; inc nextJsReq
    jsCallbacks[req] = cb
    naWebViewEvaluateJavaScript(w.native, script.cstring, req)
  else: cb("null", true)

proc evaluateJavaScriptWithWorld*(w: WebView, script, world: string, cb: proc(json: string, isError: bool)) =
  when defined(linux):
    if w.native.isNil: cb("null", true); return
    let req = nextJsReq; inc nextJsReq
    jsCallbacks[req] = cb
    naWebViewEvaluateJavaScriptWithWorld(w.native, script.cstring, world.cstring, req)
  else: cb("null", true)

proc callAsyncJavaScript*(w: WebView, script: string, argsJson = "[]", world = "", cb: proc(json: string, isError: bool)) =
  when defined(linux):
    if w.native.isNil: cb("null", true); return
    let req = nextJsReq; inc nextJsReq
    jsCallbacks[req] = cb
    naWebViewCallAsyncJavaScript(w.native, script.cstring, argsJson.cstring, world.cstring, req)
  else: cb("null", true)

# ── policy decision ──
proc decidePolicy*(w: WebView, decisionId: uint32, allow: bool) =
  when defined(linux):
    if not w.native.isNil: naWebViewDecidePolicy(w.native, decisionId, allow)

# ── custom schemes ──
proc registerUriScheme*(w: WebView, scheme: string) =
  when defined(linux):
    if not w.native.isNil: naWebViewRegisterUriScheme(w.native, scheme.cstring)
proc unregisterUriScheme*(w: WebView, scheme: string) =
  when defined(linux):
    if not w.native.isNil: naWebViewUnregisterUriScheme(w.native, scheme.cstring)
proc schemeFinish*(requestId: uint32, mimeType: string, data: string) =
  when defined(linux):
    naWebViewSchemeFinish(requestId, mimeType.cstring, data.cstring, cint(data.len))
proc schemeFinishWithHeaders*(requestId: uint32, mimeType: string, data: string, headersJson: string, statusCode: int) =
  when defined(linux):
    naWebViewSchemeFinishWithHeaders(requestId, mimeType.cstring, data.cstring, cint(data.len), headersJson.cstring, cint(statusCode))
proc schemeError*(requestId: uint32, msg: string) =
  when defined(linux):
    naWebViewSchemeError(requestId, msg.cstring)
proc schemeRedirect*(requestId: uint32, url: string) =
  when defined(linux):
    naWebViewSchemeRedirect(requestId, url.cstring)

# ── find / print / snapshot ──
proc findText*(w: WebView, text: string, caseSensitive = false, backwards = false, wrap = true): bool =
  when defined(linux):
    if not w.native.isNil: naWebViewFindText(w.native, text.cstring, caseSensitive, backwards, wrap) else: false
  else: false
proc findNext*(w: WebView, forward = true): bool =
  when defined(linux):
    if not w.native.isNil: naWebViewFindNext(w.native, forward) else: false
  else: false
proc hideFindHighlight*(w: WebView) =
  when defined(linux):
    if not w.native.isNil: naWebViewHideFindHighlight(w.native)
proc print*(w: WebView) =
  when defined(linux):
    if not w.native.isNil: naWebViewPrint(w.native)
proc printToPdf*(w: WebView, path: string, cb: proc(success: bool)) =
  when defined(linux):
    if w.native.isNil: cb(false); return
    let req = nextPdfReq; inc nextPdfReq
    pdfCallbacks[req] = cb
    naWebViewPrintToPdf(w.native, path.cstring, req)
  else: cb(false)
proc snapshot*(w: WebView, cb: proc(imageHandle: int64)) =
  when defined(linux):
    if w.native.isNil: cb(0); return
    let req = nextSnapReq; inc nextSnapReq
    snapCallbacks[req] = cb
    naWebViewSnapshot(w.native, req)
  else: cb(0)
proc snapshotRect*(w: WebView, x,y,wid,hei: float, cb: proc(imageHandle: int64)) =
  when defined(linux):
    if w.native.isNil: cb(0); return
    let req = nextSnapReq; inc nextSnapReq
    snapCallbacks[req] = cb
    naWebViewSnapshotRect(w.native, x,y,wid,hei, req)
  else: cb(0)

# ── listeners ──
proc onNavigation*(w: WebView, handler: proc(e: WebNavigationEvent)): ListenerId {.discardable.} =
  addListener[GuiEvent, WebNavigationEvent](w, handler)
proc onProgress*(w: WebView, handler: proc(e: WebProgressEvent)): ListenerId {.discardable.} =
  addListener[GuiEvent, WebProgressEvent](w, handler)
proc onMessage*(w: WebView, handler: proc(e: WebMessageEvent)): ListenerId {.discardable.} =
  addListener[GuiEvent, WebMessageEvent](w, handler)
proc onScheme*(w: WebView, handler: proc(e: WebSchemeEvent)): ListenerId {.discardable.} =
  addListener[GuiEvent, WebSchemeEvent](w, handler)
proc onTerminated*(w: WebView, handler: proc(e: WebTerminateEvent)): ListenerId {.discardable.} =
  addListener[GuiEvent, WebTerminateEvent](w, handler)
proc onDecidePolicy*(w: WebView, handler: proc(e: WebPolicyEvent)): ListenerId {.discardable.} =
  addListener[GuiEvent, WebPolicyEvent](w, handler)

proc fitSize*(w: WebView, win: Window = nil) =
  ## Make the WebView fill its window and keep it filled on resize.
  ## Call after creating the WebView and Window, e.g.:
  ##   let win = newWindow()
  ##   let browser = newWebView()
  ##   browser.fitSize(win)
  ## or without args it uses `mostRecentWindow()`:
  ##   browser.fitSize()
  ## The view is reparented to the window's content view and constrained to fill.
  let targetWin = if win.isNil: mostRecentWindow() else: win
  if targetWin.isNil or w.isNil: return
  when defined(linux) or defined(macosx) or defined(ios):
    let cvPtr = targetWin.contentView
    if not cvPtr.isNil:
      w.removeFromParent()
      naViewAddSubview(cvPtr, w.native)
      w.fillParent()
      let cs = targetWin.getContentSize()
      if cs.width > 0 and cs.height > 0:
        w.setFrameRect(rectangle(0, 0, cs.width, cs.height))
      else:
        let s = targetWin.getSize()
        if s.width > 0 and s.height > 0:
          w.setFrameRect(rectangle(0, 0, s.width, s.height))
    let wm = sharedWindowManager()
    discard wm.addListener(proc(e: WindowResizedEvent) =
      if e.windowId == targetWin.id:
        w.setFrameRect(rectangle(0, 0, e.newSize.width, e.newSize.height))
    )

proc fitBelowToolbarHeight*(w: WebView, toolbarHeight: float, win: Window = nil) =
  ## Create a container `calc(100vh - toolbarHeight)` and make WebView fill it.
  ## Container is `window.width x (window.height - toolbarHeight)` at y=0,
  ## toolbar is expected to be positioned by caller or via `fitBelowView`.
  let targetWin = if win.isNil: mostRecentWindow() else: win
  if targetWin.isNil or w.isNil: return
  when defined(linux) or defined(macosx) or defined(ios):
    let cvPtr = targetWin.contentView
    if cvPtr.isNil: return
    if w.fitContainer.isNil:
      w.fitContainer = newPlainView()
    w.fitContainer.removeFromParent()
    w.removeFromParent()
    naViewAddSubview(cvPtr, w.fitContainer.native)
    w.fitContainer.addSubview(w)
    w.fillParent()
    w.fitWindowId = targetWin.id
    proc update() =
      let cs = targetWin.getContentSize()
      var cw = cs.width
      var ch = cs.height
      if cw <= 0 or ch <= 0:
        let s = targetWin.getSize()
        cw = s.width; ch = s.height
      if cw <= 0 or ch <= 0: return
      let th = toolbarHeight
      let containerH = max(ch - th, 0.0)
      w.fitContainer.setFrameRect(rectangle(0, 0, cw, containerH))
      w.setFrameRect(rectangle(0, 0, cw, containerH))
    update()
    let wm = sharedWindowManager()
    discard wm.addListener(proc(e: WindowResizedEvent) =
      if e.windowId == targetWin.id:
        update()
    )

proc fitBelowView*(w: WebView, toolbarView: View, win: Window = nil) =
  ## Dynamic `calc(100vh - toolbarView.height)`: container fills window minus toolbar,
  ## WebView fills container 100%. Toolbar is reparented to window and kept at top.
  let targetWin = if win.isNil: mostRecentWindow() else: win
  if targetWin.isNil or w.isNil or toolbarView.isNil: return
  when defined(linux) or defined(macosx) or defined(ios):
    let cvPtr = targetWin.contentView
    if cvPtr.isNil: return
    if w.fitContainer.isNil:
      w.fitContainer = newPlainView()
    w.fitToolbar = toolbarView
    w.fitWindowId = targetWin.id
    # Reparent toolbar and container to window's content view
    toolbarView.removeFromParent()
    w.fitContainer.removeFromParent()
    w.removeFromParent()
    naViewAddSubview(cvPtr, w.fitContainer.native)
    naViewAddSubview(cvPtr, toolbarView.native)
    w.fitContainer.addSubview(w)
    w.fillParent()
    proc update() =
      let cs = targetWin.getContentSize()
      var cw = cs.width
      var ch = cs.height
      if cw <= 0 or ch <= 0:
        let s = targetWin.getSize()
        cw = s.width; ch = s.height
      if cw <= 0 or ch <= 0: return
      var th = toolbarView.getFrameRect().height
      if th <= 0.5:
        let ms = toolbarView.measure()
        th = ms.height
      if th <= 0.5:
        th = 50.0
      let containerH = max(ch - th, 0.0)
      # Container at bottom (y=0), toolbar at top (y=containerH)
      w.fitContainer.setFrameRect(rectangle(0, 0, cw, containerH))
      toolbarView.setFrameRect(rectangle(0, containerH, cw, th))
      w.setFrameRect(rectangle(0, 0, cw, containerH))
    update()
    let wm = sharedWindowManager()
    discard wm.addListener(proc(e: WindowResizedEvent) =
      if e.windowId == targetWin.id:
        update()
    )

# live count helper for tests
proc liveWebViewCount*(): int = liveWebViews.len
proc findWebView*(key: uint32): WebView = liveWebViews.getOrDefault(key)
