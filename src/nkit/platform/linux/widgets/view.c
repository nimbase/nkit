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
  // Drag-drop portal wiring lands in phase 4; stored no-op for now.
}

#define ViewState NkitViewState
#define state_of nkit_state_of

void *na_view_create(void) {
  na_linux_ensure_gtk();
  GtkWidget *f = gtk_fixed_new();
#if !NA_GTK4
  gtk_widget_show(f);
#else
  gtk_widget_set_visible(f, TRUE);
#endif
  state_of(f);
  // Extra ref so Nim-side GC timing never frees the widget early.
  g_object_ref_sink(f);
  return (void *)f;
}

void na_view_destroy(void *view_ptr) {
  GtkWidget *w = (GtkWidget *)view_ptr;
  if (!w) return;
  GtkWidget *parent =
#if NA_GTK4
      gtk_widget_get_parent(w);
#else
      gtk_widget_get_parent(w);
#endif
  if (parent) na_compat_container_remove(parent, w);
  g_object_unref(w);
}

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

void na_view_set_frame(void *view_ptr, double x, double y, double w,
                        double h) {
  GtkWidget *v = (GtkWidget *)view_ptr;
  if (!v) return;
  ViewState *st = state_of(v);
  st->x = x; st->y = y; st->w = w; st->h = h;
  gtk_widget_set_size_request(v, (int)w, (int)h);
  GtkWidget *parent = gtk_widget_get_parent(v);
  if (parent && GTK_IS_FIXED(parent)) {
    ViewState *pst = state_of(parent);
    double ph = pst ? pst->h : 0;
    double y_top = y;
    if (ph > 0) y_top = ph - y - h;
    gtk_fixed_move(GTK_FIXED(parent), v, (int)x, (int)y_top);
  }
}
void na_view_get_frame(void *view_ptr, double *ox, double *oy, double *ow,
                        double *oh) {
  GtkWidget *v = (GtkWidget *)view_ptr;
  if (!v) { *ox = 0; *oy = 0; *ow = 0; *oh = 0; return; }
  ViewState *st = state_of(v);
  // If parent is a vertical/horizontal GtkBox, compute position on demand
  // from sibling measures + box spacing, because GtkBox allocation is not
  // realized offscreen in unit tests.
  GtkWidget *parent = gtk_widget_get_parent(v);
  if (parent && GTK_IS_BOX(parent) && (st->w == 0 || st->h == 0 || st->y == 0)) {
    // Fallback box layout calculation
    GtkOrientation orient = gtk_orientable_get_orientation(GTK_ORIENTABLE(parent));
    int spacing = gtk_box_get_spacing(GTK_BOX(parent));
#if NA_GTK4
    double cur = 0;
    for (GtkWidget *c = gtk_widget_get_first_child(parent); c; c = gtk_widget_get_next_sibling(c)) {
      if (c == v) {
        double cw = 0, ch = 0;
        na_view_measure((void*)c, 0, 0, &cw, &ch);
        if (st->w > 0) cw = st->w;
        if (st->h > 0) ch = st->h;
        if (orient == GTK_ORIENTATION_VERTICAL && parent) {
          ViewState *pst = state_of(parent);
          double pw = pst ? pst->w : 0;
          if (pw == 0 && gtk_widget_get_visible(parent)) {
            GtkAllocation alloc;
            gtk_widget_get_allocation(parent, &alloc);
            if (alloc.width > 0) pw = alloc.width;
          }
          if (pw > 0) {
            double left = gtk_widget_get_margin_start(parent);
            double right = gtk_widget_get_margin_end(parent);
            cw = pw - left - right;
            if (cw < 0) cw = pw;
          }
        }
        *ox = (orient == GTK_ORIENTATION_VERTICAL) ? 0 : cur;
        *oy = (orient == GTK_ORIENTATION_VERTICAL) ? cur : 0;
        *ow = cw > 0 ? cw : st->w;
        *oh = ch > 0 ? ch : st->h;
        if (*ow == 0 || *oh == 0) {
          double mw = 0, mh = 0;
          na_view_measure(v, 0, 0, &mw, &mh);
          if (*ow == 0) *ow = mw;
          if (*oh == 0) *oh = mh;
        }
        return;
      }
      double tcw = 0, tch = 0;
      na_view_measure((void*)c, 0, 0, &tcw, &tch);
      if (orient == GTK_ORIENTATION_VERTICAL) cur += tch + spacing;
      else cur += tcw + spacing;
    }
#else
    GList *kids = gtk_container_get_children(GTK_CONTAINER(parent));
    double cur = 0;
    int idx = 0, targetIdx = -1;
    for (GList *l = kids; l; l = l->next) {
      if ((GtkWidget*)l->data == v) targetIdx = idx;
      idx++;
    }
    idx = 0;
    for (GList *l = kids; l; l = l->next) {
      GtkWidget *c = (GtkWidget*)l->data;
      if (idx == targetIdx) {
        double cw = 0, ch = 0;
        na_view_measure((void*)c, 0, 0, &cw, &ch);
        if (st->w > 0) cw = st->w;
        if (st->h > 0) ch = st->h;
        if (orient == GTK_ORIENTATION_VERTICAL && parent) {
          ViewState *pst = state_of(parent);
          double pw = pst ? pst->w : 0;
          if (pw > 0) {
            int ml = gtk_widget_get_margin_start(parent);
            int mr = gtk_widget_get_margin_end(parent);
            cw = pw - ml - mr;
          }
        }
        *ox = (orient == GTK_ORIENTATION_VERTICAL) ? 0 : cur;
        *oy = (orient == GTK_ORIENTATION_VERTICAL) ? cur : 0;
        *ow = cw; *oh = ch;
        if (*ow == 0 || *oh == 0) {
          double mw = 0, mh = 0;
          na_view_measure(v, 0, 0, &mw, &mh);
          if (*ow == 0) *ow = mw;
          if (*oh == 0) *oh = mh;
        }
        if (kids) g_list_free(kids);
        return;
      }
      double tcw = 0, tch = 0;
      na_view_measure((void*)c, 0, 0, &tcw, &tch);
      if (orient == GTK_ORIENTATION_VERTICAL) cur += tch + spacing;
      else cur += tcw + spacing;
      idx++;
    }
    if (kids) g_list_free(kids);
#endif
  }
  // Fixed fallback: use measure for missing dimension
  if ((st->w == 0 || st->h == 0) && v) {
    double mw = 0, mh = 0;
    na_view_measure(v, 0, 0, &mw, &mh);
    *ox = st->x; *oy = st->y;
    *ow = st->w > 0 ? st->w : mw;
    *oh = st->h > 0 ? st->h : mh;
    return;
  }
  *ox = st->x; *oy = st->y; *ow = st->w; *oh = st->h;
}

