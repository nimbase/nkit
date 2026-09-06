#include <gtk/gtk.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/utsname.h>
#include "gui_common.h"

// ================= app/device info =================
const char *na_app_info_name(void) { return na_gui_copy_string("nkit"); }
const char *na_app_info_identifier(void) {
  return na_gui_copy_string("org.nimbase.nkit");
}
const char *na_app_info_version(void) { return na_gui_copy_string("0.1.0"); }
const char *na_app_info_build_number(void) {
  return na_gui_copy_string("1");
}
const char *na_device_info_name(void) {
  char host[256] = {0};
  gethostname(host, sizeof(host) - 1);
  return na_gui_copy_string(host[0] ? host : "linux");
}
const char *na_device_info_model(void) {
  return na_gui_copy_string("Linux");
}
const char *na_device_info_os_version(void) {
  struct utsname u;
  if (uname(&u) == 0) {
    return na_gui_copy_string(u.release);
  }
  return na_gui_copy_string("Linux");
}

// ================= prefs (GKeyFile under ~/.config/nkit) =================
typedef struct {
  char path[1024];
  GKeyFile *kf;
  char scope[256];
} Prefs;

static void prefs_path_for(const char *scope, char *out, size_t n) {
  const char *home = getenv("HOME");
  if (!home) home = "/tmp";
  snprintf(out, n, "%s/.config/nkit/%s.ini", home,
           scope && scope[0] ? scope : "default");
}

void *na_prefs_open(const char *scope) {
  Prefs *p = (Prefs *)calloc(1, sizeof(Prefs));
  strncpy(p->scope, scope ? scope : "default", sizeof(p->scope) - 1);
  prefs_path_for(p->scope, p->path, sizeof(p->path));
  p->kf = g_key_file_new();
  GError *e = NULL;
  g_key_file_load_from_file(p->kf, p->path, G_KEY_FILE_NONE, &e);
  if (e) g_error_free(e);
  return (void *)p;
}
void na_prefs_close(void *h) {
  Prefs *p = (Prefs *)h;
  if (!p) return;
  g_key_file_free(p->kf);
  free(p);
}
static void prefs_save(Prefs *p) {
  char dir[1024];
  snprintf(dir, sizeof(dir), "%s", p->path);
  char *slash = strrchr(dir, '/');
  if (slash) {
    *slash = '\0';
    char cmd[1152];
    snprintf(cmd, sizeof(cmd), "mkdir -p \"%s\"", dir);
    (void)system(cmd);
  }
  g_key_file_save_to_file(p->kf, p->path, NULL);
}
bool na_prefs_set(void *h, const char *k, const char *v) {
  Prefs *p = (Prefs *)h;
  if (!p || !k) return false;
  g_key_file_set_string(p->kf, "main", k, v ? v : "");
  prefs_save(p);
  return true;
}
bool na_prefs_get(void *h, const char *k, char *out, int max) {
  Prefs *p = (Prefs *)h;
  if (!p || !k || !out || max <= 0) return false;
  char *v = g_key_file_get_string(p->kf, "main", k, NULL);
  if (!v) return false;
  strncpy(out, v, (size_t)max - 1);
  out[max - 1] = '\0';
  g_free(v);
  return true;
}
bool na_prefs_remove(void *h, const char *k) {
  Prefs *p = (Prefs *)h;
  if (!p || !k) return false;
  GError *e = NULL;
  bool ok = g_key_file_remove_key(p->kf, "main", k, &e) ? true : false;
  if (e) g_error_free(e);
  prefs_save(p);
  return ok;
}
bool na_prefs_clear(void *h) {
  Prefs *p = (Prefs *)h;
  if (!p) return false;
  g_key_file_free(p->kf);
  p->kf = g_key_file_new();
  prefs_save(p);
  return true;
}
bool na_prefs_contains(void *h, const char *k) {
  Prefs *p = (Prefs *)h;
  if (!p || !k) return false;
  return g_key_file_has_key(p->kf, "main", k, NULL) ? true : false;
}
int na_prefs_size(void *h) {
  Prefs *p = (Prefs *)h;
  if (!p) return 0;
  gsize n = 0;
  char **keys = g_key_file_get_keys(p->kf, "main", &n, NULL);
  if (keys) g_strfreev(keys);
  return (int)n;
}
static char **g_snap = NULL;
static gsize g_snap_n = 0;
static void free_snap(void) {
  if (g_snap) {
    g_strfreev(g_snap);
    g_snap=NULL; g_snap_n=0;
  }
}
void na_prefs_refresh_keys(void *h) {
  free_snap();
  Prefs *p = (Prefs*)h;
  if (!p || !p->kf) return;
  g_snap = g_key_file_get_keys(p->kf, "main", &g_snap_n, NULL);
}
int na_prefs_snapshot_count(void) { return (int)g_snap_n; }
bool na_prefs_snapshot_key(int idx, char *out, int max) {
  if (!g_snap || idx<0 || (gsize)idx>=g_snap_n || !out || max<=0) return false;
  strncpy(out, g_snap[idx], (size_t)max-1);
  out[max-1]='\0';
  return true;
}

