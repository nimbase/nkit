#include <gtk/gtk.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>
#include "gui_common.h"
#include "na_compat.h"

// Stubs for all na_webview* / na_web_context* symbols.
// Used when compiled without -d:webkit (opt-in). Keeps Nim linking green
// and provides in-memory round-trips via GObject qdata so tests run headless.

static void *g_nav_ctx = NULL;
static void *g_prog_ctx = NULL;
static void *g_msg_ctx = NULL;
static void *g_dialog_ctx = NULL;
static void *g_perm_ctx = NULL;
static void *g_term_ctx = NULL;
static void *g_decide_ctx = NULL;
static void *g_scheme_ctx = NULL;
static void *g_script_ctx = NULL;
static void *g_cookie_ctx = NULL;
static void *g_data_ctx = NULL;
static void *g_pdf_ctx = NULL;
static void *g_snap_ctx = NULL;

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

static nav_fn    g_nav_fn = NULL;
static prog_fn   g_prog_fn = NULL;
static msg_fn    g_msg_fn = NULL;
static dialog_fn g_dialog_fn = NULL;
static perm_fn   g_perm_fn = NULL;
static term_fn   g_term_fn = NULL;
static nav_fn    g_decide_fn = NULL;
static scheme_fn g_scheme_fn = NULL;
static script_fn g_script_fn = NULL;
static cookie_fn g_cookie_fn = NULL;
static data_fn   g_data_fn = NULL;
static pdf_fn    g_pdf_fn = NULL;
static snap_fn   g_snap_fn = NULL;

// ── helpers: per-widget storage via GObject qdata ──
static void store_str(GtkWidget *w, const char *key, const char *v){
  char *dup = v ? strdup(v) : strdup("");
  g_object_set_data_full(G_OBJECT(w), key, dup, free);
}
static const char *load_str(GtkWidget *w, const char *key){
  char *s = (char*)g_object_get_data(G_OBJECT(w), key);
  return s ? na_gui_copy_string(s) : na_gui_copy_string("");
}
static void store_bool(GtkWidget *w, const char *key, bool v){
  g_object_set_data(G_OBJECT(w), key, GINT_TO_POINTER(v?2:1));
}
static bool load_bool(GtkWidget *w, const char *key, bool def){
  char flag[256]; snprintf(flag,sizeof(flag),"%s-set",key);
  if(!g_object_get_data(G_OBJECT(w), flag)) return def;
  gpointer p = g_object_get_data(G_OBJECT(w), key);
  return GPOINTER_TO_INT(p)==2;
}
static void store_bool_set(GtkWidget *w, const char *key, bool v){
  g_object_set_data(G_OBJECT(w), key, GINT_TO_POINTER(v?2:1));
  char flag[256]; snprintf(flag,sizeof(flag),"%s-set",key);
  g_object_set_data(G_OBJECT(w), flag, GINT_TO_POINTER(1));
}
static void store_int(GtkWidget *w, const char *key, int v){
  g_object_set_data(G_OBJECT(w), key, GINT_TO_POINTER(v));
}
static int load_int(GtkWidget *w, const char *key, int def){
  gpointer p = g_object_get_data(G_OBJECT(w), key);
  char flag[256]; snprintf(flag,sizeof(flag),"%s-set",key);
  if(!g_object_get_data(G_OBJECT(w), flag)) return def;
  return GPOINTER_TO_INT(p);
}
static void store_int_set(GtkWidget *w, const char *key, int v){
  g_object_set_data(G_OBJECT(w), key, GINT_TO_POINTER(v));
  char flag[256]; snprintf(flag,sizeof(flag),"%s-set",key);
  g_object_set_data(G_OBJECT(w), flag, GINT_TO_POINTER(1));
}
static void store_double(GtkWidget *w, const char *key, double v){
  double *p = malloc(sizeof(double)); *p=v;
  g_object_set_data_full(G_OBJECT(w), key, p, free);
}
static double load_double(GtkWidget *w, const char *key, double def){
  double *p = g_object_get_data(G_OBJECT(w), key);
  return p?*p:def;
}

