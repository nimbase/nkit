#include <gtk/gtk.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include "gui_common.h"
#include "na_compat.h"

void na_view_measure(void *view_ptr, double max_w, double max_h, double *ow, double *oh);

typedef void (*na_drop_event_fn)(unsigned int widget_id, const char **paths,
                                 int count, void *ctx);
typedef void (*na_frame_changed_fn)(double width, double height, void *ctx);

static na_drop_event_fn g_drop_fn = NULL;
static void *g_drop_ctx = NULL;

void na_drop_set_event_callback(na_drop_event_fn fn, void *ctx) {
  g_drop_fn = fn;
  g_drop_ctx = ctx;
}
void na_view_set_drop_enabled(void *view_ptr, bool enabled,
                              unsigned int widget_id) {
  (void)view_ptr; (void)enabled; (void)widget_id;
}

#define ViewState NkitViewState
#define state_of nkit_state_of

/* ── create / destroy ──────────────────────────────────────────────── */

void *na_view_create(void) {
  na_linux_ensure_gtk();
  GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
#if !NA_GTK4
  gtk_widget_show(box);
#else
  gtk_widget_set_visible(box, TRUE);
#endif
  state_of(box);
  g_object_ref_sink(box);
  return (void *)box;
}

void na_view_destroy(void *view_ptr) {
  GtkWidget *w = (GtkWidget *)view_ptr;
  if (!w) return;
  GtkWidget *parent = gtk_widget_get_parent(w);
  if (parent) na_compat_container_remove(parent, w);
  g_object_unref(w);
}

/* ── properties ────────────────────────────────────────────────────── */

void na_view_set_hidden(void *view_ptr, bool hidden) {
  GtkWidget *w = (GtkWidget *)view_ptr;
  if (!w) return;
  state_of(w)->hidden = hidden;
  gtk_widget_set_visible(w, hidden ? FALSE : TRUE);
}
bool na_view_is_hidden(void *view_ptr) {
  GtkWidget *w = (GtkWidget *)view_ptr;
  if (!w) return false;
  return state_of(w)->hidden;
}

void na_view_set_tooltip(void *view_ptr, const char *tip) {
  GtkWidget *w = (GtkWidget *)view_ptr;
  if (!w) return;
  ViewState *st = state_of(w);
  strncpy(st->tooltip, tip ? tip : "", sizeof(st->tooltip) - 1);
  gtk_widget_set_tooltip_text(w, tip ? tip : "");
}
const char *na_view_get_tooltip(void *view_ptr) {
  GtkWidget *w = (GtkWidget *)view_ptr;
  if (!w) return na_gui_copy_string("");
  return na_gui_copy_string(state_of(w)->tooltip);
}

void na_view_set_tag(void *view_ptr, int tag) {
  GtkWidget *w = (GtkWidget *)view_ptr;
  if (w) state_of(w)->tag = tag;
}
int na_view_get_tag(void *view_ptr) {
  GtkWidget *w = (GtkWidget *)view_ptr;
  return w ? state_of(w)->tag : 0;
}

/* ── frame (state-only — no GTK allocation, no feedback loop) ──────── */

void na_view_set_frame(void *view_ptr, double x, double y, double w,
                         double h) {
  GtkWidget *v = (GtkWidget *)view_ptr;
  if (!v) return;
  ViewState *st = state_of(v);
  st->x = x; st->y = y; st->w = w; st->h = h;
}

void na_view_set_frame_no_request(void *view_ptr, double x, double y,
                                    double w, double h) {
  na_view_set_frame(view_ptr, x, y, w, h);
}

void na_view_get_frame(void *view_ptr, double *ox, double *oy, double *ow,
                        double *oh) {
  GtkWidget *v = (GtkWidget *)view_ptr;
  if (!v) { *ox = 0; *oy = 0; *ow = 0; *oh = 0; return; }
  ViewState *st = state_of(v);
  *ox = st->x; *oy = st->y; *ow = st->w; *oh = st->h;
}

