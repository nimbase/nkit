#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "gui_common.h"

// Event kinds delivered to na_webview_set_event_callback. Must stay in
// sync with src/nkit/gui/webview.nim.
#define NA_WEBVIEW_STARTED 0
#define NA_WEBVIEW_FINISHED 1
#define NA_WEBVIEW_FAILED 2
#define NA_WEBVIEW_PROGRESS 3
#define NA_WEBVIEW_MESSAGE 4
#define NA_WEBVIEW_JS_RESULT 5
#define NA_WEBVIEW_NAV_REQUESTED 6
#define NA_WEBVIEW_PDF_RESULT 7
#define NA_WEBVIEW_SNAPSHOT_RESULT 8
#define NA_WEBVIEW_COOKIES_RESULT 9
#define NA_WEBVIEW_JS_ALERT 10
#define NA_WEBVIEW_JS_CONFIRM 11
#define NA_WEBVIEW_JS_PROMPT 12
#define NA_WEBVIEW_NEW_WINDOW 13
#define NA_WEBVIEW_FULLSCREEN 14

// Navigation policy modes (mirrors Nim NavPolicy).
#define NA_NAV_ALLOW_ALL 0
#define NA_NAV_ASK 1
#define NA_NAV_BLOCK_EXTERNAL 2

typedef void (*na_webview_event_fn)(uint32_t widget_id, int kind,
                                    const char* arg1, const char* arg2,
                                    double num, uint64_t num2, void* ctx);

static na_webview_event_fn g_webview_fn = NULL;
static void* g_webview_ctx = NULL;

void na_webview_set_event_callback(na_webview_event_fn fn, void* ctx) {
  g_webview_fn = fn;
  g_webview_ctx = ctx;
}

// Dedicated getter buffers: the shared g_gui_text_buffer (2KB) is too
// small for URLs and page titles.
static char g_webview_url_buffer[8192];
static char g_webview_title_buffer[8192];

static const char* webview_copy_static(NSString* value, char* buf, size_t cap) {
  buf[0] = '\0';
  if (!value) {
    return buf;
  }
  const char* utf8 = value.UTF8String;
  if (utf8) {
    strncpy(buf, utf8, cap - 1);
    buf[cap - 1] = '\0';
  }
  return buf;
}

static void webview_emit(uint32_t widget_id, int kind, NSString* arg1,
                         NSString* arg2, double num, uint64_t num2) {
  if (!g_webview_fn) {
    return;
  }
  g_webview_fn(widget_id, kind, arg1 ? arg1.UTF8String : NULL,
               arg2 ? arg2.UTF8String : NULL, num, num2, g_webview_ctx);
}

