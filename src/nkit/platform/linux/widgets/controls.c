#include <gtk/gtk.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>
#include "gui_common.h"
#include "na_compat.h"

// Forward declarations (implemented in view.c, same link unit).
void *na_view_create(void);
void na_view_remove_all(void *parent_ptr);
int na_view_subview_count(void *parent_ptr);
int na_split_view_pane_count(void *v);

// ================= button (real) =================
typedef void (*na_button_event_fn)(uint32_t widget_id, void *ctx);
static na_button_event_fn g_button_fn = NULL;
static void *g_button_ctx = NULL;

void na_button_set_event_callback(na_button_event_fn fn, void *ctx) {
  g_button_fn = fn;
  g_button_ctx = ctx;
}

static void button_clicked_cb(GtkWidget *w, gpointer ud) {
  (void)ud;
  if (!g_button_fn) return;
  uint32_t id = GPOINTER_TO_UINT(g_object_get_data(G_OBJECT(w), "nkit-id"));
  g_button_fn(id, g_button_ctx);
}

void *na_button_create(uint32_t widget_id, int style) {
  na_linux_ensure_gtk();
  (void)style;
  GtkWidget *b = gtk_button_new_with_label("");
  g_object_set_data(G_OBJECT(b), "nkit-id", GUINT_TO_POINTER(widget_id));
  g_object_set_data(G_OBJECT(b), "nkit-state", GINT_TO_POINTER(0));
  g_signal_connect(b, "clicked", G_CALLBACK(button_clicked_cb), NULL);
#if !NA_GTK4
  gtk_widget_show(b);
#endif
  g_object_ref_sink(b);
  return (void *)b;
}
void na_button_free(uint32_t widget_id, void *view_ptr) {
  (void)widget_id;
  GtkWidget *w = (GtkWidget *)view_ptr;
  if (!w) return;
  GtkWidget *p = gtk_widget_get_parent(w);
  if (p) na_compat_container_remove(p, w);
  g_object_unref(w);
}
void na_button_set_title(void *v, const char *t) {
  if (v && t) gtk_button_set_label(GTK_BUTTON(v), t);
}
const char *na_button_get_title(void *v) {
  if (!v) return na_gui_copy_string("");
  const char *s = gtk_button_get_label(GTK_BUTTON(v));
  return na_gui_copy_string(s ? s : "");
}
void na_button_set_state(void *v, int s) {
  if (v) g_object_set_data(G_OBJECT(v), "nkit-state", GINT_TO_POINTER(s));
}
int na_button_get_state(void *v) {
  if (!v) return 0;
  return GPOINTER_TO_INT(g_object_get_data(G_OBJECT(v), "nkit-state"));
}
void na_button_set_enabled(void *v, bool e) {
  if (v) gtk_widget_set_sensitive((GtkWidget *)v, e ? TRUE : FALSE);
}
bool na_button_is_enabled(void *v) {
  if (!v) return false;
  return gtk_widget_get_sensitive((GtkWidget *)v) ? true : false;
}
void na_button_fire(uint32_t widget_id) {
  if (g_button_fn) g_button_fn(widget_id, g_button_ctx);
}

