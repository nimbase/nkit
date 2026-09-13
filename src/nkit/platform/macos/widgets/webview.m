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

@interface NAWebView : WKWebView <WKNavigationDelegate, WKScriptMessageHandler>
@property(nonatomic, assign) uint32_t widgetId;
@property(nonatomic, strong) NSMutableSet<NSString*>* handlerNames;
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
  web.navigationDelegate = web;
  [web addObserver:web forKeyPath:@"estimatedProgress"
           options:NSKeyValueObservingOptionNew context:NULL];
  g_webviews[@(widget_id)] = web;
  na_gui_register_view(web);
  return (__bridge void*)web;
}

void na_webview_free(uint32_t widget_id, void* ptr) {
  ensure_webview_tables();
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

// Full-stack test hook: replays an event without a live page load.
void na_webview_fire(uint32_t widget_id, int kind, const char* arg1,
                     const char* arg2, double num, uint64_t num2) {
  if (!g_webview_fn) {
    return;
  }
  g_webview_fn(widget_id, kind, arg1, arg2, num, num2, g_webview_ctx);
}