void na_view_add_subview(void *parent_ptr, void *child_ptr) {
  GtkWidget *p = (GtkWidget *)parent_ptr;
  GtkWidget *c = (GtkWidget *)child_ptr;
  if (!p || !c) return;
  // Avoid double-parent warnings.
  GtkWidget *old = gtk_widget_get_parent(c);
  if (old && old != p) na_compat_container_remove(old, c);
  if (gtk_widget_get_parent(c) == p) return;
  if (GTK_IS_FIXED(p)) {
    ViewState *st = state_of(c);
    gtk_fixed_put(GTK_FIXED(p), c, (int)st->x, (int)st->y);
    if (st->w > 0 && st->h > 0)
      gtk_widget_set_size_request(c, (int)st->w, (int)st->h);
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
    else if (GTK_IS_FIXED(p)) gtk_fixed_remove(GTK_FIXED(p), child);
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

void na_view_constrain_fill(void *parent_ptr, void *child_ptr, double l,
                             double t, double r, double b) {
  GtkWidget *p = (GtkWidget *)parent_ptr;
  GtkWidget *c = (GtkWidget *)child_ptr;
  if (!p || !c) return;
  ViewState *st = state_of(c);
  ViewState *pst = state_of(p);
  // Use bottom origin for y to match macOS/AppKit (non-iOS) coordinate system
  st->x = l; st->y = b;
  double pw = pst ? pst->w : 0;
  double ph = pst ? pst->h : 0;
  if (pw > 0) {
    st->w = pw - l - r;
    if (st->w < 0) st->w = 0;
    gtk_widget_set_size_request(c, (int)st->w, (int)(st->h > 0 ? st->h : -1));
  }
  if (ph > 0) {
    st->h = ph - t - b;
    if (st->h < 0) st->h = 0;
    gtk_widget_set_size_request(c, (int)(st->w > 0 ? st->w : -1), (int)st->h);
  }
  if (GTK_IS_FIXED(p)) {
    // For fixed, y is bottom inset; translate to top for gtk_fixed_move (top-left)
    double y_top = ph > 0 ? (ph - b - st->h) : t;
    if (ph == 0) y_top = t;
    gtk_fixed_move(GTK_FIXED(p), c, (int)l, (int)y_top);
    if (st->w > 0 || st->h > 0) gtk_widget_queue_resize(c);
  }
}

void na_view_constrain_fill_superview(void *child_ptr, double l, double t,
                                       double r, double b) {
  GtkWidget *c = (GtkWidget *)child_ptr;
  if (!c) return;
  ViewState *st = state_of(c);
  // Bottom origin y = b
  st->x = l; st->y = b;
  GtkWidget *p = gtk_widget_get_parent(c);
  if (p) {
    ViewState *pst = state_of(p);
    double pw = pst ? pst->w : 0;
    double ph = pst ? pst->h : 0;
    if (pw > 0) {
      st->w = pw - l - r;
      if (st->w < 0) st->w = 0;
    }
    if (ph > 0) {
      st->h = ph - t - b;
      if (st->h < 0) st->h = 0;
    }
    if (st->w > 0 || st->h > 0) gtk_widget_set_size_request(c, (int)(st->w >0?st->w:-1), (int)(st->h>0?st->h:-1));
    if (p && GTK_IS_FIXED(p)) {
      double y_top = ph > 0 ? (ph - b - st->h) : t;
      if (ph == 0) y_top = t;
      gtk_fixed_move(GTK_FIXED(p), c, (int)l, (int)y_top);
    }
  }
}

void na_view_constrain_size(void *view_ptr, double w, double h) {
  GtkWidget *v = (GtkWidget *)view_ptr;
  if (!v) return;
  state_of(v)->w = w;
  state_of(v)->h = h;
  gtk_widget_set_size_request(v, (int)w, (int)h);
}

void na_view_set_content_hugging(void *view_ptr, int orientation,
                                  double priority) {
  (void)view_ptr; (void)orientation; (void)priority;
}

void na_view_measure(void *view_ptr, double max_w, double max_h, double *ow,
                     double *oh) {
  (void)max_w; (void)max_h;
  GtkWidget *v = (GtkWidget *)view_ptr;
  if (!v) { *ow = 0; *oh = 0; return; }
  ViewState *st = state_of(v);
  if (st->w > 0 && st->h > 0) {
    *ow = st->w; *oh = st->h;
    return;
  }
#if NA_GTK4
  *ow = (double)gtk_widget_get_width(v);
  *oh = (double)gtk_widget_get_height(v);
#else
  GtkRequisition minReq, natReq;
  gtk_widget_get_preferred_size(v, &minReq, &natReq);
  double w = natReq.width > minReq.width ? natReq.width : minReq.width;
  double h = natReq.height > minReq.height ? natReq.height : minReq.height;
  // Also respect size_request via ViewState if larger
  if (st->w > w) w = st->w;
  if (st->h > h) h = st->h;
  *ow = w;
  *oh = h;
#endif
  if (*ow <= 0) *ow = st->w;
  if (*oh <= 0) *oh = st->h;
}

void na_view_set_wants_layer(void *view_ptr, bool wants) {
  (void)view_ptr; (void)wants; // Always layer-backed conceptually.
}

void na_view_set_corner_radius(void *view_ptr, double radius) {
  (void)view_ptr; (void)radius; // CSS polish in phase 6.
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
  (void)view_ptr; (void)fn; (void)ctx; // Resize-listener wiring in phase 3.
}