/* ── hierarchy ─────────────────────────────────────────────────────── */

static void box_pack_child(GtkWidget *parent, GtkWidget *child, bool expand) {
  ViewState *cst = state_of(child);
  bool do_expand = expand || cst->expanded;
#if NA_GTK4
  gtk_widget_set_hexpand(child, TRUE);
  gtk_widget_set_vexpand(child, do_expand);
  gtk_widget_set_halign(child, GTK_ALIGN_FILL);
  gtk_widget_set_valign(child, do_expand ? GTK_ALIGN_FILL : GTK_ALIGN_START);
  gtk_box_append(GTK_BOX(parent), child);
#else
  gtk_box_pack_start(GTK_BOX(parent), child,
                     do_expand ? TRUE : FALSE,   /* expand */
                     do_expand ? TRUE : FALSE,   /* fill */
                     0);
  if (!do_expand)
    gtk_widget_set_valign(child, GTK_ALIGN_START);
#endif
}

void na_view_add_subview(void *parent_ptr, void *child_ptr) {
  GtkWidget *p = (GtkWidget *)parent_ptr;
  GtkWidget *c = (GtkWidget *)child_ptr;
  if (!p || !c) return;
  GtkWidget *old = gtk_widget_get_parent(c);
  if (old && old != p) na_compat_container_remove(old, c);
  if (gtk_widget_get_parent(c) == p) return;
  if (GTK_IS_BOX(p)) {
    box_pack_child(p, c, false);
  } else {
    na_compat_container_add(p, c);
  }
#if !NA_GTK4
  gtk_widget_show_all(c);
#else
  gtk_widget_set_visible(c, TRUE);
#endif
}

void na_view_remove_from_parent(void *view_ptr) {
  GtkWidget *v = (GtkWidget *)view_ptr;
  if (!v) return;
  GtkWidget *p = gtk_widget_get_parent(v);
  if (p) na_compat_container_remove(p, v);
}

void na_view_remove_all(void *parent_ptr) {
  GtkWidget *p = (GtkWidget *)parent_ptr;
  if (!p) return;
#if NA_GTK4
  GtkWidget *child = gtk_widget_get_first_child(p);
  while (child) {
    GtkWidget *next = gtk_widget_get_next_sibling(child);
    if (GTK_IS_BOX(p)) gtk_box_remove(GTK_BOX(p), child);
    child = next;
  }
#else
  GList *kids = gtk_container_get_children(GTK_CONTAINER(p));
  for (GList *l = kids; l; l = l->next)
    gtk_container_remove(GTK_CONTAINER(p), GTK_WIDGET(l->data));
  if (kids) g_list_free(kids);
#endif
}

int na_view_subview_count(void *parent_ptr) {
  GtkWidget *p = (GtkWidget *)parent_ptr;
  if (!p) return 0;
#if NA_GTK4
  int n = 0;
  for (GtkWidget *c = gtk_widget_get_first_child(p); c;
       c = gtk_widget_get_next_sibling(c))
    n++;
  return n;
#else
  GList *kids = gtk_container_get_children(GTK_CONTAINER(p));
  int n = g_list_length(kids);
  if (kids) g_list_free(kids);
  return n;
#endif
}

void na_view_layout(void *view_ptr) {
  GtkWidget *w = (GtkWidget *)view_ptr;
  if (w) gtk_widget_queue_resize(w);
}

/* ── constraints / sizing ──────────────────────────────────────────── */

void na_view_constrain_fill(void *parent_ptr, void *child_ptr, double l,
                             double t, double r, double b) {
  GtkWidget *c = (GtkWidget *)child_ptr;
  if (!c) return;
  ViewState *st = state_of(c);
  st->x = l; st->y = t;
  GtkWidget *p = (GtkWidget *)parent_ptr;
  if (p && GTK_IS_BOX(p)) {
    bool expand = (b < 0 && l == 0 && r == 0);
    box_pack_child(p, c, expand);
  }
}