// ================= label (real) =================
void *na_label_create(void) {
  na_linux_ensure_gtk();
  GtkWidget *l = gtk_label_new("");
  gtk_label_set_xalign(GTK_LABEL(l), 0.0f);
#if !NA_GTK4
  gtk_widget_show(l);
#endif
  g_object_ref_sink(l);
  return (void *)l;
}
void na_label_free(void *v) {
  GtkWidget *w = (GtkWidget *)v;
  if (!w) return;
  GtkWidget *p = gtk_widget_get_parent(w);
  if (p) na_compat_container_remove(p, w);
  g_object_unref(w);
}
void na_label_set_text(void *v, const char *t) {
  if (v) gtk_label_set_text(GTK_LABEL(v), t ? t : "");
}
const char *na_label_get_text(void *v) {
  if (!v) return na_gui_copy_string("");
  const char *s = gtk_label_get_text(GTK_LABEL(v));
  return na_gui_copy_string(s ? s : "");
}
void na_label_set_text_color(void *v, unsigned char r, unsigned char g,
                              unsigned char b, unsigned char a) {
  (void)v; (void)r; (void)g; (void)b; (void)a; // CSS phase 6.
}
void na_label_set_font_size(void *v, double size) {
  if (!v) return;
  if (!gdk_display_get_default()) return; // Headless: no style context.
  char css[128];
  snprintf(css, sizeof(css), "* { font-size: %.1fpt; }", size);
#if !NA_GTK4
  GtkCssProvider *p = gtk_css_provider_new();
  gtk_css_provider_load_from_data(p, css, -1, NULL);
  GtkStyleContext *sc = gtk_widget_get_style_context((GtkWidget *)v);
  gtk_style_context_add_provider(sc, GTK_STYLE_PROVIDER(p),
                                 GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  g_object_unref(p);
#else
  (void)css;
#endif
}
void na_label_set_font_weight(void *v, int w) {
  (void)v; (void)w;
}
void na_label_set_alignment(void *v, int a) {
  if (!v) return;
  // 0 left, 1 center, 2 right (matches macOS contract order).
  float x = 0.0f;
  if (a == 1) x = 0.5f;
  else if (a == 2) x = 1.0f;
  gtk_label_set_xalign(GTK_LABEL(v), x);
}
void na_label_set_wraps(void *v, bool wraps, int max_lines) {
  (void)max_lines;
  if (v) gtk_label_set_line_wrap(GTK_LABEL(v), wraps ? TRUE : FALSE);
}

// ================= separator (real) =================
void *na_separator_create(int orientation) {
  na_linux_ensure_gtk();
  GtkWidget *s =
#if NA_GTK4
      gtk_separator_new(orientation == 1 ? GTK_ORIENTATION_VERTICAL
                                        : GTK_ORIENTATION_HORIZONTAL);
#else
      orientation == 1 ? gtk_vseparator_new() : gtk_hseparator_new();
#endif
  g_object_set_data(G_OBJECT(s), "nkit-orient", GINT_TO_POINTER(orientation));
  // Initialize ViewState size for thickness tests (default 1)
  NkitViewState *st = nkit_state_of(s);
  if (orientation == 0) st->h = 1.0;
  else st->w = 1.0;
#if !NA_GTK4
  gtk_widget_show(s);
#endif
  g_object_ref_sink(s);
  return (void *)s;
}
void na_separator_free(void *v) {
  GtkWidget *w = (GtkWidget *)v;
  if (!w) return;
  GtkWidget *p = gtk_widget_get_parent(w);
  if (p) na_compat_container_remove(p, w);
  g_object_unref(w);
}
void na_separator_set_thickness(void *v, double t) {
  if (!v) return;
  NkitViewState *st = nkit_state_of((GtkWidget*)v);
  if (st) {
    // For horizontal separator, height = thickness
    GtkWidget *w = (GtkWidget*)v;
    GtkOrientation orient = GTK_ORIENTATION_HORIZONTAL;
    // Detect orientation via size request orientation? Heuristic: if created as vertical, orientation vertical
    // Use stored orient via object data if available, else assume horizontal
    // We store orientation in nkit-orient during creation
    gpointer o = g_object_get_data(G_OBJECT(v), "nkit-orient");
    if (o) orient = GPOINTER_TO_INT(o) == 1 ? GTK_ORIENTATION_VERTICAL : GTK_ORIENTATION_HORIZONTAL;
    if (orient == GTK_ORIENTATION_HORIZONTAL) st->h = t;
    else st->w = t;
    if (st->w > 0 || st->h > 0) gtk_widget_set_size_request(w, (int)(st->w>0?st->w:-1), (int)(st->h>0?st->h:-1));
  }
  // Also set GTK size request directly
  GtkOrientation orient2 = GTK_ORIENTATION_HORIZONTAL;
  gpointer o2 = g_object_get_data(G_OBJECT(v), "nkit-orient");
  if (o2) orient2 = GPOINTER_TO_INT(o2)==1?GTK_ORIENTATION_VERTICAL:GTK_ORIENTATION_HORIZONTAL;
  if (orient2 == GTK_ORIENTATION_HORIZONTAL) gtk_widget_set_size_request((GtkWidget*)v, -1, (int)t);
  else gtk_widget_set_size_request((GtkWidget*)v, (int)t, -1);
}

// ================= stack (real) =================
void *na_stack_create(int orientation) {
  na_linux_ensure_gtk();
  GtkWidget *b = na_compat_box_new(orientation, 0);
#if !NA_GTK4
  gtk_widget_show(b);
#endif
  g_object_ref_sink(b);
  return (void *)b;
}
void na_stack_free(void *v) {
  GtkWidget *w = (GtkWidget *)v;
  if (!w) return;
  GtkWidget *p = gtk_widget_get_parent(w);
  if (p) na_compat_container_remove(p, w);
  g_object_unref(w);
}
void na_stack_set_spacing(void *v, double s) {
  if (!v) return;
#if NA_GTK4
  gtk_box_set_spacing(GTK_BOX(v), (int)s);
#else
  gtk_box_set_spacing(GTK_BOX(v), (gint)s);
#endif
}
void na_stack_set_padding(void *v, double l, double t, double r, double b) {
  if (!v) return;
#if NA_GTK4
  gtk_widget_set_margin_start((GtkWidget *)v, (int)l);
  gtk_widget_set_margin_top((GtkWidget *)v, (int)t);
  gtk_widget_set_margin_end((GtkWidget *)v, (int)r);
  gtk_widget_set_margin_bottom((GtkWidget *)v, (int)b);
#else
  gtk_widget_set_margin_left((GtkWidget *)v, (int)l);
  gtk_widget_set_margin_top((GtkWidget *)v, (int)t);
  gtk_widget_set_margin_right((GtkWidget *)v, (int)r);
  gtk_widget_set_margin_bottom((GtkWidget *)v, (int)b);
#endif
}
void na_stack_set_alignment(void *v, int a) {
  (void)v; (void)a;
}
void na_stack_add_arranged(void *stack, void *child) {
  if (!stack || !child) return;
  GtkWidget *old = gtk_widget_get_parent((GtkWidget *)child);
  if (old && old != (GtkWidget *)stack)
    na_compat_container_remove(old, (GtkWidget *)child);
  if (gtk_widget_get_parent((GtkWidget *)child) == (GtkWidget *)stack) return;
  na_compat_box_append((GtkWidget *)stack, (GtkWidget *)child);
}
void na_stack_insert_arranged(void *stack, void *child, int index) {
  if (!stack || !child) return;
  GtkWidget *old = gtk_widget_get_parent((GtkWidget *)child);
  if (old && old != (GtkWidget *)stack)
    na_compat_container_remove(old, (GtkWidget *)child);
#if NA_GTK4
  gtk_box_insert(GTK_BOX(stack), (GtkWidget *)child, index);
#else
  gtk_box_pack_start(GTK_BOX(stack), (GtkWidget *)child, FALSE, FALSE, 0);
  gtk_box_reorder_child(GTK_BOX(stack), (GtkWidget *)child, index);
  gtk_widget_show_all((GtkWidget *)child);
#endif
}
void na_stack_remove_arranged(void *stack, void *child) {
  if (!stack || !child) return;
  na_compat_box_remove((GtkWidget *)stack, (GtkWidget *)child);
}
int na_stack_arranged_count(void *stack) {
  if (!stack) return 0;
#if NA_GTK4
  int n = 0;
  for (GtkWidget *c = gtk_widget_get_first_child((GtkWidget *)stack); c;
       c = gtk_widget_get_next_sibling(c))
    n++;
  return n;
#else
  GList *kids = gtk_container_get_children(GTK_CONTAINER(stack));
  int n = g_list_length(kids);
  if (kids) g_list_free(kids);
  return n;
#endif
}
void na_stack_set_arranged_fill(void *v, bool fill) {
  (void)v; (void)fill;
}

// ================= input (Entry, real-ish) =================
typedef void (*na_input_event_fn)(uint32_t id, void *ctx);
static na_input_event_fn g_input_fn = NULL;
static void *g_input_ctx = NULL;
void na_input_set_event_callback(na_input_event_fn fn, void *ctx) {
  g_input_fn = fn; g_input_ctx = ctx;
}
static void input_changed_cb(GtkWidget *w, gpointer ud) {
  (void)ud;
  if (!g_input_fn) return;
  g_input_fn(GPOINTER_TO_UINT(g_object_get_data(G_OBJECT(w), "nkit-id")),
             g_input_ctx);
}
void *na_input_create(uint32_t id, int style) {
  na_linux_ensure_gtk();
  (void)style;
  GtkWidget *e = gtk_entry_new();
  g_object_set_data(G_OBJECT(e), "nkit-id", GUINT_TO_POINTER(id));
  g_signal_connect(e, "changed", G_CALLBACK(input_changed_cb), NULL);
#if !NA_GTK4
  gtk_widget_show(e);
#endif
  g_object_ref_sink(e);
  return (void *)e;
}
void na_input_free(uint32_t id, void *v) {
  (void)id;
  GtkWidget *w = (GtkWidget *)v;
  if (!w) return;
  GtkWidget *p = gtk_widget_get_parent(w);
  if (p) na_compat_container_remove(p, w);
  g_object_unref(w);
}
void na_input_set_text(void *v, const char *t) {
  if (v) gtk_entry_set_text(GTK_ENTRY(v), t ? t : "");
}
const char *na_input_get_text(void *v) {
  if (!v) return na_gui_copy_string("");
  return na_gui_copy_string(gtk_entry_get_text(GTK_ENTRY(v)));
}
void na_input_set_placeholder(void *v, const char *t) {
  if (v) gtk_entry_set_placeholder_text(GTK_ENTRY(v), t ? t : "");
}
const char *na_input_get_placeholder(void *v) {
  if (!v) return na_gui_copy_string("");
  const char *s = gtk_entry_get_placeholder_text(GTK_ENTRY(v));
  return na_gui_copy_string(s ? s : "");
}
void na_input_set_editable(void *v, bool e) {
  if (v) gtk_editable_set_editable(GTK_EDITABLE(v), e ? TRUE : FALSE);
}
bool na_input_is_editable(void *v) {
  if (!v) return false;
  return gtk_editable_get_editable(GTK_EDITABLE(v)) ? true : false;
}
void na_input_focus(uint32_t id, void *v) {
  (void)id;
  if (v) gtk_widget_grab_focus((GtkWidget *)v);
}
void na_input_fire_change(uint32_t id) {
  if (g_input_fn) g_input_fn(id, g_input_ctx);
}

// ================= textarea (TextView) =================
typedef void (*na_textarea_event_fn)(uint32_t id, void *ctx);
static na_textarea_event_fn g_ta_fn = NULL;
static void *g_ta_ctx = NULL;
void na_textarea_set_event_callback(na_textarea_event_fn fn, void *ctx) {
  g_ta_fn = fn; g_ta_ctx = ctx;
}
void *na_textarea_create(uint32_t id) {
  na_linux_ensure_gtk();
  GtkWidget *t = gtk_text_view_new();
  g_object_set_data(G_OBJECT(t), "nkit-id", GUINT_TO_POINTER(id));
#if !NA_GTK4
  gtk_widget_show(t);
#endif
  g_object_ref_sink(t);
  return (void *)t;
}
void na_textarea_free(uint32_t id, void *v) {
  (void)id;
  GtkWidget *w = (GtkWidget *)v;
  if (!w) return;
  GtkWidget *p = gtk_widget_get_parent(w);
  if (p) na_compat_container_remove(p, w);
  g_object_unref(w);
}
static GtkTextBuffer *ta_buf(void *v) {
  return gtk_text_view_get_buffer(GTK_TEXT_VIEW(v));
}
void na_textarea_set_text(uint32_t id, void *v, const char *t) {
  (void)id;
  if (v) gtk_text_buffer_set_text(ta_buf(v), t ? t : "", -1);
}
const char *na_textarea_get_text(uint32_t id, void *v) {
  (void)id;
  if (!v) return na_gui_copy_string("");
  GtkTextIter s, e;
  gtk_text_buffer_get_bounds(ta_buf(v), &s, &e);
  char *txt = gtk_text_buffer_get_text(ta_buf(v), &s, &e, FALSE);
  const char *out = na_gui_copy_string(txt ? txt : "");
  if (txt) g_free(txt);
  return out;
}
void na_textarea_set_editable(uint32_t id, void *v, bool e) {
  (void)id;
  if (v) gtk_text_view_set_editable(GTK_TEXT_VIEW(v), e ? TRUE : FALSE);
}
bool na_textarea_is_editable(uint32_t id, void *v) {
  (void)id;
  if (!v) return false;
  return gtk_text_view_get_editable(GTK_TEXT_VIEW(v)) ? true : false;
}
void na_textarea_fire_change(uint32_t id) {
  if (g_ta_fn) g_ta_fn(id, g_ta_ctx);
}

// ================= switch =================
typedef void (*na_switch_event_fn)(uint32_t id, void *ctx);
static na_switch_event_fn g_sw_fn = NULL;
static void *g_sw_ctx = NULL;
void na_switch_set_event_callback(na_switch_event_fn fn, void *ctx) {
  g_sw_fn = fn; g_sw_ctx = ctx;
}
static gboolean switch_state_cb(GtkWidget *w, gboolean state, gpointer ud) {
  (void)ud;
  if (g_sw_fn)
    g_sw_fn(GPOINTER_TO_UINT(g_object_get_data(G_OBJECT(w), "nkit-id")),
            g_sw_ctx);
  (void)state;
  return FALSE;
}
void *na_switch_create(uint32_t id) {
  na_linux_ensure_gtk();
  GtkWidget *s = gtk_switch_new();
  g_object_set_data(G_OBJECT(s), "nkit-id", GUINT_TO_POINTER(id));
#if !NA_GTK4
  gtk_widget_show(s);
#endif
  // Do not auto-connect state-set; programmatic setState must not emit.
  // User toggles are simulated via na_switch_fire.
  g_object_ref_sink(s);
  return (void *)s;
}
void na_switch_free(uint32_t id, void *v) {
  (void)id;
  GtkWidget *w = (GtkWidget *)v;
  if (!w) return;
  GtkWidget *p = gtk_widget_get_parent(w);
  if (p) na_compat_container_remove(p, w);
  g_object_unref(w);
}
void na_switch_set_state(void *v, bool on) {
  if (v) gtk_switch_set_active(GTK_SWITCH(v), on ? TRUE : FALSE);
}
bool na_switch_get_state(void *v) {
  if (!v) return false;
  return gtk_switch_get_active(GTK_SWITCH(v)) ? true : false;
}
void na_switch_fire(uint32_t id) {
  if (g_sw_fn) g_sw_fn(id, g_sw_ctx);
}

// ================= slider =================
typedef void (*na_slider_event_fn)(uint32_t id, double value, bool released,
                                   void *ctx);
static na_slider_event_fn g_sl_fn = NULL;
static void *g_sl_ctx = NULL;
void na_slider_set_event_callback(na_slider_event_fn fn, void *ctx) {
  g_sl_fn = fn; g_sl_ctx = ctx;
}
static void slider_value_cb(GtkWidget *w, gpointer ud) {
  (void)ud;
  if (!g_sl_fn) return;
  double v = 0;
#if !NA_GTK4
  v = gtk_range_get_value(GTK_RANGE(w));
#else
  v = gtk_range_get_value(GTK_RANGE(w));
#endif
  g_sl_fn(GPOINTER_TO_UINT(g_object_get_data(G_OBJECT(w), "nkit-id")), v,
          true, g_sl_ctx);
}
void *na_slider_create(uint32_t id) {
  na_linux_ensure_gtk();
  GtkWidget *s =
#if NA_GTK4
      gtk_scale_new_with_range(GTK_ORIENTATION_HORIZONTAL, 0, 100, 1);
#else
      gtk_scale_new_with_range(GTK_ORIENTATION_HORIZONTAL, 0, 100, 1);
#endif
  g_object_set_data(G_OBJECT(s), "nkit-id", GUINT_TO_POINTER(id));
  g_signal_connect(s, "value-changed", G_CALLBACK(slider_value_cb), NULL);
#if !NA_GTK4
  gtk_widget_show(s);
#endif
  g_object_ref_sink(s);
  return (void *)s;
}
void na_slider_free(uint32_t id, void *v) {
  (void)id;
  GtkWidget *w = (GtkWidget *)v;
  if (!w) return;
  GtkWidget *p = gtk_widget_get_parent(w);
  if (p) na_compat_container_remove(p, w);
  g_object_unref(w);
}
void na_slider_set_range(void *v, double mn, double mx) {
  if (v) gtk_range_set_range(GTK_RANGE(v), mn, mx);
}
double na_slider_get_min(void *v) {
  if (!v) return 0;
  GtkAdjustment *adj = gtk_range_get_adjustment(GTK_RANGE(v));
  return adj ? gtk_adjustment_get_lower(adj) : 0;
}
double na_slider_get_max(void *v) {
  if (!v) return 0;
  GtkAdjustment *adj = gtk_range_get_adjustment(GTK_RANGE(v));
  return adj ? gtk_adjustment_get_upper(adj) : 0;
}
void na_slider_set_value(void *v, double val) {
  if (v) gtk_range_set_value(GTK_RANGE(v), val);
}
double na_slider_get_value(void *v) {
  if (!v) return 0;
  return gtk_range_get_value(GTK_RANGE(v));
}

// ================= progress =================
void *na_progress_create(int style) {
  na_linux_ensure_gtk();
  GtkWidget *p = gtk_progress_bar_new();
  bool isSpinner = (style == 1);
  // Store raw value heap-allocated for 0..100 range, and indeterminate flag
  double *valp = (double*)malloc(sizeof(double));
  *valp = 0.0;
  g_object_set_data_full(G_OBJECT(p), "nkit-val", valp, free);
  g_object_set_data(G_OBJECT(p), "nkit-ind", GINT_TO_POINTER(isSpinner ? 1 : 0));
  if (isSpinner) gtk_progress_bar_pulse(GTK_PROGRESS_BAR(p));
#if !NA_GTK4
  gtk_widget_show(p);
#endif
  g_object_ref_sink(p);
  return (void *)p;
}
void na_progress_free(void *v) {
  GtkWidget *w = (GtkWidget *)v;
  if (!w) return;
  GtkWidget *par = gtk_widget_get_parent(w);
  if (par) na_compat_container_remove(par, w);
  g_object_unref(w);
}
void na_progress_set_value(void *v, double val) {
  if (!v) return;
  double *vp = (double*)g_object_get_data(G_OBJECT(v), "nkit-val");
  if (vp) *vp = val;
  // Reflect to GTK fraction 0..1 for visual, but keep raw
  double frac = val / 100.0;
  if (frac < 0) frac = 0;
  if (frac > 1) frac = 1;
  gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(v), frac);
  g_object_set_data(G_OBJECT(v), "nkit-ind", GINT_TO_POINTER(0));
}
double na_progress_get_value(void *v) {
  if (!v) return 0;
  double *vp = (double*)g_object_get_data(G_OBJECT(v), "nkit-val");
  if (vp) return *vp;
  return gtk_progress_bar_get_fraction(GTK_PROGRESS_BAR(v)) * 100.0;
}
void na_progress_set_indeterminate(void *v, bool ind) {
  if (!v) return;
  g_object_set_data(G_OBJECT(v), "nkit-ind", GINT_TO_POINTER(ind ? 1 : 0));
  if (ind) gtk_progress_bar_pulse(GTK_PROGRESS_BAR(v));
}
bool na_progress_is_indeterminate(void *v) {
  if (!v) return false;
  return GPOINTER_TO_INT(g_object_get_data(G_OBJECT(v), "nkit-ind")) != 0;
}