// ── WebContext dummy ──
typedef struct { bool ephemeral; bool cache; bool diskCache; bool itp; int tlsPolicy; int cookiePolicy; char *storagePath; } DummyCtx;
void *na_web_context_create(void){
  DummyCtx *c=calloc(1,sizeof(DummyCtx)); c->cache=true; c->diskCache=true; c->cookiePolicy=0; return c;
}
void *na_web_context_create_ephemeral(void){
  DummyCtx *c=calloc(1,sizeof(DummyCtx)); c->ephemeral=true; return c;
}
void na_web_context_free(void *ctx){ DummyCtx *c=ctx; if(!c) return; free(c->storagePath); free(c); }
void na_web_context_set_cache_enabled(void *ctx,bool v){ if(ctx) ((DummyCtx*)ctx)->cache=v; }
void na_web_context_set_disk_cache_enabled(void *ctx,bool v){ if(ctx) ((DummyCtx*)ctx)->diskCache=v; }
void na_web_context_clear_website_data(void *ctx,int mask){ (void)ctx;(void)mask; }
void na_web_context_fetch_data_records(void *ctx,int mask,uint32_t req){ (void)ctx;(void)mask; if(g_data_fn) g_data_fn(req,"[]",g_data_ctx); }
void na_web_context_set_itp_enabled(void *ctx,bool v){ if(ctx) ((DummyCtx*)ctx)->itp=v; }
void na_web_context_set_tls_errors_policy(void *ctx,int p){ if(ctx) ((DummyCtx*)ctx)->tlsPolicy=p; }
void na_web_context_set_data_records_callback(void *fn,void *ctx){ g_data_fn=(data_fn)fn; g_data_ctx=ctx; }
void na_web_context_cookie_set(void *ctx,const char *url,const char *cookie){ (void)ctx;(void)url;(void)cookie; }
const char *na_web_context_cookie_get(void *ctx,const char *url){ (void)ctx;(void)url; return na_gui_copy_string(""); }
void na_web_context_cookie_delete(void *ctx,const char *url,const char *name){ (void)ctx;(void)url;(void)name; }
void na_web_context_cookie_get_all(void *ctx,uint32_t req){ (void)ctx; if(g_cookie_fn) g_cookie_fn(req,"[]",g_cookie_ctx); }
void na_web_context_set_cookie_callback(void *fn,void *ctx){ g_cookie_fn=(cookie_fn)fn; g_cookie_ctx=ctx; }
void na_web_context_set_cookie_accept_policy(void *ctx,int p){ if(ctx) ((DummyCtx*)ctx)->cookiePolicy=p; }
int  na_web_context_get_cookie_accept_policy(void *ctx){ return ctx?((DummyCtx*)ctx)->cookiePolicy:0; }
void na_web_context_set_persistent_storage_path(void *ctx,const char *path){ if(!ctx) return; DummyCtx *c=ctx; free(c->storagePath); c->storagePath=path?strdup(path):NULL; }

// ── WebView stubs ──
static GtkWidget *make_view(uint32_t wid){
  na_linux_ensure_gtk();
  GtkWidget *v = gtk_fixed_new();
  g_object_set_data(G_OBJECT(v),"nkit-id",GUINT_TO_POINTER(wid));
  g_object_set_data(G_OBJECT(v),"nkit-url",strdup(""));
  g_object_set_data_full(G_OBJECT(v),"nkit-url",strdup(""),free);
  g_object_set_data_full(G_OBJECT(v),"nkit-title",strdup(""),free);
  g_object_set_data_full(G_OBJECT(v),"nkit-ua",strdup(""),free);
  g_object_set_data_full(G_OBJECT(v),"nkit-app-ua",strdup(""),free);
  // defaults matching WKWebView
  store_bool_set(v,"js-enabled",true);
  store_bool_set(v,"js-openwin",false);
  store_bool_set(v,"inline-media",false);
  store_int_set(v,"media-mask",0);
  store_int_set(v,"min-font",0);
  store_int_set(v,"default-font",16);
  store_bool_set(v,"auto-images",true);
  store_bool_set(v,"allows-content-js",true);
  store_int_set(v,"content-mode",0);
  store_int_set(v,"data-detectors",0);
  store_double(v,"zoom",1.0);
  store_double(v,"mag",1.0);
  store_bool_set(v,"inspectable",false);
  store_bool_set(v,"back-gestures",false);
  store_bool_set(v,"link-preview",true);
  store_bool_set(v,"muted",false);
  store_bool_set(v,"transparent",false);
  store_bool_set(v,"smooth-scroll",true);
  store_bool_set(v,"developer-extras",false);
  // progress
  double *prog=malloc(sizeof(double)); *prog=0.0; g_object_set_data_full(G_OBJECT(v),"progress",prog,free);
  // back/forward list: simple array of strings (store count + vector)
  g_object_set_data(G_OBJECT(v),"bf-count",GINT_TO_POINTER(0));
  g_object_set_data(G_OBJECT(v),"bf-cur",GINT_TO_POINTER(-1));
  g_object_set_data(G_OBJECT(v),"web-context",NULL);
  g_object_ref_sink(v);
  return v;
}