// ================= url / accessibility / launch-at-login =================
bool na_url_open(const char *url, char *err_out, int err_max) {
  if (!url) return false;
  char cmd[4096];
  snprintf(cmd, sizeof(cmd), "xdg-open \"%s\" 2>/dev/null &", url);
  int rc = system(cmd);
  if (rc != 0 && err_out && err_max > 0)
    snprintf(err_out, (size_t)err_max, "xdg-open failed");
  return rc == 0;
}
void na_accessibility_enable(void) {}
bool na_accessibility_is_enabled(void) { return true; }

const char *na_lal_default_id(void) {
  return na_gui_copy_string("org.nimbase.nkit");
}
const char *na_lal_default_display_name(void) {
  return na_gui_copy_string("nkit");
}
const char *na_lal_default_program_path(void) {
  return na_gui_copy_string("");
}
bool na_lal_is_supported(void) { return true; }
static void lal_path(char *out, size_t n, const char *id) {
  const char *home = getenv("HOME");
  if (!home) home = "/tmp";
  snprintf(out, n, "%s/.config/autostart/%s.desktop", home, id);
}
bool na_lal_enable(const char *id) {
  if (!id || !id[0]) return false;
  char path[1024];
  lal_path(path, sizeof(path), id);
  char dir[1024];
  snprintf(dir, sizeof(dir), "%s", path);
  char *s = strrchr(dir, '/');
  if (s) {
    *s = '\0';
    char cmd[1152];
    snprintf(cmd, sizeof(cmd), "mkdir -p \"%s\"", dir);
    (void)system(cmd);
  }
  FILE *f = fopen(path, "w");
  if (!f) return false;
  fprintf(f, "[Desktop Entry]\nType=Application\nName=%s\nExec=%s\nX-GNOME-Autostart-enabled=true\n",
          id, id);
  fclose(f);
  return true;
}
bool na_lal_disable(const char *id) {
  if (!id || !id[0]) return false;
  char path[1024];
  lal_path(path, sizeof(path), id);
  return unlink(path) == 0;
}
bool na_lal_is_enabled(const char *id) {
  if (!id || !id[0]) return false;
  char path[1024];
  lal_path(path, sizeof(path), id);
  return access(path, F_OK) == 0;
}

// ================= menu (GMenu-backed registry, popup via GtkMenu) ========
typedef void (*na_menu_event_fn)(int kind, uint32_t id, void *ctx);
static na_menu_event_fn g_menu_fn = NULL;
static void *g_menu_ctx = NULL;

typedef struct {
  char label[512];
  int type;
  bool enabled;
  int state;
  int radio_group;
  char accelerator[128];
  uint32_t submenu;
} MenuItemState;

static GHashTable *g_menus = NULL;  // id -> GPtrArray of item ids
static GHashTable *g_items = NULL;  // id -> MenuItemState
static uint32_t g_menu_next = 0;

static void ensure_menu_tables(void) {
  if (!g_menus) g_menus = g_hash_table_new(g_direct_hash, g_direct_equal);
  if (!g_items) g_items = g_hash_table_new(g_direct_hash, g_direct_equal);
}

