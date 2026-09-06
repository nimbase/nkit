#include <gtk/gtk.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include "gui_common.h"
#include "na_compat.h"

GtkApplication *na_linux_gtk_app(void);
void na_view_remove_all(void *parent_ptr);
void na_view_add_subview(void *parent_ptr, void *child_ptr);

__thread char g_gui_text_buffer[8192];

typedef void (*na_window_event_fn)(int kind, uint32_t window_id, double a,
                                   double b, void *ctx);
static na_window_event_fn g_win_fn = NULL;
static void *g_win_ctx = NULL;

typedef struct {
  GtkWidget *win;
  GtkWidget *root; // content-box child (fixed for absolute layout)
  double x, y, w, h;
  double min_w, min_h, max_w, max_h;
  char title[512];
  bool visible, maximized, minimized, fullscreen;
  bool resizable, movable, minimizable, maximizable, closable;
  bool always_on_top, all_workspaces, ignore_mouse, has_shadow;
  float opacity;
  unsigned char bg[4];
  int title_bar_style, visual_effect;
} WinState;

static GHashTable *g_windows = NULL;
static uint32_t g_next_seq = 0;

static void ensure_table(void) {
  if (!g_windows) {
    g_windows = g_hash_table_new(g_direct_hash, g_direct_equal);
  }
}

static uint32_t alloc_id(void) {
  g_next_seq += 1;
  return (1u << 24) | g_next_seq;
}

static WinState *find_win(uint32_t id) {
  ensure_table();
  return (WinState *)g_hash_table_lookup(g_windows, GUINT_TO_POINTER(id));
}

static GtkWidget *make_root_container(void) {
#if NA_GTK4
  GtkWidget *f = gtk_fixed_new();
  gtk_widget_set_hexpand(f, TRUE);
  gtk_widget_set_vexpand(f, TRUE);
  return f;
#else
  GtkWidget *f = gtk_fixed_new();
  return f;
#endif
}

uint32_t na_window_create(void) {
  na_linux_ensure_gtk();
  ensure_table();
  GtkApplication *app = na_linux_gtk_app();
  GtkWidget *win = na_compat_window_new(app);
  gtk_window_set_default_size(GTK_WINDOW(win), 400, 300);
  GtkWidget *root = make_root_container();
#if NA_GTK4
  gtk_window_set_child(GTK_WINDOW(win), root);
#else
  gtk_container_add(GTK_CONTAINER(win), root);
#endif
  WinState *st = (WinState *)calloc(1, sizeof(WinState));
  st->win = win;
  st->root = root;
  st->x = 0;
  st->y = 0;
  st->w = 400;
  st->h = 300;
  st->resizable = true;
  st->movable = true;
  st->minimizable = true;
  st->maximizable = true;
  st->closable = true;
  st->has_shadow = true;
  st->opacity = 1.0f;
  st->bg[0] = st->bg[1] = st->bg[2] = 255;
  st->bg[3] = 255;
  // Keep widget alive beyond Nim GC: extra ref owned by registry.
  g_object_ref_sink(win);
  uint32_t id = alloc_id();
  g_hash_table_insert(g_windows, GUINT_TO_POINTER(id), st);
  g_object_set_data(G_OBJECT(win), "nkit-window-id",
                    GUINT_TO_POINTER(id));
  return id;
}

void na_window_free(uint32_t id) {
  WinState *st = find_win(id);
  if (!st) return;
  g_hash_table_remove(g_windows, GUINT_TO_POINTER(id));
  if (st->win) {
    gtk_widget_destroy(st->win);
    g_object_unref(st->win);
  }
  free(st);
}

bool na_window_exists(uint32_t id) { return find_win(id) != NULL; }

void na_window_focus(uint32_t id) {
  WinState *st = find_win(id);
  if (!st) return;
#if !NA_GTK4
  gtk_window_present(GTK_WINDOW(st->win));
#else
  gtk_window_present(GTK_WINDOW(st->win));
#endif
}

void na_window_blur(uint32_t id) {
  (void)id; // No cross-platform blur; compositor owns focus.
}

bool na_window_is_focused(uint32_t id) {
  WinState *st = find_win(id);
  if (!st) return false;
  return gtk_window_is_active(GTK_WINDOW(st->win)) ? true : false;
}

void na_window_show(uint32_t id) {
  WinState *st = find_win(id);
  if (!st) return;
  st->visible = true;
  na_compat_show(st->win);
#if !NA_GTK4
  gtk_widget_show_all(st->win);
  gtk_window_present(GTK_WINDOW(st->win));
#else
  gtk_window_present(GTK_WINDOW(st->win));
#endif
}