void *na_webview_create(uint32_t wid){ return make_view(wid); }
void *na_webview_create_with_context(uint32_t wid, void *ctx){
  GtkWidget *v=make_view(wid);
  g_object_set_data(G_OBJECT(v),"web-context",ctx);
  return v;
}
void na_webview_free(uint32_t wid, void *ptr){ (void)wid; GtkWidget *w=ptr; if(!w) return; GtkWidget *p=gtk_widget_get_parent(w); if(p) na_compat_container_remove(p,w); g_object_unref(w); }
void *na_webview_get_context(void *ptr){ GtkWidget *w=ptr; return w?g_object_get_data(G_OBJECT(w),"web-context"):NULL; }

void na_webview_load_url(void *ptr,const char *url){
  GtkWidget *w=ptr; if(!w) return;
  store_str(w,"nkit-url",url?url:"");
  // simulate push to BF list
  int cnt=GPOINTER_TO_INT(g_object_get_data(G_OBJECT(w),"bf-count"));
  int cur=GPOINTER_TO_INT(g_object_get_data(G_OBJECT(w),"bf-cur"));
  // truncate forward
  // store URL in simple qdata slot
  char key[64]; snprintf(key,sizeof(key),"bf-%d-url",cnt);
  // if we truncated, we just append; for stub keep linear
  g_object_set_data_full(G_OBJECT(w), key, strdup(url?url:""), free);
  char tkey[64]; snprintf(tkey,sizeof(tkey),"bf-%d-title",cnt);
  g_object_set_data_full(G_OBJECT(w), tkey, strdup(""), free);
  g_object_set_data(G_OBJECT(w),"bf-count",GINT_TO_POINTER(cnt+1));
  g_object_set_data(G_OBJECT(w),"bf-cur",GINT_TO_POINTER(cnt));
  (void)cur;
}
void na_webview_load_html(void *ptr,const char *html,const char *base){ (void)html; na_webview_load_url(ptr, base?base:"about:blank"); }
void na_webview_load_data(void *ptr,const char *data,int len,const char *mime,const char *enc,const char *base){ (void)data;(void)len;(void)mime;(void)enc; na_webview_load_url(ptr, base?base:"about:blank"); }
void na_webview_load_file_url(void *ptr,const char *fileUrl,const char *readAccess){ (void)readAccess; na_webview_load_url(ptr,fileUrl); }
void na_webview_reload(void *ptr){ (void)ptr; }
void na_webview_reload_from_origin(void *ptr){ (void)ptr; }
void na_webview_stop_loading(void *ptr){ (void)ptr; }