// Serializes a JS evaluation result or script-message body to text.
static NSString* webview_stringify(id value) {
  if (!value || value == (id)[NSNull null]) {
    return @"";
  }
  if ([value isKindOfClass:[NSString class]]) {
    return (NSString*)value;
  }
  if ([value isKindOfClass:[NSNumber class]]) {
    return [(NSNumber*)value stringValue];
  }
  if ([NSJSONSerialization isValidJSONObject:value]) {
    NSError* err = nil;
    NSData* data = [NSJSONSerialization dataWithJSONObject:value
                                                   options:0
                                                     error:&err];
    if (data) {
      return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
  }
  return [value description] ?: @"";
}

@interface NAWebView : WKWebView <WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate>
@property(nonatomic, assign) uint32_t widgetId;
@property(nonatomic, strong) NSMutableSet<NSString*>* handlerNames;
@property(nonatomic, assign) int navPolicyMode;
@property(nonatomic, assign) BOOL webContextMenuEnabled;
@end

@implementation NAWebView

- (void)observeValueForKeyPath:(NSString*)keyPath
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context {
  if ([keyPath isEqualToString:@"estimatedProgress"]) {
    webview_emit(_widgetId, NA_WEBVIEW_PROGRESS, nil, nil,
                 ((WKWebView*)object).estimatedProgress, 0);
    return;
  }
  [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

// --- WKNavigationDelegate (allow-all: no policy delegate, everything
// stays in this view) ---

- (void)webView:(WKWebView*)webView didStartProvisionalNavigation:(WKNavigation*)navigation {
  (void)navigation;
  webview_emit(_widgetId, NA_WEBVIEW_STARTED, webView.URL.absoluteString, nil, 0, 0);
}

- (void)webView:(WKWebView*)webView didFinishNavigation:(WKNavigation*)navigation {
  (void)navigation;
  webview_emit(_widgetId, NA_WEBVIEW_FINISHED, webView.URL.absoluteString, nil,
               webView.estimatedProgress, 0);
}

- (void)webView:(WKWebView*)webView didFailNavigation:(WKNavigation*)navigation withError:(NSError*)error {
  (void)navigation;
  webview_emit(_widgetId, NA_WEBVIEW_FAILED, webView.URL.absoluteString,
               error.localizedDescription, 0, 0);
}

- (void)webView:(WKWebView*)webView didFailProvisionalNavigation:(WKNavigation*)navigation withError:(NSError*)error {
  (void)navigation;
  webview_emit(_widgetId, NA_WEBVIEW_FAILED, webView.URL.absoluteString,
               error.localizedDescription, 0, 0);
}

// --- WKScriptMessageHandler (JS -> native) ---

- (void)userContentController:(WKUserContentController*)controller
      didReceiveScriptMessage:(WKScriptMessage*)message {
  (void)controller;
  webview_emit(_widgetId, NA_WEBVIEW_MESSAGE, message.name,
               webview_stringify(message.body), 0, 0);
}

static NSMutableDictionary<NSNumber*, id>* g_nav_decisions = nil;
static NSMutableDictionary<NSNumber*, id>* g_alert_completions = nil;
static NSMutableDictionary<NSNumber*, NSNumber*>* g_nav_owners = nil;
static NSMutableDictionary<NSNumber*, NSNumber*>* g_alert_owners = nil;
static uint64_t g_next_decision_id = 0;
static uint64_t g_next_completion_id = 0;

static void ensure_pending_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_nav_decisions = [NSMutableDictionary dictionary];
    g_alert_completions = [NSMutableDictionary dictionary];
    g_nav_owners = [NSMutableDictionary dictionary];
    g_alert_owners = [NSMutableDictionary dictionary];
  }
}

static void webview_drop_pending_for_widget(uint32_t widget_id) {
  ensure_pending_tables();
  NSMutableArray<NSNumber*>* navDoomed = [NSMutableArray array];
  for (NSNumber* key in g_nav_owners) {
    if ([g_nav_owners[key] unsignedIntValue] == widget_id) {
      void (^handler)(WKNavigationActionPolicy) = g_nav_decisions[key];
      if (handler) {
        handler(WKNavigationActionPolicyCancel);
      }
      [navDoomed addObject:key];
    }
  }
  [g_nav_decisions removeObjectsForKeys:navDoomed];
  [g_nav_owners removeObjectsForKeys:navDoomed];
  NSMutableArray<NSNumber*>* alertDoomed = [NSMutableArray array];
  for (NSNumber* key in g_alert_owners) {
    if ([g_alert_owners[key] unsignedIntValue] == widget_id) {
      [alertDoomed addObject:key];
    }
  }
  [g_alert_completions removeObjectsForKeys:alertDoomed];
  [g_alert_owners removeObjectsForKeys:alertDoomed];
}

static NSString* nav_type_string(WKNavigationType t) {
  switch (t) {
    case WKNavigationTypeLinkActivated: return @"link";
    case WKNavigationTypeFormSubmitted: return @"formSubmit";
    case WKNavigationTypeBackForward: return @"backForward";
    case WKNavigationTypeReload: return @"reload";
    case WKNavigationTypeFormResubmitted: return @"formResubmit";
    default: return @"other";
  }
}

// --- WKNavigationDelegate policy (ask / block-external / allow-all) ---

- (void)webView:(WKWebView*)webView
    decidePolicyForNavigationAction:(WKNavigationAction*)action
                    decisionHandler:
                        (void (^)(WKNavigationActionPolicy))decisionHandler {
  int mode = _navPolicyMode;
  if (mode == NA_NAV_ALLOW_ALL) {
    decisionHandler(WKNavigationActionPolicyAllow);
    return;
  }
  NSURL* url = action.request.URL;
  NSString* scheme = url.scheme.lowercaseString ?: @"";
  BOOL isHttp = [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
  if (mode == NA_NAV_BLOCK_EXTERNAL) {
    // New-window targets and non-http(s) schemes are treated as external.
    if ((action.targetFrame == nil && action.navigationType == WKNavigationTypeLinkActivated) ||
        (!isHttp && url != nil)) {
      webview_emit(_widgetId, NA_WEBVIEW_NAV_REQUESTED,
                   url.absoluteString ?: @"", @"blocked-external", 0, 0);
      decisionHandler(WKNavigationActionPolicyCancel);
      return;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
    return;
  }
  // NA_NAV_ASK: hand the decision to Nim, auto-allow after 5s so a
  // missing reply cannot hang the page.
  ensure_pending_tables();
  g_next_decision_id += 1;
  uint64_t did = g_next_decision_id;
  uint32_t wid = ((NAWebView*)webView).widgetId;
  g_nav_decisions[@(did)] = [decisionHandler copy];
  g_nav_owners[@(did)] = @(wid);
  webview_emit(_widgetId, NA_WEBVIEW_NAV_REQUESTED,
               url.absoluteString ?: @"", nav_type_string(action.navigationType),
               0, did);
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)5 * NSEC_PER_SEC),
                 dispatch_get_main_queue(), ^{
                   void (^pending)(WKNavigationActionPolicy) =
                       g_nav_decisions[@(did)];
                   if (pending) {
                     [g_nav_decisions removeObjectForKey:@(did)];
                     [g_nav_owners removeObjectForKey:@(did)];
                     NSLog(@"nkit webview: navigation decision %llu timed out, allowing",
                           did);
                     pending(WKNavigationActionPolicyAllow);
                   }
                 });
}

// --- WKUIDelegate: JS dialogs + new windows ---

