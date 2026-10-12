# Plan: Extensive macOS WebKit + Right-Click + Dock APIs

Preference lock-in: WebKit = all groups, Right-click = any `View`, Dock = full tile API, Platform = macOS-only (`when defined(macosx)` guards only).

## 1. Current state

* `src/nkit/gui/webview.nim` + `platform/macos/widgets/webview.m`: `WKWebView`, shared `WKProcessPool`, `WKNavigationDelegate`, `estimatedProgress` KVO, `WKScriptMessageHandler`. Events `0..5` (started/finished/failed/progress/message/jsResult) via `na_webview_*`, `fireTestEvent` hook. No `WKUIDelegate`, no policy delegate, no config beyond `javaScriptEnabled`, no history list, cookies, data-store, find/zoom/print/PDF/snapshot, user scripts, content rules.
* `src/nkit/menu.nim` + `widgets/menu.m`: full menu/item CRUD, accelerator, radio groups, `na_menu_popup(menu,x,y,placement)`, `cancelTracking`, `MenuOpened/Closed`, `MenuItemClicked` via single `cdecl` slot + `liveItems/liveMenus`. No `NSView.menu` attachment, no automatic right-click.
* `src/nkit/gui/view.nim` + `widgets/view.m`: `NAPlainView` subclass only for plain views (drop + frame callback). No `setContextMenu`.
* `src/nkit/application.nim` + `widgets/app.m`: `g_dock_menu_id` + `applicationDockMenu:` delegate, `setDockMenu/clearDockMenu/getDockMenuKey`, `setIcon/setDockIconVisible`. No badge, `requestUserAttention`, progress, reopen event, `getDockMenu(): Menu`.
* House convention: `widgets/*.m` shim + `{.importc.}` in `nsfunctions.nim` + Nim wrapper + `cdecl` trampoline + umbrella export in `src/nkit.nim` + `tests/test_*.nim` via `fire`/direct trampoline + `examples/`.

## 2. Architecture

```
widgets/webview_ex.m (or extend webview.m) -> nsfunctions.nim na_webview_*
  -> gui/webview.nim (+ new gui/webview_ex.nim if file gets >600 lines)
widgets/view.m (+ webview.m special-case)   -> na_view_set_context_menu_*
  -> gui/view.nim + window.nim
widgets/dock.m (new, extracted from app.m)  -> na_dock_*
  -> new dock.nim (re-exported from nkit.nim, application.nim keeps compat forwards)
```

All new Nim procs `when defined(macosx)` only. Cross-platform callers must guard with `when defined(macosx)`. `nkit.nim` still imports on Linux/iOS because the new module compiles to an empty shell there (type decls only, procs behind `when defined(macosx)`).

## 3. Workstream A: WebKit extensive

### A1. Config + creation (S)

Keep `newWebView(javaScriptEnabled)` compatible. Add `WebViewOptions` (javaScriptEnabled, persistentStore, userAgent, applicationNameForUserAgent, backForwardGestures, magnifiersAllowed), `newWebViewEx`, `setUserAgent/getUserAgent`, `setApplicationNameForUserAgent`, `setBackForwardGestures`, `setMagnification/getMagnification`, `setPageZoom/getPageZoom`. Shim `na_webview_create_ex`, `na_webview_set_user_agent/get`, `na_webview_set_page_zoom/get`, `na_webview_set_backforward_gestures`. Private store chosen at `WKWebViewConfiguration` creation time.

### A2. Navigation + history + policy (M)

`reloadFromOrigin`, `loadFileUrl(path, readAccessDir)`, `loadData(data, mime, encoding, baseUrl)`, `WebHistoryItem`, `getBackList/getForwardList`, `goToHistoryIndex`, `NavigationType`, `WebViewNavigationEvent(url, navType, decisionId)`, `onNavigationRequested`, `allowNavigation/cancelNavigation`, `setNavigationPolicyMode(npAllowAll/npAsk/npBlockExternal)`. Shim stores `decisionHandler` blocks by id, emits event 6, Nim replies via `na_webview_decide_navigation`.

### A3. JS bridge++ (S)

`removeMessageHandler/removeAllMessageHandlers`, `addUserScript(source, atDocumentEnd, mainFrameOnly)/removeAllUserScripts`, `addContentRule(json, identifier)/removeAllContentRules`.