// ================= segmented / select / datepicker / imageview / scroll /
// hover / toast / popover / split / toolbar (functional stubs) =============
//
// These keep full ABI linkability; visual fidelity lands phase-by-phase.
// State needed for Nim-side round-trips is kept in GObject qdata.

typedef void (*na_segmented_event_fn)(uint32_t id, int64_t index, void *ctx);
static na_segmented_event_fn g_seg_fn = NULL;
static void *g_seg_ctx = NULL;
void na_segmented_set_event_callback(na_segmented_event_fn fn, void *ctx) {
  g_seg_fn = fn; g_seg_ctx = ctx;
}
void *na_segmented_create(uint32_t id) {
  na_linux_ensure_gtk();
  GtkWidget *b = na_compat_box_new(0, 4);
  g_object_set_data(G_OBJECT(b), "nkit-id", GUINT_TO_POINTER(id));
  g_object_set_data(G_OBJECT(b), "nkit-sel", GINT_TO_POINTER(-1));
  g_object_ref_sink(b);
  return (void *)b;
}
void na_segmented_free(uint32_t id, void *v) {
  (void)id;
  GtkWidget *w = (GtkWidget *)v;
  if (!w) return;
  GtkWidget *p = gtk_widget_get_parent(w);
  if (p) na_compat_container_remove(p, w);
  g_object_unref(w);
}
void na_segmented_set_labels(void *v, const char **labels, int count) {
  if (!v) return;
  na_view_remove_all(v);
  for (int i = 0; i < count; i++) {
    GtkWidget *b =
        gtk_toggle_button_new_with_label(labels && labels[i] ? labels[i] : "");
    g_object_set_data(G_OBJECT(b), "nkit-idx", GINT_TO_POINTER(i));
    na_compat_box_append((GtkWidget *)v, b);
  }
  // Default selection to first segment if any, matching macOS
  if (count > 0) g_object_set_data(G_OBJECT(v), "nkit-sel", GINT_TO_POINTER(0));
  else g_object_set_data(G_OBJECT(v), "nkit-sel", GINT_TO_POINTER(-1));
}
int na_segmented_count(void *v) {
  if (!v) return 0;
  return na_view_subview_count(v);
}
int64_t na_segmented_selected(void *v) {
  if (!v) return -1;
  return (int64_t)GPOINTER_TO_INT(
      g_object_get_data(G_OBJECT(v), "nkit-sel"));
}
void na_segmented_select(void *v, int64_t idx) {
  if (v) g_object_set_data(G_OBJECT(v), "nkit-sel", GINT_TO_POINTER((int)idx));
}
void na_segmented_fire(uint32_t id, void *v) {
  (void)v;
  if (g_seg_fn) {
    int64_t sel = v ? na_segmented_selected(v) : 0;
    g_seg_fn(id, sel, g_seg_ctx);
  }
}