bool na_webview_go_back(void *ptr){
  GtkWidget *w=ptr; if(!w) return false;
  int cur=GPOINTER_TO_INT(g_object_get_data(G_OBJECT(w),"bf-cur"));
  if(cur<=0) return false;
  g_object_set_data(G_OBJECT(w),"bf-cur",GINT_TO_POINTER(cur-1));
  char key[64]; snprintf(key,sizeof(key),"bf-%d-url",cur-1);
  char *u=g_object_get_data(G_OBJECT(w),key); store_str(w,"nkit-url",u?u:"");
  return true;
}
bool na_webview_go_forward(void *ptr){
  GtkWidget *w=ptr; if(!w) return false;
  int cur=GPOINTER_TO_INT(g_object_get_data(G_OBJECT(w),"bf-cur"));
  int cnt=GPOINTER_TO_INT(g_object_get_data(G_OBJECT(w),"bf-count"));
  if(cur+1>=cnt) return false;
  g_object_set_data(G_OBJECT(w),"bf-cur",GINT_TO_POINTER(cur+1));
  char key[64]; snprintf(key,sizeof(key),"bf-%d-url",cur+1);
  char *u=g_object_get_data(G_OBJECT(w),key); store_str(w,"nkit-url",u?u:"");
  return true;
}
bool na_webview_can_go_back(void *ptr){ GtkWidget *w=ptr; if(!w) return false; int cur=GPOINTER_TO_INT(g_object_get_data(G_OBJECT(w),"bf-cur")); return cur>0; }
bool na_webview_can_go_forward(void *ptr){ GtkWidget *w=ptr; if(!w) return false; int cur=GPOINTER_TO_INT(g_object_get_data(G_OBJECT(w),"bf-cur")); int cnt=GPOINTER_TO_INT(g_object_get_data(G_OBJECT(w),"bf-count")); return cur+1<cnt; }
bool na_webview_go_to_back_forward_index(void *ptr,int idx){
  GtkWidget *w=ptr; if(!w) return false;
  int cnt=GPOINTER_TO_INT(g_object_get_data(G_OBJECT(w),"bf-count"));
  if(idx<0||idx>=cnt) return false;
  g_object_set_data(G_OBJECT(w),"bf-cur",GINT_TO_POINTER(idx));
  char key[64]; snprintf(key,sizeof(key),"bf-%d-url",idx);
  char *u=g_object_get_data(G_OBJECT(w),key); store_str(w,"nkit-url",u?u:"");
  return true;
}
int na_webview_back_forward_count(void *ptr){ GtkWidget *w=ptr; return w?GPOINTER_TO_INT(g_object_get_data(G_OBJECT(w),"bf-count")):0; }
bool na_webview_back_forward_item_at(void *ptr,int idx,char *outUrl,char *outTitle,int maxLen){
  GtkWidget *w=ptr; if(!w) return false;
  char key[64]; snprintf(key,sizeof(key),"bf-%d-url",idx);
  char *u=g_object_get_data(G_OBJECT(w),key); if(!u) return false;
  if(outUrl) { strncpy(outUrl,u,maxLen-1); outUrl[maxLen-1]='\0'; }
  if(outTitle){ char tkey[64]; snprintf(tkey,sizeof(tkey),"bf-%d-title",idx); char *t=g_object_get_data(G_OBJECT(w),tkey); strncpy(outTitle,t?t:"",maxLen-1); outTitle[maxLen-1]='\0'; }
  return true;
}
int na_webview_back_forward_current_index(void *ptr){ GtkWidget *w=ptr; return w?GPOINTER_TO_INT(g_object_get_data(G_OBJECT(w),"bf-cur")):-1; }

const char *na_webview_get_url(void *ptr){ return load_str(ptr,"nkit-url"); }
const char *na_webview_get_title(void *ptr){ return load_str(ptr,"nkit-title"); }
double na_webview_get_progress(void *ptr){ return load_double(ptr,"progress",0.0); }
bool na_webview_is_loading(void *ptr){ (void)ptr; return false; }
bool na_webview_has_only_secure_content(void *ptr){ (void)ptr; return true; }
double na_webview_get_estimated_progress(void *ptr){ return na_webview_get_progress(ptr); }