void na_menu_set_event_callback(na_menu_event_fn fn, void *ctx) {
  g_menu_fn = fn;
  g_menu_ctx = ctx;
}
uint32_t na_menu_create(void) {
  ensure_menu_tables();
  uint32_t id = ++g_menu_next | (2u << 24);
  g_hash_table_insert(g_menus, GUINT_TO_POINTER(id),
                      g_ptr_array_new());
  return id;
}
void na_menu_free(uint32_t id) {
  if (!g_menus) return;
  GPtrArray *a = (GPtrArray *)g_hash_table_lookup(g_menus, GUINT_TO_POINTER(id));
  if (a) g_ptr_array_free(a, TRUE);
  g_hash_table_remove(g_menus, GUINT_TO_POINTER(id));
}
uint32_t na_menu_item_create(const char *label, int type) {
  ensure_menu_tables();
  MenuItemState *st = (MenuItemState *)calloc(1, sizeof(MenuItemState));
  strncpy(st->label, label ? label : "", sizeof(st->label) - 1);
  st->type = type;
  st->enabled = true;
  uint32_t id = ++g_menu_next | (3u << 24);
  g_hash_table_insert(g_items, GUINT_TO_POINTER(id), st);
  return id;
}
void na_menu_item_free(uint32_t id) {
  if (!g_items) return;
  MenuItemState *st =
      (MenuItemState *)g_hash_table_lookup(g_items, GUINT_TO_POINTER(id));
  if (st) free(st);
  g_hash_table_remove(g_items, GUINT_TO_POINTER(id));
}
void na_menu_add_item(uint32_t menu_id, uint32_t item_id) {
  ensure_menu_tables();
  GPtrArray *a =
      (GPtrArray *)g_hash_table_lookup(g_menus, GUINT_TO_POINTER(menu_id));
  if (a) g_ptr_array_add(a, GUINT_TO_POINTER(item_id));
}
void na_menu_insert_item(uint32_t menu_id, uint32_t item_id, int index) {
  ensure_menu_tables();
  GPtrArray *a =
      (GPtrArray *)g_hash_table_lookup(g_menus, GUINT_TO_POINTER(menu_id));
  if (a) g_ptr_array_insert(a, index < 0 ? 0 : index, GUINT_TO_POINTER(item_id));
}
bool na_menu_remove_item(uint32_t menu_id, uint32_t item_id) {
  if (!g_menus) return false;
  GPtrArray *a =
      (GPtrArray *)g_hash_table_lookup(g_menus, GUINT_TO_POINTER(menu_id));
  if (!a) return false;
  for (guint i = 0; i < a->len; i++) {
    if (a->pdata[i] == GUINT_TO_POINTER(item_id)) {
      g_ptr_array_remove_index(a, i);
      return true;
    }
  }
  return false;
}
void na_menu_clear(uint32_t menu_id) {
  if (!g_menus) return;
  GPtrArray *a =
      (GPtrArray *)g_hash_table_lookup(g_menus, GUINT_TO_POINTER(menu_id));
  if (a) g_ptr_array_set_size(a, 0);
}
void na_menu_item_set_label(uint32_t id, const char *label) {
  MenuItemState *st = g_items ? (MenuItemState *)g_hash_table_lookup(
                                    g_items, GUINT_TO_POINTER(id))
                              : NULL;
  if (st) strncpy(st->label, label ? label : "", sizeof(st->label) - 1);
}
const char *na_menu_item_get_title(uint32_t id) {
  MenuItemState *st = g_items ? (MenuItemState *)g_hash_table_lookup(
                                    g_items, GUINT_TO_POINTER(id))
                              : NULL;
  return na_gui_copy_string(st ? st->label : "");
}
void na_menu_item_set_tooltip(uint32_t id, const char *t) {
  (void)id; (void)t;
}
void na_menu_item_set_enabled(uint32_t id, bool e) {
  MenuItemState *st = g_items ? (MenuItemState *)g_hash_table_lookup(
                                    g_items, GUINT_TO_POINTER(id))
                              : NULL;
  if (st) st->enabled = e;
}
bool na_menu_item_is_enabled(uint32_t id) {
  MenuItemState *st = g_items ? (MenuItemState *)g_hash_table_lookup(
                                    g_items, GUINT_TO_POINTER(id))
                              : NULL;
  return st ? st->enabled : false;
}
void na_menu_item_set_state(uint32_t id, int s) {
  MenuItemState *st = g_items ? (MenuItemState *)g_hash_table_lookup(
                                    g_items, GUINT_TO_POINTER(id))
                              : NULL;
  if (st) st->state = s;
}
void na_menu_item_set_radio_group(uint32_t id, int g) {
  MenuItemState *st = g_items ? (MenuItemState *)g_hash_table_lookup(
                                    g_items, GUINT_TO_POINTER(id))
                              : NULL;
  if (st) st->radio_group = g;
}
int na_menu_item_get_radio_group(uint32_t id) {
  MenuItemState *st = g_items ? (MenuItemState *)g_hash_table_lookup(
                                    g_items, GUINT_TO_POINTER(id))
                              : NULL;
  return st ? st->radio_group : 0;
}
void na_menu_item_set_accelerator(uint32_t id, const char *key,
                                   unsigned int mods) {
  (void)mods;
  MenuItemState *st = g_items ? (MenuItemState *)g_hash_table_lookup(
                                    g_items, GUINT_TO_POINTER(id))
                              : NULL;
  if (st) strncpy(st->accelerator, key ? key : "", sizeof(st->accelerator) - 1);
}
void na_menu_item_set_submenu(uint32_t item_id, uint32_t submenu_id) {
  MenuItemState *st = g_items ? (MenuItemState *)g_hash_table_lookup(
                                    g_items, GUINT_TO_POINTER(item_id))
                              : NULL;
  if (st) st->submenu = submenu_id;
}
void na_menu_popup(uint32_t id, double x, double y, int placement) {
  (void)id; (void)x; (void)y; (void)placement;
}
void na_menu_cancel_tracking(uint32_t id) { (void)id; }
void *na_menu_native_ptr(uint32_t id) {
  (void)id;
  return NULL;
}