- (void)webView:(WKWebView*)webView
    runJavaScriptAlertPanelWithMessage:(NSString*)message
                     initiatedByFrame:(WKFrameInfo*)frame
                    completionHandler:(void (^)(void))completionHandler {
  (void)webView;
  (void)frame;
  ensure_pending_tables();
  g_next_completion_id += 1;
  uint64_t cid = g_next_completion_id;
  g_alert_completions[@(cid)] = [completionHandler copy];
  g_alert_owners[@(cid)] = @(_widgetId);
  webview_emit(_widgetId, NA_WEBVIEW_JS_ALERT, message ?: @"", nil, 0, cid);
}

- (void)webView:(WKWebView*)webView
    runJavaScriptConfirmPanelWithMessage:(NSString*)message
                        initiatedByFrame:(WKFrameInfo*)frame
                       completionHandler:(void (^)(BOOL))completionHandler {
  (void)webView;
  (void)frame;
  ensure_pending_tables();
  g_next_completion_id += 1;
  uint64_t cid = g_next_completion_id;
  g_alert_completions[@(cid)] = [completionHandler copy];
  g_alert_owners[@(cid)] = @(_widgetId);
  webview_emit(_widgetId, NA_WEBVIEW_JS_CONFIRM, message ?: @"", nil, 0, cid);
}

- (void)webView:(WKWebView*)webView
    runJavaScriptTextInputPanelWithPrompt:(NSString*)prompt
                             defaultText:(NSString*)defaultText
                        initiatedByFrame:(WKFrameInfo*)frame
                       completionHandler:(void (^)(NSString*))completionHandler {
  (void)webView;
  (void)frame;
  ensure_pending_tables();
  g_next_completion_id += 1;
  uint64_t cid = g_next_completion_id;
  g_alert_completions[@(cid)] = [completionHandler copy];
  g_alert_owners[@(cid)] = @(_widgetId);
  webview_emit(_widgetId, NA_WEBVIEW_JS_PROMPT, prompt ?: @"",
               defaultText ?: @"", 0, cid);
}

- (WKWebView*)webView:(WKWebView*)webView
    createWebViewWithConfiguration:(WKWebViewConfiguration*)configuration
               forNavigationAction:(WKNavigationAction*)action
                    windowFeatures:(WKWindowFeatures*)windowFeatures {
  (void)webView;
  (void)configuration;
  (void)windowFeatures;
  webview_emit(_widgetId, NA_WEBVIEW_NEW_WINDOW,
               action.request.URL.absoluteString ?: @"",
               nav_type_string(action.navigationType), 0, 0);
  return nil;
}

- (void)webViewDidClose:(WKWebView*)webView {
  (void)webView;
}

// Right-click: when the default web menu is disabled, show the attached
// NSView.menu (set via na_view_set_context_menu) or swallow the click.
// When enabled, defer to WKWebView so the standard web menu appears.
- (void)rightMouseDown:(NSEvent*)event {
  if (_webContextMenuEnabled) {
    [super rightMouseDown:event];
    return;
  }
  NSMenu* menu = self.menu;
  if (menu) {
    [NSMenu popUpContextMenu:menu withEvent:event forView:self];
  }
}

@end

static NSMutableDictionary<NSNumber*, NAWebView*>* g_webviews = nil;
static WKProcessPool* g_webview_pool = nil;

static void ensure_webview_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_webviews = [NSMutableDictionary dictionary];
    g_webview_pool = [[WKProcessPool alloc] init];
  }
}

void* na_webview_create(uint32_t widget_id, bool java_script_enabled) {
  ensure_webview_tables();
  WKWebViewConfiguration* config = [[WKWebViewConfiguration alloc] init];
  // Share one process pool so cookies / storage persist across webviews.
  config.processPool = g_webview_pool;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  config.preferences.javaScriptEnabled = java_script_enabled ? YES : NO;
#pragma clang diagnostic pop
  if (@available(macOS 10.15, *)) {
    config.defaultWebpagePreferences.allowsContentJavaScript =
        java_script_enabled ? YES : NO;
  }
  NAWebView* web = [[NAWebView alloc] initWithFrame:NSMakeRect(0, 0, 400, 300)
                                      configuration:config];
  web.widgetId = widget_id;
  web.handlerNames = [NSMutableSet set];
  web.navPolicyMode = NA_NAV_ALLOW_ALL;
  web.webContextMenuEnabled = YES;
  web.navigationDelegate = web;
  web.UIDelegate = web;
  [web addObserver:web forKeyPath:@"estimatedProgress"
           options:NSKeyValueObservingOptionNew context:NULL];
  g_webviews[@(widget_id)] = web;
  na_gui_register_view(web);
  return (__bridge void*)web;
}

void na_webview_free(uint32_t widget_id, void* ptr) {
  ensure_webview_tables();
  webview_drop_pending_for_widget(widget_id);
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (web) {
    [web stopLoading];
    @try {
      [web removeObserver:web forKeyPath:@"estimatedProgress"];
    } @catch (NSException* e) {
      (void)e;
    }
    for (NSString* name in [web.handlerNames copy]) {
      [web.configuration.userContentController
          removeScriptMessageHandlerForName:name];
    }
    [web.handlerNames removeAllObjects];
    web.navigationDelegate = nil;
    web.UIDelegate = nil;
    [web removeFromSuperview];
    na_gui_unregister_view(web);
  }
  [g_webviews removeObjectForKey:@(widget_id)];
}

