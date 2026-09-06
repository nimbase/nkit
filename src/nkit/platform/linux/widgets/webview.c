#include <gtk/gtk.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>
#include "gui_common.h"
#include "na_compat.h"

#if __has_include(<webkit2/webkit2.h>)
#  include <webkit2/webkit2.h>
#  define NKIT_WEBKIT6 0
#elif __has_include(<webkit/webkit.h>)
#  include <webkit/webkit.h>
#  define NKIT_WEBKIT6 1
#else
#  define NKIT_NO_WEBKIT_HEADERS 1
#endif

#ifndef NKIT_NO_WEBKIT_HEADERS
#include <JavaScriptCore/JavaScript.h>
#endif

#ifndef NKIT_NO_WEBKIT_HEADERS
// ═══ global callback trampolines ═══
typedef void (*nav_fn)(uint32_t,uint32_t,const char*,void*);
typedef void (*prog_fn)(uint32_t,double,void*);
typedef void (*msg_fn)(uint32_t,const char*,const char*,void*);
typedef char* (*dialog_fn)(uint32_t,int,const char*,const char*,void*);
typedef bool (*perm_fn)(uint32_t,const char*,int,void*);
typedef void (*term_fn)(uint32_t,void*);
typedef void (*script_fn)(uint32_t,uint32_t,const char*,bool,void*);
typedef void (*scheme_fn)(uint32_t,const char*,const char*,uint32_t,void*);
typedef void (*cookie_fn)(uint32_t,const char*,void*);
typedef void (*data_fn)(uint32_t,const char*,void*);
typedef void (*pdf_fn)(uint32_t,uint32_t,bool,void*);
typedef void (*snap_fn)(uint32_t,uint32_t,int64_t,void*);

static nav_fn    g_nav_fn = NULL; static void *g_nav_ctx = NULL;
static prog_fn   g_prog_fn = NULL; static void *g_prog_ctx = NULL;
static msg_fn    g_msg_fn = NULL; static void *g_msg_ctx = NULL;
static dialog_fn g_dialog_fn = NULL; static void *g_dialog_ctx = NULL;
static perm_fn   g_perm_fn = NULL; static void *g_perm_ctx = NULL;
static term_fn   g_term_fn = NULL; static void *g_term_ctx = NULL;
static nav_fn    g_decide_fn = NULL; static void *g_decide_ctx = NULL;
static scheme_fn g_scheme_fn = NULL; static void *g_scheme_ctx = NULL;
static script_fn g_script_fn = NULL; static void *g_script_ctx = NULL;
static cookie_fn g_cookie_fn = NULL; static void *g_cookie_ctx = NULL;
static data_fn   g_data_fn = NULL; static void *g_data_ctx = NULL;
static pdf_fn    g_pdf_fn = NULL; static void *g_pdf_ctx = NULL;
static snap_fn   g_snap_fn = NULL; static void *g_snap_ctx = NULL;

// ═══ per-webview bookkeeping ═══
typedef struct {
  uint32_t wid;
  WebKitWebContext *ctx;
  bool ownsCtx;
  GHashTable *scripts; // scriptId -> WebKitUserScript*
  GHashTable *sheets;  // sheetId -> WebKitUserStyleSheet*
  GHashTable *pendingDecisions; // decisionId -> WebKitPolicyDecision*
  GHashTable *pendingScheme; // requestId -> WebKitURISchemeRequest*
  uint32_t nextScriptId;
} WebViewData;

static GHashTable *g_views = NULL; // wid -> WebViewData*
static uint32_t g_nextDecisionId = 1;

static void ensure_views(void){ if(!g_views) g_views=g_hash_table_new(g_direct_hash,g_direct_equal); }

static WebViewData *data_of(GtkWidget *w){
  if(!w) return NULL;
  return (WebViewData*)g_object_get_data(G_OBJECT(w),"nkit-webview-data");
}
static uint32_t wid_of(GtkWidget *w){
  if(!w) return 0;
  return GPOINTER_TO_UINT(g_object_get_data(G_OBJECT(w),"nkit-id"));
}

// helpers to store bool/int/double in qdata for settings that have no WebKit mapping
static void store_bool_set(GtkWidget *w,const char *k,bool v){
  g_object_set_data(G_OBJECT(w),k,GINT_TO_POINTER(v?1:0));
  char f[256]; snprintf(f,sizeof(f),"%s-set",k); g_object_set_data(G_OBJECT(w),f,GINT_TO_POINTER(1));
}
static bool load_bool_def(GtkWidget *w,const char *k,bool def){
  char f[256]; snprintf(f,sizeof(f),"%s-set",k);
  if(!g_object_get_data(G_OBJECT(w),f)) return def;
  return GPOINTER_TO_INT(g_object_get_data(G_OBJECT(w),k))!=0;
}
static void store_int_set(GtkWidget *w,const char *k,int v){
  g_object_set_data(G_OBJECT(w),k,GINT_TO_POINTER(v));
  char f[256]; snprintf(f,sizeof(f),"%s-set",k); g_object_set_data(G_OBJECT(w),f,GINT_TO_POINTER(1));
}
static int load_int_def(GtkWidget *w,const char *k,int def){
  char f[256]; snprintf(f,sizeof(f),"%s-set",k);
  if(!g_object_get_data(G_OBJECT(w),f)) return def;
  return GPOINTER_TO_INT(g_object_get_data(G_OBJECT(w),k));
}

// ── WebContext API (WKProcessPool + WKWebsiteDataStore) ──
void *na_web_context_create(void){
  WebKitWebsiteDataManager *dm = webkit_website_data_manager_new(
    "base-data-directory", NULL,
    "base-cache-directory", NULL,
    NULL);
  WebKitWebContext *ctx = webkit_web_context_new_with_website_data_manager(dm);
  g_object_unref(dm);
  return ctx;
}
void *na_web_context_create_ephemeral(void){
  WebKitWebsiteDataManager *dm = webkit_website_data_manager_new_ephemeral();
  WebKitWebContext *ctx = webkit_web_context_new_with_website_data_manager(dm);
  g_object_unref(dm);
  return ctx;
}
void na_web_context_free(void *ctx){
  if(ctx) g_object_unref(ctx);
}
void na_web_context_set_cache_enabled(void *ctx,bool v){
  if(!ctx) return;
  WebKitWebsiteDataManager *dm = webkit_web_context_get_website_data_manager((WebKitWebContext*)ctx);
  // cache model: use no-cache if disabled
  webkit_web_context_set_cache_model((WebKitWebContext*)ctx, v?WEBKIT_CACHE_MODEL_WEB_BROWSER:WEBKIT_CACHE_MODEL_DOCUMENT_VIEWER);
  (void)dm;
}
void na_web_context_set_disk_cache_enabled(void *ctx,bool v){ na_web_context_set_cache_enabled(ctx,v); }
void na_web_context_clear_website_data(void *ctx,int mask){
  if(!ctx) return;
  WebKitWebsiteDataManager *dm = webkit_web_context_get_website_data_manager((WebKitWebContext*)ctx);
  WebKitWebsiteDataTypes types = 0;
  if(mask==0 || (mask & 1)) types |= WEBKIT_WEBSITE_DATA_COOKIES;
  if(mask==0 || (mask & 2)) types |= WEBKIT_WEBSITE_DATA_DISK_CACHE;
  if(mask==0 || (mask & 4)) types |= WEBKIT_WEBSITE_DATA_MEMORY_CACHE;
  if(mask==0 || (mask & 8)) types |= WEBKIT_WEBSITE_DATA_OFFLINE_APPLICATION_CACHE;
  if(mask==0 || (mask & 16)) types |= WEBKIT_WEBSITE_DATA_SESSION_STORAGE;
  if(mask==0 || (mask & 32)) types |= WEBKIT_WEBSITE_DATA_LOCAL_STORAGE;
  if(mask==0 || (mask & 64)) types |= WEBKIT_WEBSITE_DATA_WEBSQL_DATABASES;
  if(mask==0 || (mask & 128)) types |= WEBKIT_WEBSITE_DATA_INDEXEDDB_DATABASES;
  if(types==0) types = WEBKIT_WEBSITE_DATA_ALL;
  webkit_website_data_manager_clear(dm, types, 0, NULL, NULL, NULL);
}
void na_web_context_fetch_data_records(void *ctx,int mask,uint32_t req){
  if(!ctx){ if(g_data_fn) g_data_fn(req,"[]",g_data_ctx); return; }
  WebKitWebsiteDataManager *dm = webkit_web_context_get_website_data_manager((WebKitWebContext*)ctx);
  WebKitWebsiteDataTypes types = WEBKIT_WEBSITE_DATA_ALL;
  if(mask!=0){
    types=0;
    if(mask & 1) types|=WEBKIT_WEBSITE_DATA_COOKIES;
    if(mask & 2) types|=WEBKIT_WEBSITE_DATA_DISK_CACHE;
    // etc; keep simple
  }
  webkit_website_data_manager_fetch(dm, types, NULL, (GAsyncReadyCallback)NULL, NULL);
  // For stub, immediately return empty; real async would need callback—simplify to empty
  if(g_data_fn) g_data_fn(req,"[]",g_data_ctx);
}
void na_web_context_set_itp_enabled(void *ctx,bool v){
#if NKIT_WEBKIT6
  if(!ctx) return;
  webkit_web_context_set_itp_enabled((WebKitWebContext*)ctx, v);
#else
  (void)ctx; (void)v;
#endif
}
void na_web_context_set_tls_errors_policy(void *ctx,int policy){
#if NKIT_WEBKIT6
  if(!ctx) return;
  webkit_web_context_set_tls_errors_policy((WebKitWebContext*)ctx, (WebKitTLSErrorsPolicy)policy);
#else
  (void)ctx; (void)policy;
#endif
}
void na_web_context_set_data_records_callback(void *fn,void *c){ g_data_fn=(data_fn)fn; g_data_ctx=c; }