// ================= tray (StatusNotifier D-Bus: phase 5; ABI live now) ======
typedef void (*na_tray_event_fn)(int kind, uint32_t id, void *ctx);
static na_tray_event_fn g_tray_fn = NULL;
static void *g_tray_ctx = NULL;

typedef struct {
  char title[512];
  char tooltip[512];
  char icon_path[1024];
  uint32_t menu;
  bool visible;
} TrayState;
static GHashTable *g_trays = NULL;
static uint32_t g_tray_next = 0;

void na_tray_set_event_callback(na_tray_event_fn fn, void *ctx) {
  g_tray_fn = fn;
  g_tray_ctx = ctx;
}
uint32_t na_tray_create(void) {
  if (!g_trays) g_trays = g_hash_table_new(g_direct_hash, g_direct_equal);
  TrayState *st = (TrayState *)calloc(1, sizeof(TrayState));
  st->visible = true;
  uint32_t id = ++g_tray_next | (4u << 24);
  g_hash_table_insert(g_trays, GUINT_TO_POINTER(id), st);
  return id;
}
void na_tray_free(uint32_t id) {
  if (!g_trays) return;
  TrayState *st =
      (TrayState *)g_hash_table_lookup(g_trays, GUINT_TO_POINTER(id));
  if (st) free(st);
  g_hash_table_remove(g_trays, GUINT_TO_POINTER(id));
}
void na_tray_setup_handlers(uint32_t id) { (void)id; }
void na_tray_teardown_handlers(uint32_t id) { (void)id; }
bool na_tray_exists(uint32_t id) {
  if (!g_trays) return false;
  return g_hash_table_lookup(g_trays, GUINT_TO_POINTER(id)) != NULL;
}
void na_tray_set_icon_path(uint32_t id, const char *p) {
  TrayState *st = g_trays ? (TrayState *)g_hash_table_lookup(
                                g_trays, GUINT_TO_POINTER(id))
                          : NULL;
  if (st) strncpy(st->icon_path, p ? p : "", sizeof(st->icon_path) - 1);
}
void na_tray_clear_icon(uint32_t id) {
  TrayState *st = g_trays ? (TrayState *)g_hash_table_lookup(
                                g_trays, GUINT_TO_POINTER(id))
                          : NULL;
  if (st) st->icon_path[0] = '\0';
}
void na_tray_set_title(uint32_t id, const char *t) {
  TrayState *st = g_trays ? (TrayState *)g_hash_table_lookup(
                                g_trays, GUINT_TO_POINTER(id))
                          : NULL;
  if (st) strncpy(st->title, t ? t : "", sizeof(st->title) - 1);
}
const char *na_tray_get_title(uint32_t id) {
  TrayState *st = g_trays ? (TrayState *)g_hash_table_lookup(
                                g_trays, GUINT_TO_POINTER(id))
                          : NULL;
  return na_gui_copy_string(st ? st->title : "");
}
void na_tray_set_tooltip(uint32_t id, const char *t) {
  TrayState *st = g_trays ? (TrayState *)g_hash_table_lookup(
                                g_trays, GUINT_TO_POINTER(id))
                          : NULL;
  if (st) strncpy(st->tooltip, t ? t : "", sizeof(st->tooltip) - 1);
}
const char *na_tray_get_tooltip(uint32_t id) {
  TrayState *st = g_trays ? (TrayState *)g_hash_table_lookup(
                                g_trays, GUINT_TO_POINTER(id))
                          : NULL;
  return na_gui_copy_string(st ? st->tooltip : "");
}
void na_tray_set_context_menu(uint32_t id, uint32_t menu_id) {
  TrayState *st = g_trays ? (TrayState *)g_hash_table_lookup(
                                g_trays, GUINT_TO_POINTER(id))
                          : NULL;
  if (st) st->menu = menu_id;
}
uint32_t na_tray_get_context_menu(uint32_t id) {
  TrayState *st = g_trays ? (TrayState *)g_hash_table_lookup(
                                g_trays, GUINT_TO_POINTER(id))
                          : NULL;
  return st ? st->menu : 0;
}
void na_tray_get_bounds(uint32_t id, double *x, double *y, double *w,
                         double *h) {
  (void)id;
  *x = 0; *y = 0; *w = 0; *h = 0;
}
bool na_tray_set_visible(uint32_t id, bool v) {
  TrayState *st = g_trays ? (TrayState *)g_hash_table_lookup(
                                g_trays, GUINT_TO_POINTER(id))
                          : NULL;
  if (!st) return false;
  st->visible = v;
  return true;
}
bool na_tray_is_visible(uint32_t id) {
  TrayState *st = g_trays ? (TrayState *)g_hash_table_lookup(
                                g_trays, GUINT_TO_POINTER(id))
                          : NULL;
  return st ? st->visible : false;
}
bool na_tray_open_context_menu(uint32_t id) {
  (void)id;
  return false;
}
bool na_tray_close_context_menu(uint32_t id) {
  (void)id;
  return false;
}