void na_webview_load_url(void* ptr, const char* url) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web || !url) {
    return;
  }
  NSString* s = [NSString stringWithUTF8String:url];
  NSURL* nsurl = [NSURL URLWithString:s];
  if (nsurl) {
    [web loadRequest:[NSURLRequest requestWithURL:nsurl]];
  }
}

void na_webview_load_html(void* ptr, const char* html, const char* base_url) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web || !html) {
    return;
  }
  NSString* s = [NSString stringWithUTF8String:html];
  NSURL* base = NULL;
  if (base_url && base_url[0] != '\0') {
    base = [NSURL URLWithString:[NSString stringWithUTF8String:base_url]];
  }
  [web loadHTMLString:s baseURL:base];
}

void na_webview_reload(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (web) {
    [web reload];
  }
}

void na_webview_stop(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (web) {
    [web stopLoading];
  }
}

void na_webview_go_back(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (web && web.canGoBack) {
    [web goBack];
  }
}

void na_webview_go_forward(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (web && web.canGoForward) {
    [web goForward];
  }
}

bool na_webview_can_go_back(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  return web && web.canGoBack;
}

bool na_webview_can_go_forward(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  return web && web.canGoForward;
}

const char* na_webview_get_url(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  return webview_copy_static(web ? web.URL.absoluteString : nil,
                             g_webview_url_buffer,
                             sizeof(g_webview_url_buffer));
}

const char* na_webview_get_title(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  return webview_copy_static(web ? web.title : nil, g_webview_title_buffer,
                             sizeof(g_webview_title_buffer));
}

double na_webview_get_progress(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  return web ? web.estimatedProgress : 0.0;
}

bool na_webview_is_loading(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  return web && web.loading == YES;
}

void na_webview_evaluate_js(void* ptr, const char* script, uint64_t request_id) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web || !script) {
    return;
  }
  uint32_t wid = web.widgetId;
  NSString* js = [NSString stringWithUTF8String:script];
  __weak NAWebView* weakWeb = web;
  [web evaluateJavaScript:js
       completionHandler:^(id result, NSError* error) {
         __strong NAWebView* strongWeb = weakWeb;
         (void)strongWeb;
         // Drop late completions for destroyed views.
         if (!g_webviews[@(wid)]) {
           return;
         }
         if (error) {
           webview_emit(wid, NA_WEBVIEW_JS_RESULT, error.localizedDescription,
                        nil, 1, request_id);
         } else {
           webview_emit(wid, NA_WEBVIEW_JS_RESULT, webview_stringify(result),
                        nil, 0, request_id);
         }
       }];
}

void na_webview_add_message_handler(void* ptr, const char* name) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web) {
    return;
  }
  NSString* n = (name && name[0] != '\0')
      ? [NSString stringWithUTF8String:name]
      : @"nkit";
  if (![web.handlerNames containsObject:n]) {
    [web.handlerNames addObject:n];
    [web.configuration.userContentController addScriptMessageHandler:web
                                                                 name:n];
  }
}

void na_webview_remove_message_handler(void* ptr, const char* name) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web || !name || name[0] == '\0') {
    return;
  }
  NSString* n = [NSString stringWithUTF8String:name];
  if ([web.handlerNames containsObject:n]) {
    [web.handlerNames removeObject:n];
    [web.configuration.userContentController
        removeScriptMessageHandlerForName:n];
  }
}

void na_webview_remove_all_message_handlers(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web) {
    return;
  }
  for (NSString* n in [web.handlerNames copy]) {
    [web.configuration.userContentController
        removeScriptMessageHandlerForName:n];
  }
  [web.handlerNames removeAllObjects];
}

void na_webview_add_user_script(void* ptr, const char* source, bool at_end,
                                bool main_frame_only) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web || !source) {
    return;
  }
  NSString* js = [NSString stringWithUTF8String:source];
  WKUserScriptInjectionTime when = at_end ? WKUserScriptInjectionTimeAtDocumentEnd
                                          : WKUserScriptInjectionTimeAtDocumentStart;
  WKUserScript* script = [[WKUserScript alloc] initWithSource:js
                                                injectionTime:when
                                             forMainFrameOnly:(main_frame_only ? YES : NO)];
  [web.configuration.userContentController addUserScript:script];
}

void na_webview_remove_all_user_scripts(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (web) {
    [web.configuration.userContentController removeAllUserScripts];
  }
}

void na_webview_add_content_rule(void* ptr, const char* json, const char* identifier) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web || !json || !identifier) {
    return;
  }
  NSString* rules = [NSString stringWithUTF8String:json];
  NSString* ident = [NSString stringWithUTF8String:identifier];
  [[WKContentRuleListStore defaultStore]
      compileContentRuleListForIdentifier:ident
                 encodedContentRuleList:rules
                      completionHandler:^(WKContentRuleList* list, NSError* error) {
                        if (error || !list) {
                          NSLog(@"nkit webview: content rule compile failed: %@",
                                error.localizedDescription);
                          return;
                        }
                        [web.configuration.userContentController
                            addContentRuleList:list];
                      }];
}