void na_webview_set_custom_user_agent(void *ptr,const char *ua){ store_str(ptr,"nkit-ua",ua); }
const char *na_webview_get_custom_user_agent(void *ptr){ return load_str(ptr,"nkit-ua"); }
void na_webview_set_application_name_for_user_agent(void *ptr,const char *s){ store_str(ptr,"nkit-app-ua",s); }
void na_webview_set_allows_back_forward_gestures(void *ptr,bool v){ store_bool_set(ptr,"back-gestures",v); }
bool na_webview_get_allows_back_forward_gestures(void *ptr){ return load_bool(ptr,"back-gestures",false); }
void na_webview_set_allows_link_preview(void *ptr,bool v){ store_bool_set(ptr,"link-preview",v); }
bool na_webview_get_allows_link_preview(void *ptr){ return load_bool(ptr,"link-preview",true); }
void na_webview_set_allows_magnification(void *ptr,bool v){ store_bool_set(ptr,"allow-mag",v); }
void na_webview_set_magnification(void *ptr,double m){ store_double(ptr,"mag",m); }
double na_webview_get_magnification(void *ptr){ return load_double(ptr,"mag",1.0); }
void na_webview_set_inspectable(void *ptr,bool v){ store_bool_set(ptr,"inspectable",v); }
bool na_webview_is_inspectable(void *ptr){ return load_bool(ptr,"inspectable",false); }
void na_webview_set_javascript_enabled(void *ptr,bool v){ store_bool_set(ptr,"js-enabled",v); }
bool na_webview_is_javascript_enabled(void *ptr){ return load_bool(ptr,"js-enabled",true); }
void na_webview_set_javascript_can_open_windows(void *ptr,bool v){ store_bool_set(ptr,"js-openwin",v); }
bool na_webview_is_javascript_can_open_windows(void *ptr){ return load_bool(ptr,"js-openwin",false); }
void na_webview_set_allows_inline_media_playback(void *ptr,bool v){ store_bool_set(ptr,"inline-media",v); }
bool na_webview_get_allows_inline_media_playback(void *ptr){ return load_bool(ptr,"inline-media",false); }
void na_webview_set_allows_air_play(void *ptr,bool v){ store_bool_set(ptr,"airplay",v); }
void na_webview_set_allows_picture_in_picture(void *ptr,bool v){ store_bool_set(ptr,"pip",v); }
void na_webview_set_media_types_requiring_user_action(void *ptr,int m){ store_int_set(ptr,"media-mask",m); }
int  na_webview_get_media_types_requiring_user_action(void *ptr){ return load_int(ptr,"media-mask",0); }
void na_webview_set_minimum_font_size(void *ptr,int s){ store_int_set(ptr,"min-font",s); }
int  na_webview_get_minimum_font_size(void *ptr){ return load_int(ptr,"min-font",0); }
void na_webview_set_default_font_size(void *ptr,int s){ store_int_set(ptr,"default-font",s); }
void na_webview_set_serif_font_family(void *ptr,const char *f){ store_str(ptr,"serif",f); }
void na_webview_set_sans_serif_font_family(void *ptr,const char *f){ store_str(ptr,"sans",f); }
void na_webview_set_monospace_font_family(void *ptr,const char *f){ store_str(ptr,"mono",f); }
void na_webview_set_default_charset(void *ptr,const char *c){ store_str(ptr,"charset",c); }
void na_webview_set_auto_load_images(void *ptr,bool v){ store_bool_set(ptr,"auto-images",v); }
bool na_webview_get_auto_load_images(void *ptr){ return load_bool(ptr,"auto-images",true); }
void na_webview_set_suppresses_incremental_rendering(void *ptr,bool v){ store_bool_set(ptr,"suppress",v); }
void na_webview_set_tab_focuses_links(void *ptr,bool v){ store_bool_set(ptr,"tab-links",v); }
void na_webview_set_allows_content_javascript(void *ptr,bool v){ store_bool_set(ptr,"allows-content-js",v); }
bool na_webview_get_allows_content_javascript(void *ptr){ return load_bool(ptr,"allows-content-js",true); }
void na_webview_set_preferred_content_mode(void *ptr,int m){ store_int_set(ptr,"content-mode",m); }
int  na_webview_get_preferred_content_mode(void *ptr){ return load_int(ptr,"content-mode",0); }
void na_webview_set_upgrade_known_hosts_to_https(void *ptr,bool v){ store_bool_set(ptr,"upgrade-https",v); }
void na_webview_set_limits_navigations_to_app_bound_domains(void *ptr,bool v){ store_bool_set(ptr,"appbound",v); }
void na_webview_set_ignores_viewport_scale_limits(void *ptr,bool v){ store_bool_set(ptr,"ignore-viewport",v); }
void na_webview_set_data_detector_types(void *ptr,int m){ store_int_set(ptr,"data-detectors",m); }
int  na_webview_get_data_detector_types(void *ptr){ return load_int(ptr,"data-detectors",0); }
void na_webview_set_zoom_level(void *ptr,double l){ store_double(ptr,"zoom",l); }
double na_webview_get_zoom_level(void *ptr){ return load_double(ptr,"zoom",1.0); }
void na_webview_set_background_color(void *ptr,unsigned char r,unsigned char g,unsigned char b,unsigned char a){ (void)ptr;(void)r;(void)g;(void)b;(void)a; NkitViewState *st=nkit_state_of(ptr); if(st){st->bg[0]=r;st->bg[1]=g;st->bg[2]=b;st->bg[3]=a;st->has_bg=true;}}
void na_webview_set_transparent_background(void *ptr,bool v){ store_bool_set(ptr,"transparent",v); }
void na_webview_set_enable_write_console_messages_to_stdout(void *ptr,bool v){ store_bool_set(ptr,"console-stdout",v); }
void na_webview_set_enable_developer_extras(void *ptr,bool v){ store_bool_set(ptr,"developer-extras",v); }
void na_webview_set_enable_caret_browsing(void *ptr,bool v){ store_bool_set(ptr,"caret",v); }
void na_webview_set_enable_smooth_scrolling(void *ptr,bool v){ store_bool_set(ptr,"smooth-scroll",v); }
void na_webview_set_enable_spatial_navigation(void *ptr,bool v){ store_bool_set(ptr,"spatial",v); }
void na_webview_set_enable_media_stream(void *ptr,bool v){ store_bool_set(ptr,"media-stream",v); }
void na_webview_set_enable_mediasource(void *ptr,bool v){ store_bool_set(ptr,"mediasource",v); }
void na_webview_set_enable_webaudio(void *ptr,bool v){ store_bool_set(ptr,"webaudio",v); }
void na_webview_set_enable_webrtc(void *ptr,bool v){ store_bool_set(ptr,"webrtc",v); }
void na_webview_set_enable_encrypted_media(void *ptr,bool v){ store_bool_set(ptr,"encrypted-media",v); }
void na_webview_set_enable_site_specific_quirks(void *ptr,bool v){ store_bool_set(ptr,"quirks",v); }
void na_webview_set_enable_back_forward_nav_gestures(void *ptr,bool v){ store_bool_set(ptr,"bf-gestures",v); }