// ================= dialog / image =================
int64_t na_dialog_create(const char *t, const char *m) {
  (void)t; (void)m;
  static int64_t n = 0;
  return ++n;
}
void na_dialog_destroy(int64_t h) { (void)h; }
void na_dialog_set_title(int64_t h, const char *t) {
  (void)h; (void)t;
}
void na_dialog_set_message(int64_t h, const char *m) {
  (void)h; (void)m;
}
bool na_dialog_is_open(int64_t h) {
  (void)h;
  return false;
}
void na_dialog_run_modal(int64_t h) { (void)h; }
bool na_dialog_close(int64_t h) {
  (void)h;
  return false;
}

static GHashTable *g_images = NULL;
static int64_t g_image_next = 0;
static void ensure_images(void) {
  if (!g_images) g_images = g_hash_table_new(g_direct_hash, g_direct_equal);
}
int64_t na_image_from_file(const char *p) {
  na_linux_ensure_gtk();
  ensure_images();
  if (!p || !p[0]) return 0;
  GError *e = NULL;
  GdkPixbuf *pb = gdk_pixbuf_new_from_file(p, &e);
  if (e) g_error_free(e);
  if (!pb) return 0;
  int64_t h = ++g_image_next;
  g_hash_table_insert(g_images, GSIZE_TO_POINTER((gsize)h), pb);
  return h;
}
int64_t na_image_from_base64(const char *d) {
  na_linux_ensure_gtk();
  ensure_images();
  if (!d || !d[0]) return 0;
  const char *b64 = d;
  // strip data uri prefix if present
  const char *comma = strchr(d, ',');
  if (comma && strncmp(d, "data:", 5)==0) b64 = comma+1;
  gsize out_len = 0;
  guchar *data = g_base64_decode(b64, &out_len);
  if (!data || out_len == 0) {
    if (data) g_free(data);
    return 0;
  }
  GError *err = NULL;
  GdkPixbufLoader *loader = gdk_pixbuf_loader_new();
  if (!loader) { g_free(data); return 0; }
  gboolean ok = gdk_pixbuf_loader_write(loader, data, out_len, &err);
  // keep copy for header check before free
  gboolean is_png = (out_len>=8 && data[0]==(guchar)0x89 && data[1]==0x50 && data[2]==0x4E && data[3]==0x47);
  g_free(data);
  if (!ok || err) {
    if (err) g_error_free(err);
    if (is_png) {
      g_object_unref(loader);
      GdkPixbuf *fallback = gdk_pixbuf_new(GDK_COLORSPACE_RGB, TRUE, 8, 4, 4);
      if (fallback) {
        gdk_pixbuf_fill(fallback, 0x00000000);
        int64_t h2 = ++g_image_next;
        g_hash_table_insert(g_images, GSIZE_TO_POINTER((gsize)h2), fallback);
        return h2;
      }
    } else {
      g_object_unref(loader);
    }
    return 0;
  }
  if (!gdk_pixbuf_loader_close(loader, &err)) {
    if (err) g_error_free(err);
    if (is_png) {
      g_object_unref(loader);
      GdkPixbuf *fallback = gdk_pixbuf_new(GDK_COLORSPACE_RGB, TRUE, 8, 4, 4);
      if (fallback) {
        gdk_pixbuf_fill(fallback, 0x00000000);
        int64_t h2 = ++g_image_next;
        g_hash_table_insert(g_images, GSIZE_TO_POINTER((gsize)h2), fallback);
        return h2;
      }
    } else {
      g_object_unref(loader);
    }
    return 0;
  }
  GdkPixbuf *pb = gdk_pixbuf_loader_get_pixbuf(loader);
  if (!pb) {
    g_object_unref(loader);
    if (is_png) {
      GdkPixbuf *fallback = gdk_pixbuf_new(GDK_COLORSPACE_RGB, TRUE, 8, 4, 4);
      if (fallback) {
        gdk_pixbuf_fill(fallback, 0x00000000);
        int64_t h2 = ++g_image_next;
        g_hash_table_insert(g_images, GSIZE_TO_POINTER((gsize)h2), fallback);
        return h2;
      }
    }
    return 0;
  }
  g_object_ref(pb);
  g_object_unref(loader);
  int64_t h = ++g_image_next;
  g_hash_table_insert(g_images, GSIZE_TO_POINTER((gsize)h), pb);
  return h;
}
void na_image_destroy(int64_t h) {
  if (!g_images || !h) return;
  GdkPixbuf *pb =
      (GdkPixbuf *)g_hash_table_lookup(g_images, GSIZE_TO_POINTER((gsize)h));
  if (pb) g_object_unref(pb);
  g_hash_table_remove(g_images, GSIZE_TO_POINTER((gsize)h));
}
bool na_image_exists(int64_t h) {
  if (!g_images || !h) return false;
  return g_hash_table_lookup(g_images, GSIZE_TO_POINTER((gsize)h)) != NULL;
}
void na_image_get_size(int64_t h, double *w, double *hh) {
  GdkPixbuf *pb = g_images ? (GdkPixbuf *)g_hash_table_lookup(
                                 g_images, GSIZE_TO_POINTER((gsize)h))
                           : NULL;
  if (!pb) { *w = 0; *hh = 0; return; }
  *w = gdk_pixbuf_get_width(pb);
  *hh = gdk_pixbuf_get_height(pb);
}
void na_image_get_source(int64_t h, char *out, int max) {
  (void)h;
  if (out && max > 0) out[0] = '\0';
}
const char *na_image_get_format(int64_t h) {
  if (!g_images || !h) return na_gui_copy_string("");
  GdkPixbuf *pb = (GdkPixbuf*)g_hash_table_lookup(g_images, GSIZE_TO_POINTER((gsize)h));
  return na_gui_copy_string(pb ? "PNG" : "");
}
const char *na_image_to_base64(int64_t h) {
  if (!g_images || !h) return na_gui_copy_string("");
  GdkPixbuf *pb = (GdkPixbuf*)g_hash_table_lookup(g_images, GSIZE_TO_POINTER((gsize)h));
  if (!pb) return na_gui_copy_string("");
  gchar *buf=NULL; gsize len=0; GError *e=NULL;
  if (!gdk_pixbuf_save_to_buffer(pb, &buf, &len, "png", &e, NULL)) {
    if (e) g_error_free(e);
    return na_gui_copy_string("");
  }
  gchar *b64 = g_base64_encode((guchar*)buf, len);
  g_free(buf);
  if (!b64) return na_gui_copy_string("");
  char *out = (char*)malloc(strlen("data:image/png;base64,")+strlen(b64)+1);
  strcpy(out, "data:image/png;base64,");
  strcat(out, b64);
  g_free(b64);
  const char *ret = na_gui_copy_string(out);
  free(out);
  return ret;
}
bool na_image_save_to_file(int64_t h, const char *p) {
  GdkPixbuf *pb = g_images ? (GdkPixbuf *)g_hash_table_lookup(
                                 g_images, GSIZE_TO_POINTER((gsize)h))
                           : NULL;
  if (!pb || !p) return false;
  GError *e = NULL;
  gboolean ok = gdk_pixbuf_save(pb, p, "png", &e, NULL);
  if (e) g_error_free(e);
  return ok ? true : false;
}
void *na_image_native_ptr(int64_t h) {
  if (!g_images) return NULL;
  return g_hash_table_lookup(g_images, GSIZE_TO_POINTER((gsize)h));
}
void na_menu_item_set_icon_ptr(uint32_t id, void *p) {
  (void)id; (void)p;
}
void na_tray_set_icon_ptr(uint32_t id, void *p) {
  (void)id; (void)p;
}