void na_webview_remove_all_content_rules(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (web) {
    [web.configuration.userContentController removeAllContentRuleLists];
  }
}

// --- Extended creation (persistent store + user agent) ---

void* na_webview_create_ex(uint32_t widget_id, bool java_script_enabled,
                           bool persistent, const char* user_agent,
                           const char* app_name) {
  ensure_webview_tables();
  WKWebViewConfiguration* config = [[WKWebViewConfiguration alloc] init];
  if (persistent) {
    config.processPool = g_webview_pool;
  } else {
    if (@available(macOS 10.13, *)) {
      config.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];
    }
    config.processPool = [[WKProcessPool alloc] init];
  }
  if (app_name && app_name[0] != '\0') {
    config.applicationNameForUserAgent =
        [NSString stringWithUTF8String:app_name];
  }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  config.preferences.javaScriptEnabled = java_script_enabled ? YES : NO;
#pragma clang diagnostic pop
  if (@available(macOS 10.15, *)) {
    config.defaultWebpagePreferences.allowsContentJavaScript =
        java_script_enabled ? YES : NO;
  }
  NAWebView* web = [[NAWebView alloc] initWithFrame:NSMakeRect(0, 0, 400, 300)
                                      configuration:config];
  web.widgetId = widget_id;
  web.handlerNames = [NSMutableSet set];
  web.navPolicyMode = NA_NAV_ALLOW_ALL;
  web.webContextMenuEnabled = YES;
  web.navigationDelegate = web;
  web.UIDelegate = web;
  if (user_agent && user_agent[0] != '\0') {
    web.customUserAgent = [NSString stringWithUTF8String:user_agent];
  }
  [web addObserver:web forKeyPath:@"estimatedProgress"
           options:NSKeyValueObservingOptionNew context:NULL];
  g_webviews[@(widget_id)] = web;
  na_gui_register_view(web);
  return (__bridge void*)web;
}

// --- Config getters/setters ---

static char g_webview_ua_buffer[4096];

void na_webview_set_user_agent(void* ptr, const char* user_agent) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web) {
    return;
  }
  if (!user_agent || user_agent[0] == '\0') {
    web.customUserAgent = nil;
  } else {
    web.customUserAgent = [NSString stringWithUTF8String:user_agent];
  }
}

const char* na_webview_get_user_agent(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  return webview_copy_static(web ? web.customUserAgent : nil,
                             g_webview_ua_buffer, sizeof(g_webview_ua_buffer));
}

void na_webview_set_backforward_gestures(void* ptr, bool enabled) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (web) {
    web.allowsBackForwardNavigationGestures = enabled ? YES : NO;
  }
}

bool na_webview_get_backforward_gestures(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  return web && web.allowsBackForwardNavigationGestures == YES;
}

void na_webview_set_magnification(void* ptr, double m, double cx, double cy) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (web && web.allowsMagnification) {
    [web setMagnification:(CGFloat)m centeredAtPoint:NSMakePoint(cx, cy)];
  }
}

double na_webview_get_magnification(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  return web ? (double)web.magnification : 1.0;
}

void na_webview_set_allows_magnification(void* ptr, bool allowed) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (web) {
    web.allowsMagnification = allowed ? YES : NO;
  }
}

void na_webview_set_page_zoom(void* ptr, double zoom) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web) {
    return;
  }
  if (@available(macOS 11.0, *)) {
    web.pageZoom = (CGFloat)zoom;
  }
}

double na_webview_get_page_zoom(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (web && @available(macOS 11.0, *)) {
    return (double)web.pageZoom;
  }
  return 1.0;
}

// --- Navigation extras ---

void na_webview_reload_from_origin(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (web) {
    [web reloadFromOrigin];
  }
}

void na_webview_load_file_url(void* ptr, const char* path, const char* read_access) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web || !path) {
    return;
  }
  NSURL* file = [NSURL fileURLWithPath:[NSString stringWithUTF8String:path]];
  NSURL* access = (read_access && read_access[0] != '\0')
      ? [NSURL fileURLWithPath:[NSString stringWithUTF8String:read_access]]
      : file;
  if (file && access) {
    [web loadFileURL:file allowingReadAccessToURL:access];
  }
}

void na_webview_load_data(void* ptr, const char* data, const char* mime,
                          const char* encoding, const char* base_url) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web || !data) {
    return;
  }
  NSData* bytes = [[NSString stringWithUTF8String:data]
      dataUsingEncoding:NSUTF8StringEncoding];
  NSString* mimeType =
      (mime && mime[0] != '\0') ? [NSString stringWithUTF8String:mime] : @"text/html";
  NSString* enc =
      (encoding && encoding[0] != '\0') ? [NSString stringWithUTF8String:encoding]
                                        : @"utf-8";
  NSURL* base = (base_url && base_url[0] != '\0')
      ? [NSURL URLWithString:[NSString stringWithUTF8String:base_url]]
      : [NSURL URLWithString:@"about:blank"];
  [web loadData:bytes MIMEType:mimeType characterEncodingName:enc baseURL:base];
}