typedef void (*na_select_event_fn)(uint32_t id, int64_t index, void *ctx);
static na_select_event_fn g_sel_fn = NULL;
static void *g_sel_ctx = NULL;
void na_select_set_event_callback(na_select_event_fn fn, void *ctx) {
  g_sel_fn = fn; g_sel_ctx = ctx;
}
void *na_select_create(uint32_t id) {
  na_linux_ensure_gtk();
  GtkWidget *c = gtk_combo_box_text_new();
  g_object_set_data(G_OBJECT(c), "nkit-id", GUINT_TO_POINTER(id));
#if !NA_GTK4
  gtk_widget_show(c);
#endif
  g_object_ref_sink(c);
  return (void *)c;
}
void na_select_free(uint32_t id, void *v) {
  (void)id;
  GtkWidget *w = (GtkWidget *)v;
  if (!w) return;
  GtkWidget *p = gtk_widget_get_parent(w);
  if (p) na_compat_container_remove(p, w);
  g_object_unref(w);
}
void na_select_add_item(void *v, const char *t) {
  if (v) gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(v), t ? t : "");
}
void na_select_clear(void *v) {
  if (v) gtk_combo_box_text_remove_all(GTK_COMBO_BOX_TEXT(v));
}
int na_select_count(void *v) {
  if (!v) return 0;
#if !NA_GTK4
  GtkTreeModel *m = gtk_combo_box_get_model(GTK_COMBO_BOX(v));
  return m ? gtk_tree_model_iter_n_children(m, NULL) : 0;
#else
  return 0;
#endif
}
int64_t na_select_selected(void *v) {
  if (!v) return -1;
  return (int64_t)gtk_combo_box_get_active(GTK_COMBO_BOX(v));
}
void na_select_choose(void *v, int64_t idx) {
  if (v) gtk_combo_box_set_active(GTK_COMBO_BOX(v), (int)idx);
}
const char *na_select_selected_title(void *v) {
  if (!v) return na_gui_copy_string("");
  char *t = gtk_combo_box_text_get_active_text(GTK_COMBO_BOX_TEXT(v));
  const char *out = na_gui_copy_string(t ? t : "");
  if (t) g_free(t);
  return out;
}