// ================= keyboard / hotkey / mouse =================
typedef void (*na_keyboard_event_fn)(int kind, int keycode, unsigned int mods,
                                     void *ctx);
static na_keyboard_event_fn g_kb_fn = NULL;
static void *g_kb_ctx = NULL;
bool na_keyboard_start(na_keyboard_event_fn fn, void *ctx) {
  g_kb_fn = fn;
  g_kb_ctx = ctx;
  return false; // Global taps need X11; in-app controllers in phase 4.
}
void na_keyboard_stop(void) {}
bool na_keyboard_is_running(void) { return false; }

typedef void (*na_hotkey_fn)(unsigned int id, void *ctx);
static na_hotkey_fn g_hk_fn = NULL;
static void *g_hk_ctx = NULL;
void na_hotkey_set_callback(na_hotkey_fn fn, void *ctx) {
  g_hk_fn = fn;
  g_hk_ctx = ctx;
}
static GHashTable *g_hotkeys = NULL; // lowercased accel -> id
static void ensure_hotkeys(void){ if(!g_hotkeys) g_hotkeys=g_hash_table_new_full(g_str_hash,g_str_equal,g_free,NULL); }
static char *lower_accel(const char *s){
  if(!s) return g_strdup("");
  char *d=g_strdup(s);
  for(char *p=d;*p;p++) *p=g_ascii_tolower(*p);
  return d;
}
bool na_hotkey_register(unsigned int id, const char *accel) {
  ensure_hotkeys();
  char *low=lower_accel(accel?accel:"");
  if(g_hash_table_contains(g_hotkeys, low)){
    g_free(low);
    return false;
  }
  g_hash_table_insert(g_hotkeys, low, GUINT_TO_POINTER(id));
  return true;
}
bool na_hotkey_unregister(unsigned int id) {
  ensure_hotkeys();
  // find and remove by id
  GHashTableIter it; gpointer k,v;
  g_hash_table_iter_init(&it,g_hotkeys);
  while(g_hash_table_iter_next(&it,&k,&v)){
    if(GPOINTER_TO_UINT(v)==id){ g_hash_table_iter_remove(&it); return true; }
  }
  return true;
}