static char g_history_url_buffer[8192];
static char g_history_title_buffer[8192];

int na_webview_back_count(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  return web ? (int)web.backForwardList.backList.count : 0;
}

int na_webview_forward_count(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  return web ? (int)web.backForwardList.forwardList.count : 0;
}

const char* na_webview_history_url(void* ptr, bool forward, int index) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  g_history_url_buffer[0] = '\0';
  if (!web) {
    return g_history_url_buffer;
  }
  NSArray<WKBackForwardListItem*>* list =
      forward ? web.backForwardList.forwardList : web.backForwardList.backList;
  if (index < 0 || index >= (int)list.count) {
    return g_history_url_buffer;
  }
  return webview_copy_static(list[index].URL.absoluteString,
                             g_history_url_buffer, sizeof(g_history_url_buffer));
}

const char* na_webview_history_title(void* ptr, bool forward, int index) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  g_history_title_buffer[0] = '\0';
  if (!web) {
    return g_history_title_buffer;
  }
  NSArray<WKBackForwardListItem*>* list =
      forward ? web.backForwardList.forwardList : web.backForwardList.backList;
  if (index < 0 || index >= (int)list.count) {
    return g_history_title_buffer;
  }
  return webview_copy_static(list[index].title,
                             g_history_title_buffer,
                             sizeof(g_history_title_buffer));
}

bool na_webview_go_to_offset(void* ptr, int offset) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web || offset == 0) {
    return false;
  }
  WKBackForwardListItem* item = [web.backForwardList itemAtIndex:offset];
  if (!item) {
    return false;
  }
  [web goToBackForwardListItem:item];
  return true;
}

void na_webview_set_policy_mode(void* ptr, int mode) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (web) {
    web.navPolicyMode = mode;
  }
}

int na_webview_get_policy_mode(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  return web ? web.navPolicyMode : NA_NAV_ALLOW_ALL;
}

void na_webview_decide_navigation(uint64_t decision_id, bool allow) {
  ensure_pending_tables();
  void (^handler)(WKNavigationActionPolicy) = g_nav_decisions[@(decision_id)];
  if (!handler) {
    return;
  }
  [g_nav_decisions removeObjectForKey:@(decision_id)];
  [g_nav_owners removeObjectForKey:@(decision_id)];
  handler(allow ? WKNavigationActionPolicyAllow : WKNavigationActionPolicyCancel);
}

// --- UIDelegate completions ---

void na_webview_complete_alert(uint64_t completion_id) {
  ensure_pending_tables();
  void (^handler)(void) = g_alert_completions[@(completion_id)];
  if (!handler) {
    return;
  }
  [g_alert_completions removeObjectForKey:@(completion_id)];
  [g_alert_owners removeObjectForKey:@(completion_id)];
  handler();
}

void na_webview_complete_confirm(uint64_t completion_id, bool confirmed) {
  ensure_pending_tables();
  void (^handler)(BOOL) = g_alert_completions[@(completion_id)];
  if (!handler) {
    return;
  }
  [g_alert_completions removeObjectForKey:@(completion_id)];
  [g_alert_owners removeObjectForKey:@(completion_id)];
  handler(confirmed ? YES : NO);
}

void na_webview_complete_prompt(uint64_t completion_id, const char* text,
                                bool cancelled) {
  ensure_pending_tables();
  void (^handler)(NSString*) = g_alert_completions[@(completion_id)];
  if (!handler) {
    return;
  }
  [g_alert_completions removeObjectForKey:@(completion_id)];
  [g_alert_owners removeObjectForKey:@(completion_id)];
  if (cancelled) {
    handler(nil);
  } else {
    handler((text && text[0] != '\0') ? [NSString stringWithUTF8String:text] : @"");
  }
}

// --- PDF export (async -> event 7) ---

void na_webview_create_pdf(void* ptr, uint64_t request_id) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web) {
    return;
  }
  uint32_t wid = web.widgetId;
  void (^done)(NSData*, NSError*) = ^(NSData* data, NSError* error) {
    if (!g_webviews[@(wid)]) {
      return;
    }
    if (error || !data) {
      webview_emit(wid, NA_WEBVIEW_PDF_RESULT, @"",
                   error ? error.localizedDescription : @"failed", 1,
                   request_id);
      return;
    }
    NSString* tmp = [NSString stringWithFormat:@"%@nkit-pdf-%u-%llu.pdf",
                                               NSTemporaryDirectory(), wid,
                                               request_id];
    if ([data writeToFile:tmp atomically:YES]) {
      webview_emit(wid, NA_WEBVIEW_PDF_RESULT, tmp, @"", 0, request_id);
    } else {
      webview_emit(wid, NA_WEBVIEW_PDF_RESULT, @"", @"write failed", 1,
                   request_id);
    }
  };
  if (@available(macOS 12.0, *)) {
    WKPDFConfiguration* cfg = [[WKPDFConfiguration alloc] init];
    [web createPDFWithConfiguration:cfg completionHandler:done];
  } else {
    webview_emit(wid, NA_WEBVIEW_PDF_RESULT, @"",
                 @"PDF export needs macOS 12+", 1, request_id);
  }
}

