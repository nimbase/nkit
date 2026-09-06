#pragma once
// Shared helpers for the nkit Linux (GTK) backend.
// Mirrors macos/widgets/gui_common.h intent: registries, string buffers,
// callback plumbing. GTK works on both X11 and Wayland; coordinates here
// are always top-left origin like iOS (no AppKit bottom-left flip).
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <gtk/gtk.h>

// Thread-local scratch buffers for small string getters (title, label...).
// Callers must copy immediately; matches macos g_gui_text_buffer pattern.
extern __thread char g_gui_text_buffer[8192];

// Copy helper: returns pointer to thread-local buffer.
static inline const char *na_gui_copy_string(const char *s) {
  g_gui_text_buffer[0] = '\0';
  if (s) {
    strncpy(g_gui_text_buffer, s, sizeof(g_gui_text_buffer) - 1);
    g_gui_text_buffer[sizeof(g_gui_text_buffer) - 1] = '\0';
  }
  return g_gui_text_buffer;
}

// strdup helper for owned strings (clipboard etc). Caller frees with
// na_clipboard_free_string / free.
static inline char *na_gui_dup_string(const char *s) {
  if (!s) {
    char *e = (char *)malloc(1);
    if (e) e[0] = '\0';
    return e;
  }
  size_t n = strlen(s) + 1;
  char *d = (char *)malloc(n);
  if (d) memcpy(d, s, n);
  return d;
}

// Idempotent GTK init for unit tests, which create widgets without ever
// calling na_app_init / entering the main loop. Safe to call anywhere.
static inline void na_linux_ensure_gtk(void) {
  static int done = 0;
  if (!done) {
    done = 1;
    gtk_init_check(NULL, NULL);
  }
}

// Shared ViewState layout storage for fixed-position container (GtkFixed)
// and generic widgets. Used by view.c and controls.c separator/thickness.
typedef struct {
  double x, y, w, h;
  bool hidden;
  int tag;
  char tooltip[512];
  unsigned char bg[4];
  bool has_bg;
  double alpha;
} NkitViewState;

static inline NkitViewState *nkit_state_of(GtkWidget *w) {
  if (!w) return NULL;
  NkitViewState *st = (NkitViewState *)g_object_get_data(G_OBJECT(w), "nkit-view-state");
  if (!st) {
    st = (NkitViewState *)calloc(1, sizeof(NkitViewState));
    st->alpha = 1.0;
    g_object_set_data_full(G_OBJECT(w), "nkit-view-state", st, free);
  }
  return st;
}