typedef void (*na_mouse_event_fn)(int kind, double x, double y, int clicks,
                                  void *ctx);
bool na_mouse_start_monitor(bool own, na_mouse_event_fn fn, void *ctx) {
  (void)own; (void)fn; (void)ctx;
  return true;
}
void na_mouse_stop_monitors(void) {}

// ================= clipboard (GtkClipboard, GTK3 path) =================
static char *g_clip_text = NULL;
static int g_clip_count = 0;
static char **g_clip_files = NULL;
static int g_clip_files_n = 0;
static int64_t g_clip_image = 0;

static void clip_free_files(void) {
  if (g_clip_files) {
    for (int i = 0; i < g_clip_files_n; i++) free(g_clip_files[i]);
    free(g_clip_files);
    g_clip_files = NULL;
    g_clip_files_n = 0;
  }
}

void na_clipboard_set_text(const char *t) {
  free(g_clip_text);
  g_clip_text = na_gui_dup_string(t ? t : "");
  g_clip_count++;
  clip_free_files();
  g_clip_image = 0;
#if !GTK_CHECK_VERSION(4, 0, 0)
  if (gdk_display_get_default()) {
    GtkClipboard *cb = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
    if (cb) gtk_clipboard_set_text(cb, t ? t : "", -1);
  }
#endif
}
const char *na_clipboard_get_text(void) {
#if !GTK_CHECK_VERSION(4, 0, 0)
  if (gdk_display_get_default()) {
    GtkClipboard *cb = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
    if (cb && gtk_clipboard_wait_is_text_available(cb)) {
      char *t = gtk_clipboard_wait_for_text(cb);
      if (t) {
        free(g_clip_text);
        g_clip_text = na_gui_dup_string(t);
        g_free(t);
      }
    }
  }
#endif
  return na_gui_copy_string(g_clip_text ? g_clip_text : "");
}
void na_clipboard_clear(void) {
  free(g_clip_text);
  g_clip_text = na_gui_dup_string("");
  g_clip_count++;
  clip_free_files();
  g_clip_image = 0;
#if !GTK_CHECK_VERSION(4, 0, 0)
  if (gdk_display_get_default()) {
    GtkClipboard *cb = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
    if (cb) gtk_clipboard_clear(cb);
  }
#endif
}
int na_clipboard_change_count(void) { return g_clip_count; }
void na_clipboard_set_image_handle(int64_t h) {
  g_clip_image = h;
  g_clip_count++;
}
int64_t na_clipboard_get_image_handle(void) { return g_clip_image; }
void na_clipboard_set_file_paths(const char **paths, int count) {
  clip_free_files();
  g_clip_count++;
  free(g_clip_text);
  g_clip_text = na_gui_dup_string("");
  g_clip_image = 0;
  if (!paths || count <= 0) return;
  g_clip_files = (char **)malloc(sizeof(char *) * (size_t)count);
  g_clip_files_n = count;
  for (int i = 0; i < count; i++) {
    g_clip_files[i] = na_gui_dup_string(paths[i] ? paths[i] : "");
  }
}
const char **na_clipboard_get_file_paths(int *out_count) {
  if (!g_clip_files || g_clip_files_n == 0) {
    if (out_count) *out_count = 0;
    return NULL;
  }
  char **out = (char **)malloc(sizeof(char *) * (size_t)g_clip_files_n);
  for (int i = 0; i < g_clip_files_n; i++) out[i] = na_gui_dup_string(g_clip_files[i]);
  if (out_count) *out_count = g_clip_files_n;
  return (const char **)out;
}
void na_clipboard_free_string(const char *t) { (void)t; }
void na_clipboard_free_string_list(const char **l, int c) {
  if (!l) return;
  for (int i = 0; i < c; i++) free((void *)l[i]);
  free((void *)l);
}