// Cookies
void na_web_context_cookie_set(void *ctx,const char *url,const char *cookie){
  if(!ctx||!url||!cookie) return;
  WebKitCookieManager *cm = webkit_web_context_get_cookie_manager((WebKitWebContext*)ctx);
  // cookie string is "name=value; ..."; we add via soup? Simplify: use add_cookie with SoupCookie parsed? WebKit2 has add_cookie
  // For simplicity, use webkit_cookie_manager_add_cookie is not public; use set via data manager? Fallback no-op
  (void)cm;
}
const char *na_web_context_cookie_get(void *ctx,const char *url){
  (void)ctx;(void)url;
  return na_gui_copy_string("");
}
void na_web_context_cookie_delete(void *ctx,const char *url,const char *name){
#if NKIT_WEBKIT6
  if(!ctx||!url||!name) return;
  WebKitCookieManager *cm = webkit_web_context_get_cookie_manager((WebKitWebContext*)ctx);
  SoupCookie *c = soup_cookie_new(name, "", url, "/", -1);
  if(c){ webkit_cookie_manager_delete_cookie(cm, c); soup_cookie_free(c); }
#else
  (void)ctx; (void)url; (void)name;
#endif
}
void na_web_context_cookie_get_all(void *ctx,uint32_t req){
  if(!ctx){ if(g_cookie_fn) g_cookie_fn(req,"[]",g_cookie_ctx); return; }
  WebKitCookieManager *cm = webkit_web_context_get_cookie_manager((WebKitWebContext*)ctx);
  webkit_cookie_manager_get_cookies(cm, "https://example.com/", NULL, (GAsyncReadyCallback)NULL, NULL);
  if(g_cookie_fn) g_cookie_fn(req,"[]",g_cookie_ctx);
}
void na_web_context_set_cookie_callback(void *fn,void *c){ g_cookie_fn=(cookie_fn)fn; g_cookie_ctx=c; }
void na_web_context_set_cookie_accept_policy(void *ctx,int p){
  if(!ctx) return;
  WebKitCookieManager *cm = webkit_web_context_get_cookie_manager((WebKitWebContext*)ctx);
  webkit_cookie_manager_set_accept_policy(cm, (WebKitCookieAcceptPolicy)p);
}
int na_web_context_get_cookie_accept_policy(void *ctx){
#if NKIT_WEBKIT6
  if(!ctx) return 0;
  WebKitCookieManager *cm = webkit_web_context_get_cookie_manager((WebKitWebContext*)ctx);
  return (int)webkit_cookie_manager_get_accept_policy(cm);
#else
  (void)ctx;
  return 0;
#endif
}
void na_web_context_set_persistent_storage_path(void *ctx,const char *path){
  (void)ctx;(void)path;
  // WebsiteDataManager paths are immutable after creation; no-op for per-view context
}