// --- Snapshot (async -> event 8, PNG temp file) ---

void na_webview_snapshot(void* ptr, uint64_t request_id) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web) {
    return;
  }
  uint32_t wid = web.widgetId;
  WKSnapshotConfiguration* cfg = [[WKSnapshotConfiguration alloc] init];
  [web takeSnapshotWithConfiguration:cfg
                   completionHandler:^(NSImage* image, NSError* error) {
                     if (!g_webviews[@(wid)]) {
                       return;
                     }
                     if (error || !image) {
                       webview_emit(wid, NA_WEBVIEW_SNAPSHOT_RESULT, @"",
                                    error ? error.localizedDescription
                                          : @"failed",
                                    1, request_id);
                       return;
                     }
                     NSBitmapImageRep* rep = [[NSBitmapImageRep alloc]
                         initWithData:[image TIFFRepresentation]];
                     NSData* png = [rep representationUsingType:NSBitmapImageFileTypePNG
                                                    properties:@{}];
                     if (!png) {
                       webview_emit(wid, NA_WEBVIEW_SNAPSHOT_RESULT, @"",
                                    @"encode failed", 1, request_id);
                       return;
                     }
                     NSString* tmp = [NSString
                         stringWithFormat:@"%@nkit-snap-%u-%llu.png",
                                          NSTemporaryDirectory(), wid,
                                          request_id];
                     if ([png writeToFile:tmp atomically:YES]) {
                       webview_emit(wid, NA_WEBVIEW_SNAPSHOT_RESULT, tmp, @"",
                                    0, request_id);
                     } else {
                       webview_emit(wid, NA_WEBVIEW_SNAPSHOT_RESULT, @"",
                                    @"write failed", 1, request_id);
                     }
                   }];
}

// --- Cookies + website data (events / direct) ---

void na_webview_get_cookies(void* ptr, uint64_t request_id) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web) {
    return;
  }
  uint32_t wid = web.widgetId;
  if (@available(macOS 10.13, *)) {
    WKHTTPCookieStore* jar = web.configuration.websiteDataStore.httpCookieStore;
    [jar getAllCookies:^(NSArray<NSHTTPCookie*>* cookies) {
      if (!g_webviews[@(wid)]) {
        return;
      }
      NSMutableArray* arr = [NSMutableArray array];
      for (NSHTTPCookie* c in cookies) {
        [arr addObject:@{
          @"name" : c.name ?: @"",
          @"value" : c.value ?: @"",
          @"domain" : c.domain ?: @"",
          @"path" : c.path ?: @"/",
          @"secure" : @(c.isSecure),
          @"httpOnly" : @(c.isHTTPOnly),
          @"expires" : @([c.expiresDate timeIntervalSince1970])
        }];
      }
      NSError* err = nil;
      NSData* json = [NSJSONSerialization dataWithJSONObject:arr
                                                     options:0
                                                       error:&err];
      NSString* s = json
          ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]
          : @"[]";
      webview_emit(wid, NA_WEBVIEW_COOKIES_RESULT, s, @"", 0, request_id);
    }];
  } else {
    webview_emit(wid, NA_WEBVIEW_COOKIES_RESULT, @"[]", @"", 0, request_id);
  }
}

void na_webview_set_cookie(void* ptr, const char* name, const char* value,
                           const char* domain, const char* path,
                           double max_age_sec) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web || !name || !value) {
    return;
  }
  if (@available(macOS 10.13, *)) {
    NSMutableDictionary* props = [@{
      NSHTTPCookieName : [NSString stringWithUTF8String:name],
      NSHTTPCookieValue : [NSString stringWithUTF8String:value],
      NSHTTPCookiePath : (path && path[0] != '\0')
          ? [NSString stringWithUTF8String:path]
          : @"/"
    } mutableCopy];
    if (domain && domain[0] != '\0') {
      props[NSHTTPCookieDomain] = [NSString stringWithUTF8String:domain];
    }
    if (max_age_sec > 0) {
      props[NSHTTPCookieExpires] =
          [NSDate dateWithTimeIntervalSinceNow:max_age_sec];
    }
    NSHTTPCookie* cookie = [NSHTTPCookie cookieWithProperties:props];
    if (cookie) {
      [web.configuration.websiteDataStore.httpCookieStore setCookie:cookie
                                                  completionHandler:nil];
    }
  }
}

void na_webview_delete_cookie(void* ptr, const char* name) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web || !name) {
    return;
  }
  if (@available(macOS 10.13, *)) {
    NSString* n = [NSString stringWithUTF8String:name];
    WKHTTPCookieStore* jar = web.configuration.websiteDataStore.httpCookieStore;
    [jar getAllCookies:^(NSArray<NSHTTPCookie*>* cookies) {
      for (NSHTTPCookie* c in cookies) {
        if ([c.name isEqualToString:n]) {
          [jar deleteCookie:c completionHandler:nil];
        }
      }
    }];
  }
}

