#include <gtk/gtk.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include "gui_common.h"

typedef void (*na_screens_changed_fn)(void *ctx);
static na_screens_changed_fn g_fn = NULL;
static void *g_ctx = NULL;

static GdkDisplay *default_display(void) {
  return gdk_display_get_default();
}

int na_screen_count(void) {
  GdkDisplay *d = default_display();
  if (!d) return 1;
#if GTK_CHECK_VERSION(4, 0, 0)
  GListModel *mons = gdk_display_get_monitors(d);
  return mons ? (int)g_list_model_get_n_items(mons) : 1;
#else
  return gdk_display_get_n_monitors(d);
#endif
}

uint32_t na_screen_display_id(int index) {
  // Stable 1-based ids like macOS display ids.
  return (uint32_t)(index + 1);
}

static GdkMonitor *monitor_for(uint32_t display_id) {
  GdkDisplay *d = default_display();
  if (!d) return NULL;
  int idx = (int)display_id - 1;
  if (idx < 0) idx = 0;
#if GTK_CHECK_VERSION(4, 0, 0)
  GListModel *mons = gdk_display_get_monitors(d);
  if (!mons || idx >= (int)g_list_model_get_n_items(mons)) return NULL;
  return GDK_MONITOR(g_list_model_get_item(mons, (guint)idx));
#else
  if (idx >= gdk_display_get_n_monitors(d)) return NULL;
  return gdk_display_get_monitor(d, idx);
#endif
}

bool na_screen_is_primary(uint32_t display_id) {
  (void)display_id;
  return display_id <= 1; // First monitor is primary.
}

const char *na_screen_get_name(uint32_t display_id) {
  GdkMonitor *m = monitor_for(display_id);
  if (!m) return na_gui_copy_string("Display");
#if !GTK_CHECK_VERSION(4, 0, 0)
  const char *model = gdk_monitor_get_model(m);
  if (model && model[0]) return na_gui_copy_string(model);
#endif
  char buf[64];
  snprintf(buf, sizeof(buf), "Display %u", display_id);
  return na_gui_copy_string(buf);
}

void na_screen_get_frame(uint32_t id, double *x, double *y, double *w,
                          double *h) {
  GdkMonitor *m = monitor_for(id);
  if (!m) { *x = 0; *y = 0; *w = 1920; *h = 1080; return; }
  GdkRectangle r;
  gdk_monitor_get_geometry(m, &r);
  *x = r.x; *y = r.y; *w = r.width; *h = r.height;
}

void na_screen_get_work_area(uint32_t id, double *x, double *y, double *w,
                              double *h) {
  GdkMonitor *m = monitor_for(id);
  if (!m) { *x = 0; *y = 0; *w = 1920; *h = 1040; return; }
  GdkRectangle r;
  gdk_monitor_get_workarea(m, &r);
  *x = r.x; *y = r.y; *w = r.width; *h = r.height;
}

double na_screen_get_scale_factor(uint32_t id) {
  GdkMonitor *m = monitor_for(id);
  if (!m) return 1.0;
  return (double)gdk_monitor_get_scale_factor(m);
}

int na_screen_get_refresh_rate(uint32_t id) {
  GdkMonitor *m = monitor_for(id);
  if (!m) return 60;
  int milli = gdk_monitor_get_refresh_rate(m);
  return milli > 0 ? milli / 1000 : 60;
}

void na_screen_get_cursor_position(double *x, double *y) {
  GdkDisplay *d = default_display();
  if (!d) { *x = 0; *y = 0; return; }
#if GTK_CHECK_VERSION(4, 0, 0)
  // GTK4 removed global pointer query; report origin (portal-safe).
  (void)d;
  *x = 0; *y = 0;
#else
  GdkSeat *seat = gdk_display_get_default_seat(d);
  GdkDevice *ptr = seat ? gdk_seat_get_pointer(seat) : NULL;
  if (!ptr) { *x = 0; *y = 0; return; }
  GdkScreen *scr = NULL;
  int ix = 0, iy = 0;
  gdk_device_get_position(ptr, &scr, &ix, &iy);
  *x = ix; *y = iy;
#endif
}

void na_screen_set_changed_callback(na_screens_changed_fn fn, void *ctx) {
  g_fn = fn;
  g_ctx = ctx;
  (void)g_fn; (void)g_ctx;
  // Monitor-added signals wired in phase 4; setter retained for ABI.
}