typedef void (*na_datepicker_event_fn)(uint32_t id, double unix_s, void *ctx);
static na_datepicker_event_fn g_dp_fn = NULL;
static void *g_dp_ctx = NULL;
void na_datepicker_set_event_callback(na_datepicker_event_fn fn, void *ctx) {
  g_dp_fn = fn; g_dp_ctx = ctx;
}
void *na_datepicker_create(uint32_t id, int style) {
  na_linux_ensure_gtk();
  (void)style;
  GtkWidget *c = gtk_calendar_new();
  g_object_set_data(G_OBJECT(c), "nkit-id", GUINT_TO_POINTER(id));
  g_object_set_data(G_OBJECT(c), "nkit-unix", NULL);
#if !NA_GTK4
  gtk_widget_show(c);
#endif
  g_object_ref_sink(c);
  return (void *)c;
}
void na_datepicker_free(uint32_t id, void *v) {
  (void)id;
  GtkWidget *w = (GtkWidget *)v;
  if (!w) return;
  GtkWidget *p = gtk_widget_get_parent(w);
  if (p) na_compat_container_remove(p, w);
  g_object_unref(w);
}
void na_datepicker_set_unix_seconds(void *v, double s) {
  if (!v) return;
  double *slot = (double *)g_object_get_data(G_OBJECT(v), "nkit-unix-heap");
  if (!slot) {
    slot = (double *)malloc(sizeof(double));
    g_object_set_data_full(G_OBJECT(v), "nkit-unix-heap", slot, free);
  }
  *slot = s;
}
double na_datepicker_get_unix_seconds(void *v) {
  if (!v) return 0;
  double *slot = (double *)g_object_get_data(G_OBJECT(v), "nkit-unix-heap");
  return slot ? *slot : 0;
}