void na_window_show_inactive(uint32_t id) {
  WinState *st = find_win(id);
  if (!st) return;
  st->visible = true;
#if NA_GTK4
  gtk_widget_set_visible(st->win, TRUE);
#else
  gtk_widget_show_all(st->win);
#endif
}

void na_window_hide(uint32_t id) {
  WinState *st = find_win(id);
  if (!st) return;
  st->visible = false;
  gtk_widget_hide(st->win);
}

bool na_window_is_visible(uint32_t id) {
  WinState *st = find_win(id);
  if (!st) return false;
  return st->visible;
}

void na_window_maximize(uint32_t id) {
  WinState *st = find_win(id);
  if (!st) return;
  st->maximized = true;
  gtk_window_maximize(GTK_WINDOW(st->win));
}
void na_window_unmaximize(uint32_t id) {
  WinState *st = find_win(id);
  if (!st) return;
  st->maximized = false;
  gtk_window_unmaximize(GTK_WINDOW(st->win));
}
bool na_window_is_maximized(uint32_t id) {
  WinState *st = find_win(id);
  return st ? st->maximized : false;
}

void na_window_minimize(uint32_t id) {
  WinState *st = find_win(id);
  if (!st) return;
  st->minimized = true;
  gtk_window_iconify(GTK_WINDOW(st->win));
}
void na_window_restore(uint32_t id) {
  WinState *st = find_win(id);
  if (!st) return;
  st->minimized = false;
#if !NA_GTK4
  gtk_window_deiconify(GTK_WINDOW(st->win));
#else
  gtk_window_unminimize(GTK_WINDOW(st->win));
#endif
}
bool na_window_is_minimized(uint32_t id) {
  WinState *st = find_win(id);
  return st ? st->minimized : false;
}

void na_window_set_full_screen(uint32_t id, bool fs) {
  WinState *st = find_win(id);
  if (!st) return;
  st->fullscreen = fs;
  if (fs) gtk_window_fullscreen(GTK_WINDOW(st->win));
  else gtk_window_unfullscreen(GTK_WINDOW(st->win));
}
bool na_window_is_full_screen(uint32_t id) {
  WinState *st = find_win(id);
  return st ? st->fullscreen : false;
}

void na_window_set_bounds(uint32_t id, double x, double y, double w, double h) {
  WinState *st = find_win(id);
  if (!st) return;
  st->x = x; st->y = y; st->w = w; st->h = h;
  gtk_window_set_default_size(GTK_WINDOW(st->win), (int)w, (int)h);
#if !NA_GTK4
  gtk_window_move(GTK_WINDOW(st->win), (int)x, (int)y);
  gtk_window_resize(GTK_WINDOW(st->win), (int)w, (int)h);
#endif
  if (g_win_fn) { g_win_fn(4, id, x, y, g_win_ctx); g_win_fn(5, id, w, h, g_win_ctx); }
}
void na_window_get_bounds(uint32_t id, double *ox, double *oy, double *ow,
                           double *oh) {
  WinState *st = find_win(id);
  if (!st) { *ox = 0; *oy = 0; *ow = 0; *oh = 0; return; }
  *ox = st->x; *oy = st->y; *ow = st->w; *oh = st->h;
}

void na_window_set_size(uint32_t id, double w, double h, bool animate) {
  (void)animate;
  WinState *st = find_win(id);
  if (!st) return;
  st->w = w; st->h = h;
  gtk_window_set_default_size(GTK_WINDOW(st->win), (int)w, (int)h);
#if !NA_GTK4
  gtk_window_resize(GTK_WINDOW(st->win), (int)w, (int)h);
#endif
  if (g_win_fn) g_win_fn(5, id, w, h, g_win_ctx);
}
void na_window_get_size(uint32_t id, double *ow, double *oh) {
  WinState *st = find_win(id);
  if (!st) { *ow = 0; *oh = 0; return; }
  *ow = st->w; *oh = st->h;
}