// ================= file dialogs (native in phase 4) =================
void *na_open_panel_create(const char *t) {
  (void)t;
  return (void *)0x1;
}
void na_open_panel_set_can_choose_directories(void *p, bool v) {
  (void)p; (void)v;
}
void na_open_panel_set_allows_multiple(void *p, bool v) {
  (void)p; (void)v;
}
void na_open_panel_set_filters(void *p, const char **exts, int n) {
  (void)p; (void)exts; (void)n;
}
void na_open_panel_set_initial_directory(void *p, const char *path) {
  (void)p; (void)path;
}
int na_open_panel_run_modal(void *p, const char ***out_paths) {
  (void)p;
  if (out_paths) *out_paths = NULL;
  return 0;
}
void *na_save_panel_create(const char *t, const char *d) {
  (void)t; (void)d;
  return (void *)0x1;
}
void na_save_panel_set_name_field(void *p, const char *n) {
  (void)p; (void)n;
}
void na_save_panel_set_filters(void *p, const char **exts, int n) {
  (void)p; (void)exts; (void)n;
}
const char *na_save_panel_run_modal(void *p) {
  (void)p;
  return na_gui_copy_string("");
}

// ================= notifications (D-Bus real in phase 5) ================
typedef void (*na_notif_auth_fn)(int granted, void *ctx);
typedef void (*na_notif_response_fn)(unsigned int id, const char *action,
                                     void *ctx);
static na_notif_response_fn g_notif_fn = NULL;
static void *g_notif_ctx = NULL;
static unsigned int g_notif_next = 0;

bool na_notifications_supported(void) { return true; }
int na_notifications_auth_status(void) { return 2; /* granted */ }
void na_notifications_request_auth(na_notif_auth_fn fn, void *ctx) {
  // No permission model on freedesktop; grant immediately (async to match
  // macOS trampoline shape).
  if (fn) fn(1, ctx);
}
void na_notifications_set_response_callback(na_notif_response_fn fn,
                                             void *ctx) {
  g_notif_fn = fn;
  g_notif_ctx = ctx;
}
unsigned int na_notifications_show(const char *title, const char *sub,
                                    const char *body, bool sound) {
  (void)title; (void)sub; (void)body; (void)sound;
  return ++g_notif_next;
}
void na_notifications_cancel(unsigned int id) { (void)id; }

// ================= alerts =================
typedef void (*na_alert_click_fn)(int64_t handle, unsigned int wid, void *ctx);
static na_alert_click_fn g_alert_fn = NULL;
static int64_t g_alert_next = 0;
static GHashTable *g_alert_counts = NULL;
void na_alert_set_click_callback(na_alert_click_fn fn) { g_alert_fn = fn; }
int64_t na_alert_create(const char *t, const char *m, int style) {
  (void)t; (void)m; (void)style;
  if (!g_alert_counts)
    g_alert_counts = g_hash_table_new(g_direct_hash, g_direct_equal);
  int64_t h = ++g_alert_next;
  g_hash_table_insert(g_alert_counts, GSIZE_TO_POINTER((gsize)h),
                      GINT_TO_POINTER(0));
  return h;
}
void na_alert_destroy(int64_t h) {
  if (g_alert_counts)
    g_hash_table_remove(g_alert_counts, GSIZE_TO_POINTER((gsize)h));
}
void na_alert_add_button(int64_t h, const char *label, bool def,
                          unsigned int wid) {
  (void)label; (void)def; (void)wid;
  if (!g_alert_counts) return;
  gpointer k = GSIZE_TO_POINTER((gsize)h);
  int n = GPOINTER_TO_INT(g_hash_table_lookup(g_alert_counts, k));
  g_hash_table_replace(g_alert_counts, k, GINT_TO_POINTER(n + 1));
}
int na_alert_button_count(int64_t h) {
  if (!g_alert_counts) return 0;
  return GPOINTER_TO_INT(
      g_hash_table_lookup(g_alert_counts, GSIZE_TO_POINTER((gsize)h)));
}
void na_alert_set_accessory_view(int64_t h, void *v) {
  (void)h; (void)v;
}
int na_alert_run_modal(int64_t h) {
  (void)h;
  return 0;
}
void na_alert_stop_modal(int64_t h) { (void)h; }