void *na_image_view_create(void) {
  na_linux_ensure_gtk();
  GtkWidget *w = gtk_image_new();
#if !NA_GTK4
  gtk_widget_show(w);
#endif
  g_object_ref_sink(w);
  return (void *)w;
}
void na_image_view_free(void *v) {
  GtkWidget *w = (GtkWidget *)v;
  if (!w) return;
  GtkWidget *p = gtk_widget_get_parent(w);
  if (p) na_compat_container_remove(p, w);
  g_object_unref(w);
}
void na_image_view_set_image_ptr(void *v, void *img) {
  (void)v; (void)img;
}
void na_image_view_set_symbol(void *v, const char *name, double size,
                               int weight) {
  (void)v; (void)name; (void)size; (void)weight;
}
void na_image_view_clear(void *v) {
  if (v) gtk_image_clear(GTK_IMAGE(v));
}
void na_image_view_set_scaling(void *v, int s) {
  (void)v; (void)s;
}

void *na_scroll_create(void) {
  na_linux_ensure_gtk();
  GtkWidget *s = gtk_scrolled_window_new(NULL, NULL);
#if !NA_GTK4
  gtk_widget_show(s);
#endif
  g_object_ref_sink(s);
  return (void *)s;
}
void na_scroll_free(void *v) {
  GtkWidget *w = (GtkWidget *)v;
  if (!w) return;
  GtkWidget *p = gtk_widget_get_parent(w);
  if (p) na_compat_container_remove(p, w);
  g_object_unref(w);
}
void na_scroll_set_document(void *s, void *doc) {
  if (!s || !doc) return;
#if NA_GTK4
  gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(s), (GtkWidget *)doc);