void na_view_constrain_fill_superview(void *child_ptr, double l, double t,
                                       double r, double b) {
  GtkWidget *c = (GtkWidget *)child_ptr;
  if (!c) return;
  ViewState *st = state_of(c);
  st->x = l; st->y = t;
  GtkWidget *p = gtk_widget_get_parent(c);
  if (p && GTK_IS_BOX(p)) {
    bool expand = (l == 0 && t == 0 && r == 0 && b == 0);
    box_pack_child(p, c, expand);
  }
}

void na_view_constrain_size(void *view_ptr, double w, double h) {
  GtkWidget *v = (GtkWidget *)view_ptr;
  if (!v) return;
  state_of(v)->w = w;
  state_of(v)->h = h;
}

void na_view_set_content_hugging(void *view_ptr, int orientation,
                                  double priority) {
  (void)view_ptr; (void)orientation; (void)priority;
}

/* ── measure ───────────────────────────────────────────────────────── */

void na_view_measure(void *view_ptr, double max_w, double max_h, double *ow,
                     double *oh) {
  (void)max_w; (void)max_h;
  GtkWidget *v = (GtkWidget *)view_ptr;
  if (!v) { *ow = 0; *oh = 0; return; }
  /* For boxes, return actual GTK allocation — the box computes its own
     size from children via hexpand/vexpand, not from stored frame. */
  if (GTK_IS_BOX(v) && gtk_widget_get_visible(v)) {
    GtkAllocation alloc;
    gtk_widget_get_allocation(v, &alloc);
    if (alloc.width > 0 && alloc.height > 0) {
      *ow = (double)alloc.width;
      *oh = (double)alloc.height;
      return;
    }
  }
  /* For leaves, return stored frame (set by na_view_set_frame) */
  ViewState *st = state_of(v);
  if (st->w > 0 && st->h > 0) {
    *ow = st->w; *oh = st->h;
    return;
  }
  /* Fallback: ask GTK for preferred size */
#if NA_GTK4
  *ow = (double)gtk_widget_get_width(v);
  *oh = (double)gtk_widget_get_height(v);
#else
  GtkRequisition minReq, natReq;
  gtk_widget_get_preferred_size(v, &minReq, &natReq);
  *ow = (double)(natReq.width > minReq.width ? natReq.width : minReq.width);
  *oh = (double)(natReq.height > minReq.height ? natReq.height : minReq.height);
#endif
  if (*ow <= 0) *ow = st->w;
  if (*oh <= 0) *oh = st->h;
}

/* ── styling ───────────────────────────────────────────────────────── */

void na_view_set_wants_layer(void *view_ptr, bool wants) {
  (void)view_ptr; (void)wants;
}

void na_view_set_corner_radius(void *view_ptr, double radius) {
  (void)view_ptr; (void)radius;
}

void na_view_set_background_color(void *view_ptr, unsigned char r,
                                   unsigned char g, unsigned char b,
                                   unsigned char a) {
  GtkWidget *w = (GtkWidget *)view_ptr;
  if (!w) return;
  ViewState *st = state_of(w);
  st->bg[0] = r; st->bg[1] = g; st->bg[2] = b; st->bg[3] = a;
  st->has_bg = true;
}

void na_view_clear_background_color(void *view_ptr) {
  GtkWidget *w = (GtkWidget *)view_ptr;
  if (w) state_of(w)->has_bg = false;
}

void na_view_set_border(void *view_ptr, unsigned char r, unsigned char g,
                         unsigned char b, unsigned char a, double width) {
  (void)view_ptr; (void)r; (void)g; (void)b; (void)a; (void)width;
}