// scripts/styles/message handlers
static uint32_t g_script_next=1;
uint32_t na_webview_add_user_script(void *ptr,const char *src,int inj,bool mainOnly){ (void)ptr;(void)src;(void)inj;(void)mainOnly; return g_script_next++; }
uint32_t na_webview_add_user_script_with_world(void *ptr,const char *src,int inj,bool mainOnly,const char *world){ (void)world; return na_webview_add_user_script(ptr,src,inj,mainOnly); }
void na_webview_remove_user_script(void *ptr,uint32_t id){ (void)ptr;(void)id; }
void na_webview_remove_all_user_scripts(void *ptr){ (void)ptr; }
uint32_t na_webview_add_user_style_sheet(void *ptr,const char *src,bool mainOnly){ (void)ptr;(void)src;(void)mainOnly; return g_script_next++; }
void na_webview_remove_user_style_sheet(void *ptr,uint32_t id){ (void)ptr;(void)id; }
void na_webview_remove_all_user_style_sheets(void *ptr){ (void)ptr; }
void na_webview_add_script_message_handler(void *ptr,const char *name){ (void)ptr; if(name) store_str(ptr,name,"1"); }
void na_webview_add_script_message_handler_with_reply(void *ptr,const char *name){ na_webview_add_script_message_handler(ptr,name); }
void na_webview_remove_script_message_handler(void *ptr,const char *name){ (void)ptr;(void)name; }
void na_webview_remove_all_script_message_handlers(void *ptr){ (void)ptr; }

void na_webview_evaluate_javascript(void *ptr,const char *script,uint32_t req){ (void)ptr;(void)script; if(g_script_fn){ uint32_t wid=GPOINTER_TO_UINT(g_object_get_data(G_OBJECT(ptr),"nkit-id")); g_script_fn(wid,req,"null",false,g_script_ctx); } }
void na_webview_evaluate_javascript_with_world(void *ptr,const char *script,const char *world,uint32_t req){ (void)world; na_webview_evaluate_javascript(ptr,script,req); }
void na_webview_call_async_javascript(void *ptr,const char *script,const char *args,const char *world,uint32_t req){ (void)args;(void)world; na_webview_evaluate_javascript(ptr,script,req); }
void na_webview_set_script_result_callback(void *fn,void *ctx){ g_script_fn=(script_fn)fn; g_script_ctx=ctx; }