#else
  gtk_container_add(GTK_CONTAINER(s), (GtkWidget *)doc);
  gtk_widget_show_all((GtkWidget *)doc);
#endif
}
void na_scroll_fit_width(void *s, double l, double r) {
  (void)s; (void)l; (void)r;
}
void na_scroll_set_has_vertical_bar(void *s, bool h) {
  (void)s; (void)h;
}
void na_scroll_set_has_horizontal_bar(void *s, bool h) {
  (void)s; (void)h;
}
void na_scroll_set_border(void *s, bool b) {
  (void)s; (void)b;
}
void na_scroll_set_background(void *s, unsigned char r, unsigned char g,
                               unsigned char b, unsigned char a) {
  (void)s; (void)r; (void)g; (void)b; (void)a;
}

typedef void (*na_hover_event_fn)(uint32_t id, void *ctx);
static na_hover_event_fn g_hov_fn = NULL;
static void *g_hov_ctx = NULL;
void na_hover_set_event_callback(na_hover_event_fn fn, void *ctx) {
  g_hov_fn = fn; g_hov_ctx = ctx;
}
void *na_hover_view_create(uint32_t id) {
  na_linux_ensure_gtk();
  GtkWidget *f = gtk_fixed_new();
  g_object_set_data(G_OBJECT(f), "nkit-id", GUINT_TO_POINTER(id));
  g_object_set_data(G_OBJECT(f), "nkit-sel", GINT_TO_POINTER(0));
  g_object_ref_sink(f);
  return (void *)f;
}
void na_hover_view_free(uint32_t id, void *v) {
  (void)id;
  GtkWidget *w = (GtkWidget *)v;
  if (!w) return;
  GtkWidget *p = gtk_widget_get_parent(w);
  if (p) na_compat_container_remove(p, w);
  g_object_unref(w);
}
void na_hover_view_set_selected(void *v, bool s) {
  if (v) g_object_set_data(G_OBJECT(v), "nkit-sel", GINT_TO_POINTER(s ? 1 : 0));
}
bool na_hover_view_is_selected(void *v) {
  if (!v) return false;
  return GPOINTER_TO_INT(g_object_get_data(G_OBJECT(v), "nkit-sel")) != 0;
}
void na_hover_view_fire(uint32_t id) {
  if (g_hov_fn) g_hov_fn(id, g_hov_ctx);
}

typedef void (*na_toast_dismiss_fn)(uint32_t id, void *ctx);
static na_toast_dismiss_fn g_toast_fn = NULL;
static void *g_toast_ctx = NULL;
static uint32_t g_toast_next = 0;
static int g_toast_active = 0;
void na_toast_set_dismiss_callback(na_toast_dismiss_fn fn, void *ctx) {
  g_toast_fn = fn; g_toast_ctx = ctx;
}
static gboolean toast_auto_dismiss(gpointer data){
  uint32_t id = GPOINTER_TO_UINT(data);
  if (g_toast_active>0) g_toast_active--;
  if (g_toast_fn) g_toast_fn(id, g_toast_ctx);
  return G_SOURCE_REMOVE;
}
uint32_t na_toast_show(const char *title, const char *msg, double dur_ms,
                        double off_y, double width) {
  (void)title; (void)msg; (void)off_y; (void)width;
  g_toast_active++;
  uint32_t id = ++g_toast_next;
  // schedule auto-dismiss after duration
  if (dur_ms > 0) g_timeout_add((guint)dur_ms, toast_auto_dismiss, GUINT_TO_POINTER(id));
  return id;
}
void na_toast_close(uint32_t id) {
  if (g_toast_active>0) g_toast_active--;
  if (g_toast_fn) g_toast_fn(id, g_toast_ctx);
}
int na_toast_active_count(void) { return g_toast_active; }