void na_window_set_content_size(uint32_t id, double w, double h) {
  na_window_set_size(id, w, h, false);
  // already fired via set_size
}
void na_window_set_max_size(uint32_t id, double w, double h) {
  WinState *st = find_win(id);
  if (!st) return;
  st->max_w = w; st->max_h = h;
}
void na_window_set_min_size(uint32_t id, double w, double h) {
  WinState *st = find_win(id);
  if (!st) return;
  st->min_w = w; st->min_h = h;
}
void na_window_get_content_size(uint32_t id, double *ow, double *oh) {
  na_window_get_size(id, ow, oh);
}
void na_window_set_content_bounds(uint32_t id, double x, double y, double w,
                                   double h) {
  na_window_set_bounds(id, x, y, w, h);
}
void na_window_get_content_bounds(uint32_t id, double *ox, double *oy,
                                   double *ow, double *oh) {
  na_window_get_bounds(id, ox, oy, ow, oh);
}
void na_window_set_minimum_size(uint32_t id, double w, double h) {
  WinState *st = find_win(id);
  if (!st) return;
  st->min_w = w; st->min_h = h;
}
void na_window_get_minimum_size(uint32_t id, double *ow, double *oh) {
  WinState *st = find_win(id);
  if (!st) { *ow = 0; *oh = 0; return; }
  *ow = st->min_w; *oh = st->min_h;
}
void na_window_set_maximum_size(uint32_t id, double w, double h) {
  WinState *st = find_win(id);
  if (!st) return;
  st->max_w = w; st->max_h = h;
}
void na_window_get_maximum_size(uint32_t id, double *ow, double *oh) {
  WinState *st = find_win(id);
  if (!st) { *ow = 0; *oh = 0; return; }
  *ow = st->max_w; *oh = st->max_h;
}
void na_window_set_position(uint32_t id, double x, double y) {
  WinState *st = find_win(id);
  if (!st) return;
  st->x = x; st->y = y;
#if !NA_GTK4
  gtk_window_move(GTK_WINDOW(st->win), (int)x, (int)y);
#else
  (void)x; (void)y; // Wayland: compositor owns position.
#endif
  if (g_win_fn) g_win_fn(4, id, x, y, g_win_ctx);
}
void na_window_get_position(uint32_t id, double *ox, double *oy) {
  WinState *st = find_win(id);
  if (!st) { *ox = 0; *oy = 0; return; }
  *ox = st->x; *oy = st->y;
}
void na_window_center(uint32_t id) {
  WinState *st = find_win(id);
  if (!st) return;
  gtk_window_set_position(GTK_WINDOW(st->win), GTK_WIN_POS_CENTER);
}

void na_window_set_title(uint32_t id, const char *t) {
  WinState *st = find_win(id);
  if (!st || !t) return;
  strncpy(st->title, t, sizeof(st->title) - 1);
  st->title[sizeof(st->title) - 1] = '\0';
  gtk_window_set_title(GTK_WINDOW(st->win), t);
}
const char *na_window_get_title(uint32_t id) {
  WinState *st = find_win(id);
  if (!st) return na_gui_copy_string("");
  return na_gui_copy_string(st->title);
}

void na_window_set_resizable(uint32_t id, bool v) {
  WinState *st = find_win(id);
  if (!st) return;
  st->resizable = v;
  gtk_window_set_resizable(GTK_WINDOW(st->win), v ? TRUE : FALSE);
}
bool na_window_is_resizable(uint32_t id) {
  WinState *st = find_win(id);
  return st ? st->resizable : false;
}
void na_window_set_movable(uint32_t id, bool v) {
  WinState *st = find_win(id);
  if (st) st->movable = v;
}
bool na_window_is_movable(uint32_t id) {
  WinState *st = find_win(id);
  return st ? st->movable : false;
}
void na_window_set_minimizable(uint32_t id, bool v) {
  WinState *st = find_win(id);
  if (st) st->minimizable = v;
}
bool na_window_is_minimizable(uint32_t id) {
  WinState *st = find_win(id);
  return st ? st->minimizable : false;
}
void na_window_set_maximizable(uint32_t id, bool v) {
  WinState *st = find_win(id);
  if (st) st->maximizable = v;
}
bool na_window_is_maximizable(uint32_t id) {
  WinState *st = find_win(id);
  return st ? st->maximizable : false;
}
void na_window_set_closable(uint32_t id, bool v) {
  WinState *st = find_win(id);
  if (!st) return;
  st->closable = v;
  gtk_window_set_deletable(GTK_WINDOW(st->win), v ? TRUE : FALSE);
}
bool na_window_is_closable(uint32_t id) {
  WinState *st = find_win(id);
  return st ? st->closable : false;
}
void na_window_set_always_on_top(uint32_t id, bool v) {
  WinState *st = find_win(id);
  if (!st) return;
  st->always_on_top = v;
  gtk_window_set_keep_above(GTK_WINDOW(st->win), v ? TRUE : FALSE);
}
bool na_window_is_always_on_top(uint32_t id) {
  WinState *st = find_win(id);
  return st ? st->always_on_top : false;
}
void na_window_set_visible_on_all_workspaces(uint32_t id, bool v) {
  WinState *st = find_win(id);
  if (st) st->all_workspaces = v;
}
bool na_window_is_visible_on_all_workspaces(uint32_t id) {
  WinState *st = find_win(id);
  return st ? st->all_workspaces : false;
}
void na_window_set_ignore_mouse_events(uint32_t id, bool v) {
  WinState *st = find_win(id);
  if (st) st->ignore_mouse = v;
}
bool na_window_is_ignore_mouse_events(uint32_t id) {
  WinState *st = find_win(id);
  return st ? st->ignore_mouse : false;
}
bool na_window_is_focusable(uint32_t id) {
  return find_win(id) != NULL;
}