void na_webview_clear_website_data(void* ptr, bool cookies, bool cache,
                                   bool storage, double since_unix) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web) {
    return;
  }
  if (@available(macOS 10.11, *)) {
    NSMutableSet* types = [NSMutableSet set];
    if (cookies) {
      [types addObject:WKWebsiteDataTypeCookies];
    }
    if (cache) {
      [types addObject:WKWebsiteDataTypeDiskCache];
      [types addObject:WKWebsiteDataTypeMemoryCache];
    }
    if (storage) {
      [types addObject:WKWebsiteDataTypeLocalStorage];
      [types addObject:WKWebsiteDataTypeSessionStorage];
      [types addObject:WKWebsiteDataTypeIndexedDBDatabases];
    }
    if (types.count == 0) {
      return;
    }
    NSDate* since = (since_unix > 0)
        ? [NSDate dateWithTimeIntervalSince1970:since_unix]
        : [NSDate distantPast];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:types
                                               modifiedSince:since
                                           completionHandler:^{
                                           }];
    if (web.configuration.websiteDataStore !=
        [WKWebsiteDataStore defaultDataStore]) {
      [web.configuration.websiteDataStore removeDataOfTypes:types
                                              modifiedSince:since
                                          completionHandler:^{
                                          }];
    }
  }
}

void na_webview_clear_all_website_data(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web) {
    return;
  }
  if (@available(macOS 10.11, *)) {
    NSSet* types = [WKWebsiteDataStore allWebsiteDataTypes];
    NSDate* since = [NSDate distantPast];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:types
                                               modifiedSince:since
                                           completionHandler:^{
                                           }];
    if (web.configuration.websiteDataStore !=
        [WKWebsiteDataStore defaultDataStore]) {
      [web.configuration.websiteDataStore removeDataOfTypes:types
                                              modifiedSince:since
                                          completionHandler:^{
                                          }];
    }
  }
}

// --- Find in page (JS window.find -> jsResult event) ---

static NSString* webview_js_escape(NSString* s) {
  NSMutableString* out = [NSMutableString stringWithCapacity:s.length];
  for (NSUInteger i = 0; i < s.length; i++) {
    unichar c = [s characterAtIndex:i];
    switch (c) {
      case '\\': [out appendString:@"\\\\"]; break;
      case '"': [out appendString:@"\\\""]; break;
      case '\n': [out appendString:@"\\n"]; break;
      case '\r': [out appendString:@"\\r"]; break;
      default: [out appendFormat:@"%C", c]; break;
    }
  }
  return out;
}

void na_webview_find(void* ptr, const char* text, bool backwards,
                     bool case_sensitive, bool wraps, uint64_t request_id) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web || !text || text[0] == '\0') {
    return;
  }
  uint32_t wid = web.widgetId;
  NSString* q = webview_js_escape([NSString stringWithUTF8String:text]);
  NSString* js = [NSString
      stringWithFormat:
          @"(function(){try{return window.find(\"%@\", %@, %@, %@, false, false, false);}catch(e){return false;}})()",
          q, case_sensitive ? @"true" : @"false",
          backwards ? @"true" : @"false", wraps ? @"true" : @"false"];
  __weak NAWebView* weakWeb = web;
  [web evaluateJavaScript:js
       completionHandler:^(id result, NSError* error) {
         __strong NAWebView* strongWeb = weakWeb;
         (void)strongWeb;
         if (!g_webviews[@(wid)]) {
           return;
         }
         if (error) {
           webview_emit(wid, NA_WEBVIEW_JS_RESULT, error.localizedDescription,
                        nil, 1, request_id);
         } else {
           BOOL found = NO;
           if ([result isKindOfClass:[NSNumber class]]) {
             found = [(NSNumber*)result boolValue];
           }
           webview_emit(wid, NA_WEBVIEW_JS_RESULT, found ? @"true" : @"false",
                        nil, 0, request_id);
         }
       }];
}

void na_webview_hide_find(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web) {
    return;
  }
  [web evaluateJavaScript:@"window.getSelection().removeAllRanges();"
       completionHandler:nil];
}

// --- Printing (shows the standard print panel; manual QA, not headless) ---

void na_webview_print(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (!web) {
    return;
  }
  NSPrintOperation* op = [web printOperationWithPrintInfo:[NSPrintInfo sharedPrintInfo]];
  [op runOperation];
}

// --- Web context menu toggle ---

void na_webview_set_context_menu_enabled(void* ptr, bool enabled) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  if (web) {
    web.webContextMenuEnabled = enabled ? YES : NO;
  }
}

bool na_webview_get_context_menu_enabled(void* ptr) {
  NAWebView* web = (__bridge NAWebView*)ptr;
  return !web || web.webContextMenuEnabled == YES;
}

// Full-stack test hook: replays an event without a live page load.
void na_webview_fire(uint32_t widget_id, int kind, const char* arg1,
                     const char* arg2, double num, uint64_t num2) {
  if (!g_webview_fn) {
    return;
  }
  g_webview_fn(widget_id, kind, arg1, arg2, num, num2, g_webview_ctx);
}