void na_view_set_alpha(void *view_ptr, double alpha) {
  GtkWidget *w = (GtkWidget *)view_ptr;
  if (!w) return;
  state_of(w)->alpha = alpha;
  gtk_widget_set_opacity(w, alpha);
}
double na_view_get_alpha(void *view_ptr) {
  GtkWidget *w = (GtkWidget *)view_ptr;
  return w ? state_of(w)->alpha : 1.0;
}

void na_view_set_frame_callback(void *view_ptr, na_frame_changed_fn fn,
                                 void *ctx) {
  (void)view_ptr; (void)fn; (void)ctx;
}

/* ── box helpers (called from Nim layout) ──────────────────────────── */

void na_view_set_orientation(void *view_ptr, int orientation) {
  GtkWidget *v = (GtkWidget *)view_ptr;
  if (!v || !GTK_IS_ORIENTABLE(v)) return;
  GtkOrientation o = (orientation == 1) ? GTK_ORIENTATION_HORIZONTAL
                                        : GTK_ORIENTATION_VERTICAL;
  gtk_orientable_set_orientation(GTK_ORIENTABLE(v), o);
}

void na_view_set_expanded(void *view_ptr, bool expanded) {
  GtkWidget *v = (GtkWidget *)view_ptr;
  if (!v) return;
  state_of(v)->expanded = expanded;
}

void na_view_set_spacing(void *view_ptr, double spacing) {
  GtkWidget *v = (GtkWidget *)view_ptr;
  if (!v || !GTK_IS_BOX(v)) return;
  gtk_box_set_spacing(GTK_BOX(v), (int)spacing);
}

void na_view_set_margin(void *view_ptr, double l, double t, double r, double b) {
  GtkWidget *v = (GtkWidget *)view_ptr;
  if (!v) return;
  gtk_widget_set_margin_start(v, (int)l);
  gtk_widget_set_margin_top(v, (int)t);
  gtk_widget_set_margin_end(v, (int)r);
  gtk_widget_set_margin_bottom(v, (int)b);
}

void na_view_set_expand_fill(void *view_ptr, bool expand, bool fill) {
  GtkWidget *v = (GtkWidget *)view_ptr;
  if (!v) return;
  gtk_widget_set_hexpand(v, expand);
  gtk_widget_set_vexpand(v, expand);
  gtk_widget_set_halign(v, fill ? GTK_ALIGN_FILL : GTK_ALIGN_START);
  gtk_widget_set_valign(v, fill ? GTK_ALIGN_FILL : GTK_ALIGN_START);
#if !NA_GTK4
  /* For GTK3, update the box child packing to reflect new expand flag */
  GtkWidget *parent = gtk_widget_get_parent(v);
  if (parent && GTK_IS_BOX(parent)) {
    GtkPackType pack_type = GTK_PACK_START;
    gboolean cur_expand = FALSE, cur_fill = FALSE, cur_padding = FALSE;
    gtk_box_query_child_packing(GTK_BOX(parent), v, &cur_expand, &cur_fill, &cur_padding, &pack_type);
    gtk_box_set_child_packing(GTK_BOX(parent), v,
                              expand ? TRUE : cur_expand,
                              fill ? TRUE : cur_fill,
                              cur_padding, pack_type);
  }
#endif
}

void na_view_set_cross_align(void *view_ptr, bool vertical, int align) {
  /* align: 0=fill, 1=center, 2=start, 3=end */
  GtkWidget *v = (GtkWidget *)view_ptr;
  if (!v) return;
  GtkAlign a;
  switch (align) {
    case 1: a = GTK_ALIGN_CENTER; break;
    case 2: a = vertical ? GTK_ALIGN_START : GTK_ALIGN_START; break;
    case 3: a = vertical ? GTK_ALIGN_END : GTK_ALIGN_END; break;
    default: a = GTK_ALIGN_FILL; break;
  }
  if (vertical)
    gtk_widget_set_valign(v, a);
  else
    gtk_widget_set_halign(v, a);
}