void na_webview_set_navigation_callback(void *fn,void *ctx){ g_nav_fn=(nav_fn)fn; g_nav_ctx=ctx; }
void na_webview_set_progress_callback(void *fn,void *ctx){ g_prog_fn=(prog_fn)fn; g_prog_ctx=ctx; }
void na_webview_set_message_callback(void *fn,void *ctx){ g_msg_fn=(msg_fn)fn; g_msg_ctx=ctx; }
void na_webview_set_dialog_callback(void *fn,void *ctx){ g_dialog_fn=(dialog_fn)fn; g_dialog_ctx=ctx; }
void na_webview_set_permission_callback(void *fn,void *ctx){ g_perm_fn=(perm_fn)fn; g_perm_ctx=ctx; }
void na_webview_set_terminate_callback(void *fn,void *ctx){ g_term_fn=(term_fn)fn; g_term_ctx=ctx; }
void na_webview_set_decide_policy_callback(void *fn,void *ctx){ g_decide_fn=(nav_fn)fn; g_decide_ctx=ctx; }
void na_webview_decide_policy(void *ptr,uint32_t did,bool allow){ (void)ptr;(void)did;(void)allow; }
void na_webview_reply_script_message(void *ptr,const char *handler,const char *reply){ (void)ptr;(void)handler;(void)reply; }

void na_webview_register_uri_scheme(void *ptr,const char *scheme){ (void)ptr;(void)scheme; }
void na_webview_unregister_uri_scheme(void *ptr,const char *scheme){ (void)ptr;(void)scheme; }
void na_webview_set_scheme_callback(void *fn,void *ctx){ g_scheme_fn=(scheme_fn)fn; g_scheme_ctx=ctx; }
void na_webview_scheme_finish(uint32_t req,const char *mime,const char *data,int len){ (void)req;(void)mime;(void)data;(void)len; }
void na_webview_scheme_finish_with_headers(uint32_t req,const char *mime,const char *data,int len,const char *hdr,int code){ (void)req;(void)mime;(void)data;(void)len;(void)hdr;(void)code; }
void na_webview_scheme_error(uint32_t req,const char *msg){ (void)req;(void)msg; }
void na_webview_scheme_redirect(uint32_t req,const char *url){ (void)req;(void)url; }

bool na_webview_find_text(void *ptr,const char *t,bool cs,bool back,bool wrap){ (void)ptr;(void)t;(void)cs;(void)back;(void)wrap; return true; }
bool na_webview_find_next(void *ptr,bool fwd){ (void)ptr;(void)fwd; return true; }
void na_webview_hide_find_highlight(void *ptr){ (void)ptr; }
void na_webview_print(void *ptr){ (void)ptr; }
void na_webview_print_to_pdf(void *ptr,const char *path,uint32_t req){ (void)ptr;(void)path; if(g_pdf_fn){ uint32_t wid=GPOINTER_TO_UINT(g_object_get_data(G_OBJECT(ptr),"nkit-id")); g_pdf_fn(wid,req,true,g_pdf_ctx);} }
void na_webview_set_pdf_callback(void *fn,void *ctx){ g_pdf_fn=(pdf_fn)fn; g_pdf_ctx=ctx; }
void na_webview_snapshot(void *ptr,uint32_t req){ (void)ptr; if(g_snap_fn){ uint32_t wid=GPOINTER_TO_UINT(g_object_get_data(G_OBJECT(ptr),"nkit-id")); g_snap_fn(wid,req,0,g_snap_ctx);} }
void na_webview_snapshot_rect(void *ptr,double x,double y,double w,double h,uint32_t req){ (void)x;(void)y;(void)w;(void)h; na_webview_snapshot(ptr,req); }
void na_webview_set_snapshot_callback(void *fn,void *ctx){ g_snap_fn=(snap_fn)fn; g_snap_ctx=ctx; }
void na_webview_close_all_media_presentations(void *ptr){ (void)ptr; }
void na_webview_set_muted(void *ptr,bool m){ store_bool_set(ptr,"muted",m); }
bool na_webview_is_muted(void *ptr){ return load_bool(ptr,"muted",false); }