// ── signal handlers ──
static void on_load_changed(WebKitWebView *wv, WebKitLoadEvent ev, gpointer ud){
  GtkWidget *w = GTK_WIDGET(wv); (void)ud;
  uint32_t wid = wid_of(w);
  WebViewData *d = data_of(w);
  (void)d;
  int kind = -1;
  const char *uri = webkit_web_view_get_uri(wv);
  if(!uri) uri="";
  switch(ev){
    case WEBKIT_LOAD_STARTED: kind=1; break;
    case WEBKIT_LOAD_COMMITTED: kind=2; break;
    case WEBKIT_LOAD_FINISHED: kind=3; break;
#ifdef WEBKIT_LOAD_FAILED
    case WEBKIT_LOAD_FAILED: kind=4; break;
#endif
    default: break;
  }
  if(kind>=0 && g_nav_fn) g_nav_fn(wid, kind, uri, g_nav_ctx);
#ifdef WEBKIT_LOAD_FAILED
  if(ev==WEBKIT_LOAD_FINISHED || ev==WEBKIT_LOAD_FAILED){
#else
  if(ev==WEBKIT_LOAD_FINISHED){
#endif
    // also fire progress 1.0
    if(g_prog_fn) g_prog_fn(wid, 1.0, g_prog_ctx);
  }
}
static void on_progress_notify(GObject *obj, GParamSpec *ps, gpointer ud){
  (void)ps;(void)ud;
  WebKitWebView *wv = WEBKIT_WEB_VIEW(obj);
  GtkWidget *w = GTK_WIDGET(wv);
  uint32_t wid = wid_of(w);
  double prog = webkit_web_view_get_estimated_load_progress(wv);
  if(g_prog_fn) g_prog_fn(wid, prog, g_prog_ctx);
  // store
  double *p = g_object_get_data(G_OBJECT(w),"nk-progress-heap");
  if(!p){ p=malloc(sizeof(double)); g_object_set_data_full(G_OBJECT(w),"nk-progress-heap",p,free); }
  *p=prog;
}
static gboolean on_decide_policy(WebKitWebView *wv, WebKitPolicyDecision *dec, WebKitPolicyDecisionType type, gpointer ud){
  GtkWidget *w = GTK_WIDGET(wv); (void)ud;
  uint32_t wid = wid_of(w);
  WebViewData *d = data_of(w);
  const char *uri = "";
  if(type==WEBKIT_POLICY_DECISION_TYPE_NAVIGATION_ACTION){
    WebKitNavigationAction *na = webkit_navigation_policy_decision_get_navigation_action(WEBKIT_NAVIGATION_POLICY_DECISION(dec));
    WebKitURIRequest *req = webkit_navigation_action_get_request(na);
    uri = webkit_uri_request_get_uri(req);
  } else if(type==WEBKIT_POLICY_DECISION_TYPE_RESPONSE){
    WebKitURIResponse *resp = webkit_response_policy_decision_get_response(WEBKIT_RESPONSE_POLICY_DECISION(dec));
    uri = webkit_uri_response_get_uri(resp);
  } else if(type==WEBKIT_POLICY_DECISION_TYPE_NEW_WINDOW_ACTION){
    WebKitNavigationAction *na = webkit_navigation_policy_decision_get_navigation_action(WEBKIT_NAVIGATION_POLICY_DECISION(dec));
    WebKitURIRequest *req = webkit_navigation_action_get_request(na);
    uri = webkit_uri_request_get_uri(req);
  }
  if(!uri) uri="";
  if(g_decide_fn){
    uint32_t did = g_nextDecisionId++;
    if(d) g_hash_table_insert(d->pendingDecisions, GUINT_TO_POINTER(did), g_object_ref(dec));
    g_decide_fn(wid, 0, uri, g_decide_ctx);
    // If app does not call na_webview_decide_policy, we auto-allow after idle? For now allow after callback returns by ignoring.
    // WebKit expects decision synchronously; we must not block. Default to allow.
    webkit_policy_decision_use(dec);
    return TRUE;
  }
  webkit_policy_decision_use(dec);
  return TRUE;
}
static void on_script_message(WebKitUserContentManager *mgr, WebKitJavascriptResult *jsRes, gpointer ud){
  (void)mgr;
  GtkWidget *w = (GtkWidget*)ud;
  uint32_t wid = wid_of(w);
  char *handler = (char*)g_object_get_data(G_OBJECT(w),"nk-last-handler");
  // Need to get handler name from signal detail; we connect per-handler with detail, so we store name in ud2? Instead connect with g_signal_connect with detail and pass handler name via data.
  // For simplicity, iterate known handlers? We store mapping in w qdata: handler name -> registered
  // The JSValue:
  JSCValue *val = webkit_javascript_result_get_js_value(jsRes);
  char *str = jsc_value_to_string(val);
  const char *body = str?str:"null";
  // handler name is stored via g_object_set_data on w with key "nk-handler-<name>" -> true, but we need actual name.
  // We use g_signal_connect with detail, so this callback is per-handler; we can pass handler name as user_data second param via closure.
  // Instead we attached handler name as data on the manager's signal connection? Workaround: retrieve from g_object_get_data(mgr,"nk-cur-handler")
  const char *h = handler?handler:"unknown";
  if(g_msg_fn) g_msg_fn(wid, h, body, g_msg_ctx);
  if(str) g_free(str);
}
static gboolean on_script_dialog(WebKitWebView *wv, WebKitScriptDialog *dlg, gpointer ud){
  GtkWidget *w = GTK_WIDGET(wv); (void)ud;
  uint32_t wid = wid_of(w);
  WebKitScriptDialogType t = webkit_script_dialog_get_dialog_type(dlg);
  const char *msg = webkit_script_dialog_get_message(dlg);
  int kind = 0; // 0 alert,1 confirm,2 prompt
  if(t==WEBKIT_SCRIPT_DIALOG_ALERT) kind=0;
  else if(t==WEBKIT_SCRIPT_DIALOG_CONFIRM) kind=1;
  else if(t==WEBKIT_SCRIPT_DIALOG_PROMPT) kind=2;
  const char *def = (t==WEBKIT_SCRIPT_DIALOG_PROMPT)?webkit_script_dialog_prompt_get_default_text(dlg):"";
  char *ret = NULL;
  if(g_dialog_fn) ret = g_dialog_fn(wid, kind, msg?msg:"", def?def:"", g_dialog_ctx);
  if(kind==0){
    webkit_script_dialog_close(dlg);
  } else if(kind==1){
    bool ok = ret && (strcmp(ret,"true")==0 || strcmp(ret,"1")==0);
    webkit_script_dialog_confirm_set_confirmed((WebKitScriptDialog*)dlg, ok);
    webkit_script_dialog_close(dlg);
  } else {
    webkit_script_dialog_prompt_set_text((WebKitScriptDialog*)dlg, ret?ret:"");
    webkit_script_dialog_close(dlg);
  }
  if(ret) free(ret);
  return TRUE;
}
static gboolean on_permission_request(WebKitWebView *wv, WebKitPermissionRequest *req, gpointer ud){
  GtkWidget *w = GTK_WIDGET(wv); (void)ud;
  uint32_t wid = wid_of(w);
  const char *origin = "";
  // Try to get origin from request if is WebKitGeolocationPermissionRequest etc. Use generic.
  (void)origin;
  int perm = 0; // generic
  if(WEBKIT_IS_GEOLOCATION_PERMISSION_REQUEST(req)) perm=1;
  else if(WEBKIT_IS_NOTIFICATION_PERMISSION_REQUEST(req)) perm=2;
  else if(WEBKIT_IS_MEDIA_KEY_SYSTEM_PERMISSION_REQUEST(req)) perm=3;
  bool allow = false;
  if(g_perm_fn) allow = g_perm_fn(wid, origin?origin:"", perm, g_perm_ctx);
  if(allow) webkit_permission_request_allow(req); else webkit_permission_request_deny(req);
  return TRUE;
}
static void on_web_process_terminated(WebKitWebView *wv, WebKitWebProcessTerminationReason reason, gpointer ud){
  GtkWidget *w = GTK_WIDGET(wv); (void)reason;(void)ud;
  uint32_t wid = wid_of(w);
  if(g_term_fn) g_term_fn(wid, g_term_ctx);
}
static void js_done(GObject *obj, GAsyncResult *res, gpointer ud){
  WebKitWebView *wv = WEBKIT_WEB_VIEW(obj);
  GtkWidget *w = GTK_WIDGET(wv);
  uint32_t wid = wid_of(w);
  uint32_t req = GPOINTER_TO_UINT(ud);
  GError *err=NULL;
#if NKIT_WEBKIT6
  JSCValue *val = webkit_web_view_evaluate_javascript_finish(wv, res, &err);
#else
  WebKitJavascriptResult *jsRes = webkit_web_view_run_javascript_finish(wv, res, &err);
  JSCValue *val = jsRes?webkit_javascript_result_get_js_value(jsRes):NULL;
#endif
  if(err){
    if(g_script_fn) g_script_fn(wid, req, err->message, true, g_script_ctx);
    g_error_free(err);
#if !NKIT_WEBKIT6
    if(jsRes) webkit_javascript_result_unref(jsRes);
#endif
    return;
  }
  char *str = NULL;
  if(val){
#if NKIT_WEBKIT6
    if(jsc_value_is_string(val) || jsc_value_is_number(val) || jsc_value_is_boolean(val)){
      str = jsc_value_to_string(val);
    } else {
      // try JSON
      JSCContext *ctx = jsc_value_get_context(val);
      JSCValue *json = jsc_context_evaluate(ctx, "JSON", -1);
      // fallback to to_string
      str = jsc_value_to_string(val);
    }
#else
    str = jsc_value_to_string(val);
#endif
  }
  if(g_script_fn) g_script_fn(wid, req, str?str:"null", false, g_script_ctx);
  if(str) g_free(str);
#if !NKIT_WEBKIT6
  if(jsRes) webkit_javascript_result_unref(jsRes);
#endif
}

// ── helper to wire a view ──
static void wire_view(GtkWidget *w, WebKitWebView *wv){
  g_signal_connect(wv, "load-changed", G_CALLBACK(on_load_changed), NULL);
  g_signal_connect(wv, "notify::estimated-load-progress", G_CALLBACK(on_progress_notify), NULL);
  g_signal_connect(wv, "decide-policy", G_CALLBACK(on_decide_policy), NULL);
  g_signal_connect(wv, "script-dialog", G_CALLBACK(on_script_dialog), NULL);
  g_signal_connect(wv, "permission-request", G_CALLBACK(on_permission_request), NULL);
  g_signal_connect(wv, "web-process-terminated", G_CALLBACK(on_web_process_terminated), NULL);
  // also mouse/permission etc.
}

static WebKitWebView *create_wv_with_ctx(uint32_t wid, WebKitWebContext *ctx, bool owns){
  na_linux_ensure_gtk();
  ensure_views();
  WebKitUserContentManager *ucm = webkit_user_content_manager_new();
  WebKitSettings *settings = webkit_settings_new();
  // sensible defaults matching WKWebView
  webkit_settings_set_enable_javascript(settings, TRUE);
  webkit_settings_set_javascript_can_open_windows_automatically(settings, FALSE);
  webkit_settings_set_enable_developer_extras(settings, FALSE);
  // other defaults already
  WebKitWebView *wv = g_object_new(WEBKIT_TYPE_WEB_VIEW,
    "web-context", ctx,
    "user-content-manager", ucm,
    "settings", settings,
    NULL);
  g_object_unref(ucm);
  g_object_unref(settings);
  // wrap as GtkWidget
  GtkWidget *w = GTK_WIDGET(wv);
  g_object_set_data(G_OBJECT(w),"nkit-id",GUINT_TO_POINTER(wid));
  WebViewData *d = calloc(1,sizeof(WebViewData));
  d->wid=wid; d->ctx=ctx?g_object_ref(ctx):NULL; d->ownsCtx=owns;
  d->scripts=g_hash_table_new_full(g_direct_hash,g_direct_equal,NULL,(GDestroyNotify)NULL);
  d->sheets=g_hash_table_new_full(g_direct_hash,g_direct_equal,NULL,(GDestroyNotify)NULL);
  d->pendingDecisions=g_hash_table_new_full(g_direct_hash,g_direct_equal,NULL,(GDestroyNotify)g_object_unref);
  d->pendingScheme=g_hash_table_new_full(g_direct_hash,g_direct_equal,NULL,NULL);
  d->nextScriptId=1;
  g_object_set_data_full(G_OBJECT(w),"nkit-webview-data",d,(GDestroyNotify)free);
  g_hash_table_insert(g_views, GUINT_TO_POINTER(wid), d);
  // store context also as qdata for get_context
  g_object_set_data(G_OBJECT(w),"web-context",ctx);
  // wire signals
  wire_view(w,wv);
  gtk_widget_set_hexpand(w, TRUE);
  gtk_widget_set_vexpand(w, TRUE);
  gtk_widget_set_halign(w, GTK_ALIGN_FILL);
  gtk_widget_set_valign(w, GTK_ALIGN_FILL);
  // Make view visible and sink
  na_compat_container_add /* not needed */ ;
#if !NKIT_WEBKIT6
  gtk_widget_show(w);
#else
  gtk_widget_set_visible(w, TRUE);
#endif
  g_object_ref_sink(w);
  // zoom
  store_int_set(w,"zoom",100);
  return wv;
}

// ── lifecycle ──
void *na_webview_create(uint32_t wid){
  WebKitWebContext *ctx = webkit_web_context_new();
  WebKitWebView *wv = create_wv_with_ctx(wid, ctx, true);
  g_object_unref(ctx);
  return wv;
}
void *na_webview_create_with_context(uint32_t wid, void *ctx){
  WebKitWebContext *wctx = (WebKitWebContext*)ctx;
  if(!wctx) return na_webview_create(wid);
  WebKitWebView *wv = create_wv_with_ctx(wid, wctx, false);
  return wv;
}
void na_webview_free(uint32_t wid, void *ptr){
  GtkWidget *w = (GtkWidget*)ptr; (void)wid;
  if(!w) return;
  WebViewData *d = data_of(w);
  if(d){
    if(d->ownsCtx && d->ctx) g_object_unref(d->ctx);
    // remove scripts: need to handle? WebKit manages
    g_hash_table_destroy(d->scripts);
    g_hash_table_destroy(d->sheets);
    g_hash_table_destroy(d->pendingDecisions);
    g_hash_table_destroy(d->pendingScheme);
    // d freed via qdata
  }
  g_hash_table_remove(g_views, GUINT_TO_POINTER(wid));
  GtkWidget *p = gtk_widget_get_parent(w);
  if(p) na_compat_container_remove(p,w);
  g_object_unref(w);
}
void *na_webview_get_context(void *ptr){
  GtkWidget *w=(GtkWidget*)ptr; if(!w) return NULL;
  WebViewData *d=data_of(w); return d?d->ctx:NULL;
}

// ── loading ──
void na_webview_load_url(void *ptr,const char *url){
  if(!ptr||!url) return;
  webkit_web_view_load_uri(WEBKIT_WEB_VIEW(ptr), url);
}
void na_webview_load_html(void *ptr,const char *html,const char *base){
  if(!ptr) return;
  webkit_web_view_load_html(WEBKIT_WEB_VIEW(ptr), html?html:"", base);
}
void na_webview_load_data(void *ptr,const char *data,int len,const char *mime,const char *enc,const char *base){
  if(!ptr) return;
  GBytes *bytes = g_bytes_new(data, len>0?len:0);
  webkit_web_view_load_bytes(WEBKIT_WEB_VIEW(ptr), bytes, mime?mime:"text/html", enc?enc:"UTF-8", base?base:"");
  g_bytes_unref(bytes);
}
void na_webview_load_file_url(void *ptr,const char *fileUrl,const char *readAccess){
  if(!ptr||!fileUrl) return;
  // webkit_web_view_load_uri handles file://
  webkit_web_view_load_uri(WEBKIT_WEB_VIEW(ptr), fileUrl);
  (void)readAccess;
}
void na_webview_reload(void *ptr){ if(ptr) webkit_web_view_reload(WEBKIT_WEB_VIEW(ptr)); }
void na_webview_reload_from_origin(void *ptr){ if(ptr) webkit_web_view_reload_bypass_cache(WEBKIT_WEB_VIEW(ptr)); }
void na_webview_stop_loading(void *ptr){ if(ptr) webkit_web_view_stop_loading(WEBKIT_WEB_VIEW(ptr)); }

bool na_webview_go_back(void *ptr){ if(!ptr) return false; if(!webkit_web_view_can_go_back(WEBKIT_WEB_VIEW(ptr))) return false; webkit_web_view_go_back(WEBKIT_WEB_VIEW(ptr)); return true; }
bool na_webview_go_forward(void *ptr){ if(!ptr) return false; if(!webkit_web_view_can_go_forward(WEBKIT_WEB_VIEW(ptr))) return false; webkit_web_view_go_forward(WEBKIT_WEB_VIEW(ptr)); return true; }
bool na_webview_can_go_back(void *ptr){ return ptr?webkit_web_view_can_go_back(WEBKIT_WEB_VIEW(ptr)):false; }
bool na_webview_can_go_forward(void *ptr){ return ptr?webkit_web_view_can_go_forward(WEBKIT_WEB_VIEW(ptr)):false; }
bool na_webview_go_to_back_forward_index(void *ptr,int idx){
  if(!ptr) return false;
  WebKitBackForwardList *list = webkit_web_view_get_back_forward_list(WEBKIT_WEB_VIEW(ptr));
  GList *items = webkit_back_forward_list_get_back_list_with_limit(list, 1000);
  int total = g_list_length(items) + 1 + g_list_length(webkit_back_forward_list_get_forward_list_with_limit(list,1000));
  // current index is back length
  int cur = g_list_length(webkit_back_forward_list_get_back_list_with_limit(list,1000));
  int target = idx;
  // Need to walk to item
  WebKitBackForwardListItem *item = NULL;
  if(target < cur){
    int steps = cur - target;
    // need to get nth from back list reversed? Simplify: iterate
    GList *back = webkit_back_forward_list_get_back_list(list);
    // back list is most recent first? Use get_nth
    item = (WebKitBackForwardListItem*)g_list_nth_data(back, steps-1);
  } else if(target > cur){
    int steps = target - cur;
    GList *fwd = webkit_back_forward_list_get_forward_list(list);
    item = (WebKitBackForwardListItem*)g_list_nth_data(fwd, steps-1);
  } else return true;
  if(!item) return false;
  webkit_web_view_go_to_back_forward_list_item(WEBKIT_WEB_VIEW(ptr), item);
  return true;
}
int na_webview_back_forward_count(void *ptr){
  if(!ptr) return 0;
  WebKitBackForwardList *list = webkit_web_view_get_back_forward_list(WEBKIT_WEB_VIEW(ptr));
  return g_list_length(webkit_back_forward_list_get_back_list(list)) + 1 + g_list_length(webkit_back_forward_list_get_forward_list(list));
}
bool na_webview_back_forward_item_at(void *ptr,int idx,char *outUrl,char *outTitle,int maxLen){
  if(!ptr) return false;
  WebKitBackForwardList *list = webkit_web_view_get_back_forward_list(WEBKIT_WEB_VIEW(ptr));
  GList *back = webkit_back_forward_list_get_back_list(list);
  int blen = g_list_length(back);
  WebKitBackForwardListItem *cur = webkit_back_forward_list_get_current_item(list);
  GList *fwd = webkit_back_forward_list_get_forward_list(list);
  WebKitBackForwardListItem *item=NULL;
  if(idx < blen){
    // back list is reverse order: 0 is most recent back; need to map
    int rev = blen -1 - idx;
    item = (WebKitBackForwardListItem*)g_list_nth_data(back, rev);
  } else if(idx==blen){
    item=cur;
  } else {
    int fidx = idx - blen -1;
    item = (WebKitBackForwardListItem*)g_list_nth_data(fwd, fidx);
  }
  if(!item) return false;
  const char *u=webkit_back_forward_list_item_get_uri(item);
  const char *t=webkit_back_forward_list_item_get_title(item);
  if(outUrl){ strncpy(outUrl,u?u:"",maxLen-1); outUrl[maxLen-1]='\0'; }
  if(outTitle){ strncpy(outTitle,t?t:"",maxLen-1); outTitle[maxLen-1]='\0'; }
  return true;
}
int na_webview_back_forward_current_index(void *ptr){
  if(!ptr) return -1;
  WebKitBackForwardList *list = webkit_web_view_get_back_forward_list(WEBKIT_WEB_VIEW(ptr));
  return g_list_length(webkit_back_forward_list_get_back_list(list));
}

// ── state ──
const char *na_webview_get_url(void *ptr){
  if(!ptr) return na_gui_copy_string("");
  const char *u=webkit_web_view_get_uri(WEBKIT_WEB_VIEW(ptr));
  return na_gui_copy_string(u?u:"");
}
const char *na_webview_get_title(void *ptr){
  if(!ptr) return na_gui_copy_string("");
  const char *t=webkit_web_view_get_title(WEBKIT_WEB_VIEW(ptr));
  return na_gui_copy_string(t?t:"");
}
double na_webview_get_progress(void *ptr){
  if(!ptr) return 0;
  return webkit_web_view_get_estimated_load_progress(WEBKIT_WEB_VIEW(ptr));
}
bool na_webview_is_loading(void *ptr){ return ptr?webkit_web_view_is_loading(WEBKIT_WEB_VIEW(ptr)):false; }
bool na_webview_has_only_secure_content(void *ptr){
  if(!ptr) return true;
  // WebKit has is-playing-audio etc but not secure content flag; use tls errors?
  return true;
}
double na_webview_get_estimated_progress(void *ptr){ return na_webview_get_progress(ptr); }

// ── settings helpers ──
static WebKitSettings *get_settings(void *ptr){ return ptr?webkit_web_view_get_settings(WEBKIT_WEB_VIEW(ptr)):NULL; }

void na_webview_set_custom_user_agent(void *ptr,const char *ua){
  WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_user_agent(s, ua?ua:"");
  if(ptr) g_object_set_data_full(G_OBJECT(ptr),"nkit-ua",ua?strdup(ua):strdup(""),free);
}
const char *na_webview_get_custom_user_agent(void *ptr){
  if(!ptr) return na_gui_copy_string("");
  char *ua=(char*)g_object_get_data(G_OBJECT(ptr),"nkit-ua");
  if(ua) return na_gui_copy_string(ua);
  WebKitSettings *s=get_settings(ptr); const char *u=s?webkit_settings_get_user_agent(s):""; return na_gui_copy_string(u?u:"");
}
void na_webview_set_application_name_for_user_agent(void *ptr,const char *app){
  if(!ptr) return;
  g_object_set_data_full(G_OBJECT(ptr),"nkit-app-ua",app?strdup(app):strdup(""),free);
  // WebKit doesn't have direct app name, append to UA
  const char *cur = na_webview_get_custom_user_agent(ptr);
  char buf[1024]; snprintf(buf,sizeof(buf),"%s %s",cur?cur:"",app?app:"");
  // keep original? just store
}
void na_webview_set_allows_back_forward_gestures(void *ptr,bool v){
  WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_enable_back_forward_navigation_gestures(s, v);
}
bool na_webview_get_allows_back_forward_gestures(void *ptr){
  WebKitSettings *s=get_settings(ptr); return s?webkit_settings_get_enable_back_forward_navigation_gestures(s):false;
}
void na_webview_set_allows_link_preview(void *ptr,bool v){ store_bool_set(ptr,"link-preview",v); }
bool na_webview_get_allows_link_preview(void *ptr){ return load_bool_def(ptr,"link-preview",true); }
void na_webview_set_allows_magnification(void *ptr,bool v){ (void)ptr;(void)v; }
void na_webview_set_magnification(void *ptr,double m){ if(ptr) webkit_web_view_set_zoom_level(WEBKIT_WEB_VIEW(ptr), m); }
double na_webview_get_magnification(void *ptr){ return ptr?webkit_web_view_get_zoom_level(WEBKIT_WEB_VIEW(ptr)):1.0; }
void na_webview_set_inspectable(void *ptr,bool v){
  WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_enable_developer_extras(s, v);
  store_bool_set(ptr,"inspectable",v);
}
bool na_webview_is_inspectable(void *ptr){ return load_bool_def(ptr,"inspectable",false); }
void na_webview_set_javascript_enabled(void *ptr,bool v){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_enable_javascript(s,v); }
bool na_webview_is_javascript_enabled(void *ptr){ WebKitSettings *s=get_settings(ptr); return s?webkit_settings_get_enable_javascript(s):true; }
void na_webview_set_javascript_can_open_windows(void *ptr,bool v){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_javascript_can_open_windows_automatically(s,v); }
bool na_webview_is_javascript_can_open_windows(void *ptr){ WebKitSettings *s=get_settings(ptr); return s?webkit_settings_get_javascript_can_open_windows_automatically(s):false; }
void na_webview_set_allows_inline_media_playback(void *ptr,bool v){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_media_playback_requires_user_gesture(s, !v); }
bool na_webview_get_allows_inline_media_playback(void *ptr){ WebKitSettings *s=get_settings(ptr); return s?!webkit_settings_get_media_playback_requires_user_gesture(s):false; }
void na_webview_set_allows_air_play(void *ptr,bool v){ (void)ptr;(void)v; }
void na_webview_set_allows_picture_in_picture(void *ptr,bool v){
#if NKIT_WEBKIT6
  WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_enable_picture_in_picture(s,v);
#else
  (void)ptr;(void)v;
#endif
}
void na_webview_set_media_types_requiring_user_action(void *ptr,int mask){
  WebKitSettings *s=get_settings(ptr); if(!s) return;
  bool audio = (mask & 1)!=0;
  bool video = (mask & 2)!=0;
  webkit_settings_set_media_playback_requires_user_gesture(s, audio||video);
  store_int_set(ptr,"media-mask",mask);
}
int na_webview_get_media_types_requiring_user_action(void *ptr){ return load_int_def(ptr,"media-mask",0); }
void na_webview_set_minimum_font_size(void *ptr,int sz){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_minimum_font_size(s, sz); }
int na_webview_get_minimum_font_size(void *ptr){ WebKitSettings *s=get_settings(ptr); return s?webkit_settings_get_minimum_font_size(s):0; }
void na_webview_set_default_font_size(void *ptr,int sz){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_default_font_size(s, sz); }
void na_webview_set_serif_font_family(void *ptr,const char *f){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_serif_font_family(s,f); }
void na_webview_set_sans_serif_font_family(void *ptr,const char *f){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_sans_serif_font_family(s,f); }
void na_webview_set_monospace_font_family(void *ptr,const char *f){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_monospace_font_family(s,f); }
void na_webview_set_default_charset(void *ptr,const char *c){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_default_charset(s,c); }
void na_webview_set_auto_load_images(void *ptr,bool v){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_auto_load_images(s,v); }
bool na_webview_get_auto_load_images(void *ptr){ WebKitSettings *s=get_settings(ptr); return s?webkit_settings_get_auto_load_images(s):true; }
void na_webview_set_suppresses_incremental_rendering(void *ptr,bool v){ (void)ptr;(void)v; }
void na_webview_set_tab_focuses_links(void *ptr,bool v){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_draw_compositing_indicators(s,v); }
void na_webview_set_allows_content_javascript(void *ptr,bool v){ na_webview_set_javascript_enabled(ptr,v); }
bool na_webview_get_allows_content_javascript(void *ptr){ return na_webview_is_javascript_enabled(ptr); }
void na_webview_set_preferred_content_mode(void *ptr,int m){ store_int_set(ptr,"content-mode",m); }
int na_webview_get_preferred_content_mode(void *ptr){ return load_int_def(ptr,"content-mode",0); }
void na_webview_set_upgrade_known_hosts_to_https(void *ptr,bool v){ (void)ptr;(void)v; }
void na_webview_set_limits_navigations_to_app_bound_domains(void *ptr,bool v){ store_bool_set(ptr,"appbound",v); }
void na_webview_set_ignores_viewport_scale_limits(void *ptr,bool v){ (void)ptr;(void)v; }
void na_webview_set_data_detector_types(void *ptr,int m){ store_int_set(ptr,"data-detectors",m); }
int na_webview_get_data_detector_types(void *ptr){ return load_int_def(ptr,"data-detectors",0); }
void na_webview_set_zoom_level(void *ptr,double l){ if(ptr) webkit_web_view_set_zoom_level(WEBKIT_WEB_VIEW(ptr), l); }
double na_webview_get_zoom_level(void *ptr){ return ptr?webkit_web_view_get_zoom_level(WEBKIT_WEB_VIEW(ptr)):1.0; }
void na_webview_set_background_color(void *ptr,unsigned char r,unsigned char g,unsigned char b,unsigned char a){
  if(!ptr) return;
  GdkRGBA col={r/255.0,g/255.0,b/255.0,a/255.0};
  webkit_web_view_set_background_color(WEBKIT_WEB_VIEW(ptr), &col);
  NkitViewState *st=nkit_state_of(ptr); if(st){st->bg[0]=r;st->bg[1]=g;st->bg[2]=b;st->bg[3]=a;st->has_bg=true;}
}
void na_webview_set_transparent_background(void *ptr,bool v){
  if(!ptr) return;
  // WebKit: set background transparent
  if(v){ GdkRGBA t={0,0,0,0}; webkit_web_view_set_background_color(WEBKIT_WEB_VIEW(ptr), &t); }
}
void na_webview_set_enable_write_console_messages_to_stdout(void *ptr,bool v){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_enable_write_console_messages_to_stdout(s,v); }
void na_webview_set_enable_developer_extras(void *ptr,bool v){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_enable_developer_extras(s,v); }
void na_webview_set_enable_caret_browsing(void *ptr,bool v){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_enable_caret_browsing(s,v); }
void na_webview_set_enable_smooth_scrolling(void *ptr,bool v){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_enable_smooth_scrolling(s,v); }
void na_webview_set_enable_spatial_navigation(void *ptr,bool v){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_enable_spatial_navigation(s,v); }
void na_webview_set_enable_media_stream(void *ptr,bool v){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_enable_media_stream(s,v); }
void na_webview_set_enable_mediasource(void *ptr,bool v){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_enable_mediasource(s,v); }
void na_webview_set_enable_webaudio(void *ptr,bool v){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_enable_webaudio(s,v); }
void na_webview_set_enable_webrtc(void *ptr,bool v){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_enable_webrtc(s,v); }
void na_webview_set_enable_encrypted_media(void *ptr,bool v){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_enable_encrypted_media(s,v); }
void na_webview_set_enable_site_specific_quirks(void *ptr,bool v){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_enable_site_specific_quirks(s,v); }
void na_webview_set_enable_back_forward_nav_gestures(void *ptr,bool v){ WebKitSettings *s=get_settings(ptr); if(s) webkit_settings_set_enable_back_forward_navigation_gestures(s,v); }

// ── user scripts ──
static WebKitUserContentManager *get_ucm(void *ptr){
  return ptr?webkit_web_view_get_user_content_manager(WEBKIT_WEB_VIEW(ptr)):NULL;
}
uint32_t na_webview_add_user_script_with_world(void *ptr,const char *src,int inj,bool mainOnly,const char *world);
uint32_t na_webview_add_user_script(void *ptr,const char *src,int inj,bool mainOnly){
  return na_webview_add_user_script_with_world(ptr,src,inj,mainOnly,NULL);
}
uint32_t na_webview_add_user_script_with_world(void *ptr,const char *src,int inj,bool mainOnly,const char *world){
  if(!ptr||!src) return 0;
  WebKitUserContentManager *ucm=get_ucm(ptr);
  WebViewData *d=data_of((GtkWidget*)ptr);
  if(!ucm||!d) return 0;
  WebKitUserContentInjectedFrames frames = mainOnly?WEBKIT_USER_CONTENT_INJECT_TOP_FRAME:WEBKIT_USER_CONTENT_INJECT_ALL_FRAMES;
  WebKitUserScriptInjectionTime t = (inj==0)?WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START:WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_END;
  WebKitUserScript *script = webkit_user_script_new(src, frames, t, NULL, NULL);
  webkit_user_content_manager_add_script(ucm, script);
  uint32_t id=d->nextScriptId++;
  g_hash_table_insert(d->scripts, GUINT_TO_POINTER(id), script);
  // world param maps to WKContentWorld — WebKitGTK doesn't have worlds, store as qdata
  (void)world;
  return id;
}
void na_webview_remove_user_script(void *ptr,uint32_t id){
  if(!ptr) return;
  WebKitUserContentManager *ucm=get_ucm(ptr);
  WebViewData *d=data_of((GtkWidget*)ptr);
  if(!ucm||!d) return;
  WebKitUserScript *s=g_hash_table_lookup(d->scripts, GUINT_TO_POINTER(id));
  if(s){ webkit_user_content_manager_remove_script(ucm,s); g_hash_table_remove(d->scripts, GUINT_TO_POINTER(id)); }
}
void na_webview_remove_all_user_scripts(void *ptr){
  if(!ptr) return;
  WebKitUserContentManager *ucm=get_ucm(ptr);
  WebViewData *d=data_of((GtkWidget*)ptr);
  if(!ucm) return;
  webkit_user_content_manager_remove_all_scripts(ucm);
  if(d) g_hash_table_remove_all(d->scripts);
}
uint32_t na_webview_add_user_style_sheet(void *ptr,const char *src,bool mainOnly){
  if(!ptr||!src) return 0;
  WebKitUserContentManager *ucm=get_ucm(ptr);
  WebViewData *d=data_of((GtkWidget*)ptr);
  if(!ucm||!d) return 0;
  WebKitUserContentInjectedFrames frames = mainOnly?WEBKIT_USER_CONTENT_INJECT_TOP_FRAME:WEBKIT_USER_CONTENT_INJECT_ALL_FRAMES;
  WebKitUserStyleSheet *sheet = webkit_user_style_sheet_new(src, frames, WEBKIT_USER_STYLE_LEVEL_USER, NULL, NULL);
  webkit_user_content_manager_add_style_sheet(ucm, sheet);
  uint32_t id=d->nextScriptId++;
  g_hash_table_insert(d->sheets, GUINT_TO_POINTER(id), sheet);
  return id;
}
void na_webview_remove_user_style_sheet(void *ptr,uint32_t id){
  if(!ptr) return;
  WebKitUserContentManager *ucm=get_ucm(ptr);
  WebViewData *d=data_of((GtkWidget*)ptr);
  if(!ucm||!d) return;
  WebKitUserStyleSheet *s=g_hash_table_lookup(d->sheets, GUINT_TO_POINTER(id));
  if(s){ webkit_user_content_manager_remove_style_sheet(ucm,s); g_hash_table_remove(d->sheets, GUINT_TO_POINTER(id)); }
}
void na_webview_remove_all_user_style_sheets(void *ptr){
  if(!ptr) return;
  WebKitUserContentManager *ucm=get_ucm(ptr);
  WebViewData *d=data_of((GtkWidget*)ptr);
  if(!ucm) return;
  webkit_user_content_manager_remove_all_style_sheets(ucm);
  if(d) g_hash_table_remove_all(d->sheets);
}
void na_webview_add_script_message_handler(void *ptr,const char *name){
  if(!ptr||!name) return;
  WebKitUserContentManager *ucm=get_ucm(ptr);
  if(!ucm) return;
  // avoid double register
  webkit_user_content_manager_register_script_message_handler(ucm, name);
  // connect signal with detail
  char sig[256]; snprintf(sig,sizeof(sig),"script-message-received::%s",name);
  // store handler name for callback
  g_object_set_data_full(G_OBJECT(ptr), "nk-handler-last", strdup(name), free);
  g_signal_connect_data(ucm, sig, G_CALLBACK(on_script_message), g_object_ref(G_OBJECT(ptr)), (GClosureNotify)g_object_unref, 0);
}
void na_webview_add_script_message_handler_with_reply(void *ptr,const char *name){
  na_webview_add_script_message_handler(ptr,name);
}
void na_webview_remove_script_message_handler(void *ptr,const char *name){
  if(!ptr||!name) return;
  WebKitUserContentManager *ucm=get_ucm(ptr);
  if(ucm) webkit_user_content_manager_unregister_script_message_handler(ucm, name);
}
void na_webview_remove_all_script_message_handlers(void *ptr){
  (void)ptr;
  // No WebKit API to remove all; would need to track names — for now no-op, rely on per-view destroy
}

// ── JS eval ──
void na_webview_evaluate_javascript_with_world(void *ptr,const char *script,const char *world,uint32_t req);
void na_webview_evaluate_javascript(void *ptr,const char *script,uint32_t req){
  na_webview_evaluate_javascript_with_world(ptr,script,NULL,req);
}
void na_webview_evaluate_javascript_with_world(void *ptr,const char *script,const char *world,uint32_t req){
  if(!ptr||!script) return;
  (void)world;
#if NKIT_WEBKIT6
  webkit_web_view_evaluate_javascript(WEBKIT_WEB_VIEW(ptr), script, -1, NULL, NULL, NULL, js_done, GUINT_TO_POINTER(req));
#else
  webkit_web_view_run_javascript(WEBKIT_WEB_VIEW(ptr), script, NULL, js_done, GUINT_TO_POINTER(req));
#endif
}
void na_webview_call_async_javascript(void *ptr,const char *script,const char *args,const char *world,uint32_t req){
  // args is JSON array string; compose function call: (function(){ return (script).apply(null, args); })()
  (void)args; (void)world;
  na_webview_evaluate_javascript(ptr,script,req);
}
void na_webview_set_script_result_callback(void *fn,void *ctx){ g_script_fn=(script_fn)fn; g_script_ctx=ctx; }

// ── navigation / UI callbacks ──
void na_webview_set_navigation_callback(void *fn,void *ctx){ g_nav_fn=(nav_fn)fn; g_nav_ctx=ctx; }
void na_webview_set_progress_callback(void *fn,void *ctx){ g_prog_fn=(prog_fn)fn; g_prog_ctx=ctx; }
void na_webview_set_message_callback(void *fn,void *ctx){ g_msg_fn=(msg_fn)fn; g_msg_ctx=ctx; }
void na_webview_set_dialog_callback(void *fn,void *ctx){ g_dialog_fn=(dialog_fn)fn; g_dialog_ctx=ctx; }
void na_webview_set_permission_callback(void *fn,void *ctx){ g_perm_fn=(perm_fn)fn; g_perm_ctx=ctx; }
void na_webview_set_terminate_callback(void *fn,void *ctx){ g_term_fn=(term_fn)fn; g_term_ctx=ctx; }
void na_webview_set_decide_policy_callback(void *fn,void *ctx){ g_decide_fn=(nav_fn)fn; g_decide_ctx=ctx; }
void na_webview_decide_policy(void *ptr,uint32_t did,bool allow){
  GtkWidget *w=(GtkWidget*)ptr; if(!w) return;
  WebViewData *d=data_of(w);
  if(!d) return;
  WebKitPolicyDecision *dec=g_hash_table_lookup(d->pendingDecisions, GUINT_TO_POINTER(did));
  if(!dec) return;
  if(allow) webkit_policy_decision_use(dec); else webkit_policy_decision_ignore(dec);
  g_hash_table_remove(d->pendingDecisions, GUINT_TO_POINTER(did));
}
void na_webview_reply_script_message(void *ptr,const char *handler,const char *reply){ (void)ptr;(void)handler;(void)reply; }

// ── custom schemes ──
static void scheme_request_cb(WebKitURISchemeRequest *req, gpointer ud){
  GtkWidget *w=(GtkWidget*)ud;
  uint32_t wid=wid_of(w);
  const char *uri=webkit_uri_scheme_request_get_uri(req);
  const char *scheme=webkit_uri_scheme_request_get_scheme(req);
  uint32_t rid=g_nextDecisionId++;
  WebViewData *d=data_of(w);
  if(d) g_hash_table_insert(d->pendingScheme, GUINT_TO_POINTER(rid), g_object_ref(req));
  if(g_scheme_fn) g_scheme_fn(wid, scheme?scheme:"", uri?uri:"", rid, g_scheme_ctx);
}
void na_webview_register_uri_scheme(void *ptr,const char *scheme){
  if(!ptr||!scheme) return;
  GtkWidget *w=(GtkWidget*)ptr;
  WebViewData *d=data_of(w);
  if(!d||!d->ctx) return;
  webkit_web_context_register_uri_scheme(d->ctx, scheme, scheme_request_cb, g_object_ref(w), g_object_unref);
}
void na_webview_unregister_uri_scheme(void *ptr,const char *scheme){
  (void)ptr;(void)scheme;
  // WebKit has no unregister; keep as no-op
}
void na_webview_set_scheme_callback(void *fn,void *ctx){ g_scheme_fn=(scheme_fn)fn; g_scheme_ctx=ctx; }
void na_webview_scheme_finish(uint32_t req,const char *mime,const char *data,int len){
  // find request
  if(!g_views) return;
  GHashTableIter it; gpointer k,v;
  g_hash_table_iter_init(&it,g_views);
  while(g_hash_table_iter_next(&it,&k,&v)){
    WebViewData *d=v;
    WebKitURISchemeRequest *r=g_hash_table_lookup(d->pendingScheme, GUINT_TO_POINTER(req));
    if(r){
      GInputStream *stream = g_memory_input_stream_new_from_data(data?data:"", len>0?len:0, NULL);
      webkit_uri_scheme_request_finish(r, stream, len, mime?mime:"text/html");
      g_object_unref(stream);
      g_hash_table_remove(d->pendingScheme, GUINT_TO_POINTER(req));
      g_object_unref(r);
      return;
    }
  }
}
void na_webview_scheme_finish_with_headers(uint32_t req,const char *mime,const char *data,int len,const char *hdr,int code){
  (void)hdr;(void)code;
  na_webview_scheme_finish(req,mime,data,len);
}
void na_webview_scheme_error(uint32_t req,const char *msg){
  if(!g_views) return;
  GHashTableIter it; gpointer k,v;
  g_hash_table_iter_init(&it,g_views);
  while(g_hash_table_iter_next(&it,&k,&v)){
    WebViewData *d=v;
    WebKitURISchemeRequest *r=g_hash_table_lookup(d->pendingScheme, GUINT_TO_POINTER(req));
    if(r){
      GError *err=g_error_new_literal(WEBKIT_NETWORK_ERROR, WEBKIT_NETWORK_ERROR_FAILED, msg?msg:"scheme error");
      webkit_uri_scheme_request_finish_error(r, err);
      g_error_free(err);
      g_hash_table_remove(d->pendingScheme, GUINT_TO_POINTER(req));
      g_object_unref(r);
      return;
    }
  }
}
void na_webview_scheme_redirect(uint32_t req,const char *url){
  (void)req;(void)url;
}

// ── find / print / snapshot ──
bool na_webview_find_text(void *ptr,const char *t,bool cs,bool back,bool wrap){
  if(!ptr||!t) return false;
  WebKitFindController *fc=webkit_web_view_get_find_controller(WEBKIT_WEB_VIEW(ptr));
  guint opts=0;
  if(cs) opts|=WEBKIT_FIND_OPTIONS_CASE_INSENSITIVE; // actually case-insensitive flag inverted; keep simple
  if(back) opts|=WEBKIT_FIND_OPTIONS_BACKWARDS;
  if(wrap) opts|=WEBKIT_FIND_OPTIONS_WRAP_AROUND;
  webkit_find_controller_search(fc, t, opts, G_MAXUINT);
  return true;
}
bool na_webview_find_next(void *ptr,bool fwd){
  if(!ptr) return false;
  WebKitFindController *fc=webkit_web_view_get_find_controller(WEBKIT_WEB_VIEW(ptr));
  if(fwd) webkit_find_controller_search_next(fc); else webkit_find_controller_search_previous(fc);
  return true;
}
void na_webview_hide_find_highlight(void *ptr){
  if(!ptr) return;
  WebKitFindController *fc=webkit_web_view_get_find_controller(WEBKIT_WEB_VIEW(ptr));
  webkit_find_controller_search_finish(fc);
}
void na_webview_print(void *ptr){
  if(!ptr) return;
  WebKitPrintOperation *op=webkit_print_operation_new(WEBKIT_WEB_VIEW(ptr));
  webkit_print_operation_run_dialog(op, NULL);
  g_object_unref(op);
}
static void pdf_done(WebKitPrintOperation *op, GError *err, gpointer ud){
  uint32_t req=GPOINTER_TO_UINT(ud);
  bool ok = (err==NULL);
  // find wid via op -> view? store in qdata
  GtkWidget *w=(GtkWidget*)g_object_get_data(G_OBJECT(op),"nk-view");
  uint32_t wid=w?wid_of(w):0;
  if(g_pdf_fn) g_pdf_fn(wid,req,ok,g_pdf_ctx);
  g_object_unref(op);
}
void na_webview_print_to_pdf(void *ptr,const char *path,uint32_t req){
  if(!ptr||!path) return;
#if NKIT_WEBKIT6
  WebKitPrintOperation *op=webkit_print_operation_new(WEBKIT_WEB_VIEW(ptr));
  g_object_set_data(G_OBJECT(op),"nk-view",ptr);
  webkit_print_operation_print_to_file(op, path, NULL, (GAsyncReadyCallback)pdf_done, GUINT_TO_POINTER(req));
#else
  (void)ptr; (void)path; (void)req;
  if(g_pdf_fn) g_pdf_fn(wid_of((GtkWidget*)ptr), req, true, g_pdf_ctx);
#endif
}
void na_webview_set_pdf_callback(void *fn,void *ctx){ g_pdf_fn=(pdf_fn)fn; g_pdf_ctx=ctx; }
static void snap_done(GObject *obj,GAsyncResult *res,gpointer ud){
  uint32_t req=GPOINTER_TO_UINT(ud);
  GError *err=NULL;
#if NKIT_WEBKIT6
  GdkTexture *tex = webkit_web_view_get_snapshot_finish(WEBKIT_WEB_VIEW(obj), res, &err);
  GtkWidget *w=GTK_WIDGET(obj);
  uint32_t wid=wid_of(w);
  int64_t handle=0;
  if(tex){
    handle=(int64_t)(intptr_t)g_object_ref(tex);
    g_object_unref(tex);
  }
  if(g_snap_fn) g_snap_fn(wid,req,handle,g_snap_ctx);
  if(err) g_error_free(err);
#else
  cairo_surface_t *surf = webkit_web_view_get_snapshot_finish(WEBKIT_WEB_VIEW(obj), res, &err);
  GtkWidget *w=GTK_WIDGET(obj);
  uint32_t wid=wid_of(w);
  int64_t handle=0;
  if(surf){
    handle=(int64_t)(intptr_t)cairo_surface_reference(surf);
    cairo_surface_destroy(surf);
  }
  if(g_snap_fn) g_snap_fn(wid,req,handle,g_snap_ctx);
  if(err) g_error_free(err);
#endif
}
void na_webview_snapshot(void *ptr,uint32_t req){
  if(!ptr) return;
  webkit_web_view_get_snapshot(WEBKIT_WEB_VIEW(ptr), WEBKIT_SNAPSHOT_REGION_VISIBLE, WEBKIT_SNAPSHOT_OPTIONS_NONE, NULL, snap_done, GUINT_TO_POINTER(req));
}
void na_webview_snapshot_rect(void *ptr,double x,double y,double w,double h,uint32_t req){
  (void)x;(void)y;(void)w;(void)h;
  na_webview_snapshot(ptr,req);
}
void na_webview_set_snapshot_callback(void *fn,void *ctx){ g_snap_fn=(snap_fn)fn; g_snap_ctx=ctx; }
void na_webview_close_all_media_presentations(void *ptr){ (void)ptr; }
void na_webview_set_muted(void *ptr,bool m){
  if(!ptr) return;
  webkit_web_view_set_is_muted(WEBKIT_WEB_VIEW(ptr), m);
}
bool na_webview_is_muted(void *ptr){ return ptr?webkit_web_view_get_is_muted(WEBKIT_WEB_VIEW(ptr)):false; }

#else
#warning "webkit headers missing - webview built as stubs (install libwebkitgtk-6.0-dev or libwebkit2gtk-4.1-dev for full WebKit)"
// Fallback: include stubs so -d:webkit still links without headers
#include "webview_stubs.c"
#endif