### A4. Page tools (M)

`findInPage/hideFindUI`, `printPage`, `createPdf(requestId) -> WebViewPdfEvent`, `takeSnapshot(requestId) -> WebViewSnapshotEvent`, `onPdfResult/onSnapshotResult`. Native `@available(macOS 12/13)` with JS fallback documented.

### A5. Privacy + data (M)

`getAllCookies(requestId) -> WebViewCookiesEvent(json)`, `setCookie/deleteCookie`, `clearWebsiteData/clearAllWebsiteData`, `onCookiesResult`.

### A6. UI dialogs + new windows + fullscreen (M)

`WKUIDelegate`: `WebViewAlert/Confirm/Prompt/NewWindow/Fullscreen` events + `completeAlert/completeConfirm/completePrompt`. `createWebViewWithConfiguration` emits newWindow and returns nil.

Event-kind extension: 6 navigationRequested, 7 pdfResult, 8 snapshotResult, 9 cookiesResult, 10 jsAlert, 11 jsConfirm, 12 jsPrompt, 13 newWindow, 14 fullscreenChanged.

Sugar: `webviewEx`, `webviewWithRules`, `onNavigation/onPdf/onSnapshot/onCookies/onJsAlert/...` for `ViewNode`.

## 4. Workstream B: Right-click context menu on any View

`NSView.menu` binding: `na_view_set_context_menu(viewPtr, menu_id)`, `na_view_get_context_menu`, `na_view_open_context_menu(viewPtr, x, y)` backed by `NSMapTable viewPtr -> menuId`. Nim: `View.setContextMenu/getContextMenu/clearContextMenu/openContextMenu`, `Window.setContextMenu/getContextMenu`. Dynamic updates via existing `MenuOpenedEvent`. WebView special case: `setDefaultWebContextMenuEnabled` + suppressed-mode custom `Menu`; full native+custom merge is phase 2. Lifetime: `na_menu_free` clears referencing views.

## 5. Workstream C: Dock full tile API

New `widgets/dock.m` + `src/nkit/dock.nim`. Shims: `na_dock_set_badge/get_badge`, `na_dock_request_attention/cancel_attention`, `na_dock_set_progress/clear_progress`, `na_dock_display`. Badge via `dockTile.badgeLabel`, attention via `requestUserAttention`, progress via lazily-created `NSProgressIndicator` overlay in `dockTile.contentView`. Nim: `DockAttention`, `getDockMenu/refreshDockMenu`, `setDockBadge/getDockBadge/clearDockBadge`, `requestDockAttention/cancelDockAttention`, `setDockProgress/setDockProgressIndeterminate/clearDockProgress`, `ApplicationDockReopenEvent` via `applicationShouldHandleReopen`. Menu CRUD reused from `menu.nim`.

## 6. Files to touch

Extend: `widgets/webview.m`, `view.m`, `app.m`, `nsfunctions.nim`, `gui/webview.nim`, `gui/view.nim`, `window.nim`, `menu.nim`, `application.nim`, `gui/sugar.nim`, `src/nkit.nim`. New: `widgets/dock.m`, `src/nkit/dock.nim`, `tests/test_dock.nim`, `tests/test_context_menu.nim`, extend `tests/test_webview.nim`, `examples/webview_ex_demo.nim`, `examples/context_dock_demo.nim`. Add `{.compile: "widgets/dock.m".}`.

## 7. Tests + demos (headless-safe)

`test_webview.nim` extensions, new `test_context_menu.nim` (set/get/clear, identity, open callable, free detaches, WebView suppress flag), new `test_dock.nim` (badge, attention, progress, getDockMenu identity, click routing, reopen via trampoline). Demos: `webview_ex_demo`, `context_dock_demo`.

## 8. Build order + risks

1. View context-menu bind + Dock extract (S).
2. WebKit config/navigation/policy + UIDelegate alerts (M).
3. Cookies/data-store + PDF/snapshot (M, copy cstrings synchronously).
4. Find/zoom/print + WebView menu suppression + progress overlay (S/M, @available checks).
5. Sugar + docs + demos + tests.

Risks: completion blocks called exactly once on main thread (timeout auto-allow + log); content-rule store async; dock overlay vs app icon; macOS-only guards require call-site `when defined(macosx)`.