void na_window_set_has_shadow(uint32_t id, bool v) {
  WinState *st = find_win(id);
  if (st) st->has_shadow = v;
}
bool na_window_has_shadow(uint32_t id) {
  WinState *st = find_win(id);
  return st ? st->has_shadow : false;
}
void na_window_set_opacity(uint32_t id, float o) {
  WinState *st = find_win(id);
  if (!st) return;
  st->opacity = o;
  gtk_widget_set_opacity(st->win, o);
}
float na_window_get_opacity(uint32_t id) {
  WinState *st = find_win(id);
  return st ? st->opacity : 1.0f;
}
void na_window_set_background_color(uint32_t id, unsigned char r,
                                     unsigned char g, unsigned char b,
                                     unsigned char a) {
  WinState *st = find_win(id);
  if (!st) return;
  st->bg[0] = r; st->bg[1] = g; st->bg[2] = b; st->bg[3] = a;
}
void na_window_get_background_color(uint32_t id, unsigned char *r,
                                     unsigned char *g, unsigned char *b,
                                     unsigned char *a) {
  WinState *st = find_win(id);
  if (!st) { *r = 255; *g = 255; *b = 255; *a = 255; return; }
  *r = st->bg[0]; *g = st->bg[1]; *b = st->bg[2]; *a = st->bg[3];
}

void na_window_set_title_bar_style(uint32_t id, int style) {
  WinState *st = find_win(id);
  if (!st) return;
  st->title_bar_style = style;
  gtk_window_set_decorated(GTK_WINDOW(st->win), style == 0 ? TRUE : FALSE);
}
int na_window_get_title_bar_style(uint32_t id) {
  WinState *st = find_win(id);
  return st ? st->title_bar_style : 0;
}
void na_window_set_visual_effect(uint32_t id, int fx) {
  WinState *st = find_win(id);
  if (st) st->visual_effect = fx;
}
int na_window_get_visual_effect(uint32_t id) {
  WinState *st = find_win(id);
  return st ? st->visual_effect : 0;
}

void na_window_start_dragging(uint32_t id) { (void)id; }

int na_window_list_ids(uint32_t *out, int max_count) {
  ensure_table();
  int n = 0;
  GHashTableIter it;
  gpointer k, v;
  g_hash_table_iter_init(&it, g_windows);
  while (g_hash_table_iter_next(&it, &k, &v)) {
    if (n >= max_count) break;
    out[n++] = GPOINTER_TO_UINT(k);
  }
  return n;
}

uint32_t na_window_main_window_id(void) {
  ensure_table();
  GHashTableIter it;
  gpointer k, v;
  g_hash_table_iter_init(&it, g_windows);
  if (g_hash_table_iter_next(&it, &k, &v)) return GPOINTER_TO_UINT(k);
  return 0;
}

void na_window_set_event_callback(na_window_event_fn fn, void *ctx) {
  g_win_fn = fn;
  g_win_ctx = ctx;
}

void *na_window_content_view(uint32_t id) {
  WinState *st = find_win(id);
  return st ? (void *)st->root : NULL;
}

void *na_window_native(uint32_t id) {
  WinState *st = find_win(id);
  return st ? (void *)st->win : NULL;
}

void na_window_set_root_view(uint32_t id, void *view_ptr) {
  WinState *st = find_win(id);
  GtkWidget *root = (GtkWidget *)view_ptr;
  if (!st || !root || !st->root) return;
  GtkWidget *container = st->root;
  // Clear previous content
  na_view_remove_all((void*)container);
  // Make root fill the window content area (400x300 etc)
  NkitViewState *rst = nkit_state_of(root);
  rst->x = 0; rst->y = 0; rst->w = st->w; rst->h = st->h;
  gtk_widget_set_size_request(root, (int)st->w, (int)st->h);
  na_view_add_subview((void*)container, root);
  // Ensure fill for fixed container (bottom origin y=0 -> top 0)
  // na_view_constrain_fill will handle, but we already set size
  gtk_widget_queue_resize(container);
}
