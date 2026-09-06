#pragma once
// Single-source macros over GTK4 / GTK3 API breaks.
// GTK4 preferred; GTK3 fallback compiles on stock Ubuntu without extra deps.
#include <gtk/gtk.h>

#if GTK_CHECK_VERSION(4, 0, 0)
#define NA_GTK4 1
#else
#define NA_GTK4 0
#endif

// --- windows ---------------------------------------------------------------
#if NA_GTK4
static inline GtkWidget *na_compat_window_new(GtkApplication *app) {
  GtkWidget *w = gtk_application_window_new(app);
  return w;
}
static inline void na_compat_window_set_child(GtkWidget *win, GtkWidget *child) {
  gtk_window_set_child(GTK_WINDOW(win), child);
}
static inline GtkWidget *na_compat_window_get_child(GtkWidget *win) {
  return gtk_window_get_child(GTK_WINDOW(win));
}
#else
static inline GtkWidget *na_compat_window_new(GtkApplication *app) {
  GtkWidget *w = gtk_application_window_new(app);
  return w;
}
static inline void na_compat_window_set_child(GtkWidget *win, GtkWidget *child) {
  gtk_container_add(GTK_CONTAINER(win), child);
  gtk_widget_show_all(win);
}
static inline GtkWidget *na_compat_window_get_child(GtkWidget *win) {
  GList *kids = gtk_container_get_children(GTK_CONTAINER(win));
  GtkWidget *first = kids ? (GtkWidget *)kids->data : NULL;
  if (kids) g_list_free(kids);
  return first;
}
#endif

// --- boxes -----------------------------------------------------------------
static inline GtkWidget *na_compat_box_new(int vertical, int spacing) {
#if NA_GTK4
  return gtk_box_new(vertical ? GTK_ORIENTATION_VERTICAL : GTK_ORIENTATION_HORIZONTAL,
                     spacing);
#else
  return gtk_box_new(vertical ? GTK_ORIENTATION_VERTICAL : GTK_ORIENTATION_HORIZONTAL,
                     spacing);
#endif
}

static inline void na_compat_box_append(GtkWidget *box, GtkWidget *child) {
#if NA_GTK4
  gtk_box_append(GTK_BOX(box), child);
#else
  gtk_box_pack_start(GTK_BOX(box), child, FALSE, FALSE, 0);
  gtk_widget_show_all(child);
#endif
}

static inline void na_compat_box_prepend(GtkWidget *box, GtkWidget *child) {
#if NA_GTK4
  gtk_box_prepend(GTK_BOX(box), child);
#else
  gtk_box_pack_start(GTK_BOX(box), child, FALSE, FALSE, 0);
  gtk_box_reorder_child(GTK_BOX(box), child, 0);
  gtk_widget_show_all(child);
#endif
}

static inline void na_compat_box_remove(GtkWidget *box, GtkWidget *child) {
#if NA_GTK4
  // gtk_box_remove exists in 4.x
  gtk_box_remove(GTK_BOX(box), child);
#else
  gtk_container_remove(GTK_CONTAINER(box), child);
#endif
}

// --- generic container add/remove (fixed / generic) -------------------------
static inline void na_compat_container_add(GtkWidget *parent, GtkWidget *child) {
#if NA_GTK4
  if (GTK_IS_BOX(parent)) {
    na_compat_box_append(parent, child);
  } else if (GTK_IS_FIXED(parent)) {
    gtk_fixed_put(GTK_FIXED(parent), child, 0, 0);
  } else {
    // Fallback: boxes hold children; fixed holds absolute children.
    gtk_fixed_put(GTK_FIXED(parent), child, 0, 0);
  }
#else
  if (GTK_IS_CONTAINER(parent)) {
    gtk_container_add(GTK_CONTAINER(parent), child);
    gtk_widget_show_all(child);
  }
#endif
}

static inline void na_compat_container_remove(GtkWidget *parent, GtkWidget *child) {
#if NA_GTK4
  if (GTK_IS_BOX(parent)) {
    gtk_box_remove(GTK_BOX(parent), child);
  } else if (GTK_IS_FIXED(parent)) {
    gtk_fixed_remove(GTK_FIXED(parent), child);
  }
#else
  if (GTK_IS_CONTAINER(parent)) {
    gtk_container_remove(GTK_CONTAINER(parent), child);
  }
#endif
}

// --- visibility --------------------------------------------------------------
static inline void na_compat_show(GtkWidget *w) {
#if NA_GTK4
  gtk_widget_set_visible(w, TRUE);
#else
  gtk_widget_show_all(w);
#endif
}