// popover
typedef void (*na_popover_close_fn)(int64_t handle, void *ctx);
static na_popover_close_fn g_pop_fn = NULL;
static int64_t g_pop_next = 0;
void na_popover_set_close_callback(na_popover_close_fn fn) { (void)fn; }
int64_t na_popover_create(void) {
  na_linux_ensure_gtk();
  return ++g_pop_next;
}
void na_popover_destroy(int64_t h) { (void)h; }
void *na_popover_content_view(int64_t h) {
  (void)h;
  return na_view_create();
}
void na_popover_set_size(int64_t h, double w, double hh) {
  (void)h; (void)w; (void)hh;
}
void na_popover_show(int64_t h, void *anchor, int edge) {
  (void)h; (void)anchor; (void)edge;
}
void na_popover_close(int64_t h) { (void)h; }
bool na_popover_is_shown(int64_t h) {
  (void)h;
  return false;
}

// split view (GtkPaned)
void *na_split_view_create(bool vertical) {
  na_linux_ensure_gtk();
  GtkWidget *p =
#if NA_GTK4
      gtk_paned_new(vertical ? GTK_ORIENTATION_VERTICAL
                            : GTK_ORIENTATION_HORIZONTAL);
#else
      vertical ? gtk_vpaned_new() : gtk_hpaned_new();
#endif
  g_object_ref_sink(p);
  return (void *)p;
}
void na_split_view_add_pane(void *v, void *child) {
  if (!v || !child) return;
#if NA_GTK4
  GtkWidget *first = gtk_paned_get_start_child(GTK_PANED(v));
  if (!first) gtk_paned_set_start_child(GTK_PANED(v), (GtkWidget *)child);
  else if (!gtk_paned_get_end_child(GTK_PANED(v)))
    gtk_paned_set_end_child(GTK_PANED(v), (GtkWidget *)child);
#else
  gtk_paned_add1(GTK_PANED(v), (GtkWidget *)child);
#endif
}
void na_split_view_set_divider_thickness(void *v, double t) {
  (void)v; (void)t;
}
bool na_split_view_set_position(void *v, int idx, double pos) {
  if (!v) return false;
  int n = na_split_view_pane_count(v);
  if (idx <0 || idx >= n) return false;
#if !NA_GTK4
  gtk_paned_set_position(GTK_PANED(v), (int)pos);
#else
  gtk_paned_set_position(GTK_PANED(v), (int)pos);
#endif
  return true;
}
double na_split_view_get_position(void *v, int idx) {
  (void)idx;
  if (!v) return 0;
  return (double)gtk_paned_get_position(GTK_PANED(v));
}
int na_split_view_pane_count(void *v) {
  (void)v;
  return 2;
}
void na_split_view_set_holding_priority(void *v, int idx, double p) {
  (void)v; (void)idx; (void)p;
}
void na_split_view_constrain_pane(void *v, int idx, double min_w, double max_w,
                                   double min_h, double max_h) {
  (void)v; (void)idx; (void)min_w; (void)max_w; (void)min_h; (void)max_h;
}

// toolbar
typedef void (*na_toolbar_click_fn)(unsigned int id, void *ctx);
static na_toolbar_click_fn g_tb_fn = NULL;
static void *g_tb_ctx = NULL;
void na_toolbar_set_click_callback(na_toolbar_click_fn fn) { g_tb_fn = fn; }
// per-toolbar storage
static GHashTable *g_toolbars = NULL; // handle -> GPtrArray of ids
static int64_t g_toolbar_next = 1;
static void ensure_toolbars(void){ if(!g_toolbars) g_toolbars=g_hash_table_new(g_direct_hash,g_direct_equal); }
int64_t na_toolbar_attach(uint32_t win_id) {
  (void)win_id;
  ensure_toolbars();
  int64_t h = g_toolbar_next++;
  g_hash_table_insert(g_toolbars, GSIZE_TO_POINTER((gsize)h), g_ptr_array_new());
  return h;
}
int na_toolbar_add_item(int64_t h, const char *label, const char *sym,
                         unsigned int wid) {
  (void)label; (void)sym;
  ensure_toolbars();
  GPtrArray *a = (GPtrArray*)g_hash_table_lookup(g_toolbars, GSIZE_TO_POINTER((gsize)h));
  if (!a) { a=g_ptr_array_new(); g_hash_table_insert(g_toolbars, GSIZE_TO_POINTER((gsize)h), a); }
  g_ptr_array_add(a, GUINT_TO_POINTER(wid));
  return (int)a->len -1;
}
int na_toolbar_remove_item(int64_t h, unsigned int wid) {
  ensure_toolbars();
  GPtrArray *a = (GPtrArray*)g_hash_table_lookup(g_toolbars, GSIZE_TO_POINTER((gsize)h));
  if (!a) return -1;
  for (guint i=0;i<a->len;i++) if (a->pdata[i]==GUINT_TO_POINTER(wid)) { g_ptr_array_remove_index(a,i); return 0; }
  return -1;
}
int na_toolbar_item_count(int64_t h) {
  ensure_toolbars();
  GPtrArray *a = (GPtrArray*)g_hash_table_lookup(g_toolbars, GSIZE_TO_POINTER((gsize)h));
  return a ? (int)a->len : 0;
}
static void toolbar_fire(unsigned int wid){
  if (g_tb_fn) g_tb_fn(wid, g_tb_ctx);
}
