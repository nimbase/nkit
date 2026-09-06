#include <gtk/gtk.h>
#include <stdint.h>
#include <stdbool.h>

typedef void (*na_theme_changed_fn)(void *ctx);
static na_theme_changed_fn g_fn = NULL;
static void *g_ctx = NULL;

void na_theme_set_changed_callback(na_theme_changed_fn fn, void *ctx) {
  g_fn = fn;
  g_ctx = ctx;
}

static bool gtk_prefers_dark(void) {
  GtkSettings *s = gtk_settings_get_default();
  if (!s) return false;
  gboolean dark = FALSE;
  g_object_get(s, "gtk-application-prefer-dark-theme", &dark, NULL);
  if (dark) return true;
  const char *theme = NULL;
  g_object_get(s, "gtk-theme-name", &theme, NULL);
  if (theme) {
    // Cheap heuristic: *-dark / *Dark* themes.
    for (const char *p = theme; *p; p++) {
      if ((p[0] == 'd' || p[0] == 'D') &&
          (p[1] == 'a' || p[1] == 'A') &&
          (p[2] == 'r' || p[2] == 'R') &&
          (p[3] == 'k' || p[3] == 'K'))
        return true;
    }
  }
  return false;
}

bool na_theme_is_dark(void) { return gtk_prefers_dark(); }

static void out_rgba(unsigned char *r, unsigned char *g, unsigned char *b,
                     unsigned char *a, unsigned char rr, unsigned char gg,
                     unsigned char bb, unsigned char aa) {
  *r = rr; *g = gg; *b = bb; *a = aa;
}

void na_theme_accent_color(unsigned char *r, unsigned char *g,
                            unsigned char *b, unsigned char *a) {
  out_rgba(r, g, b, a, 53, 132, 228, 255);
}
void na_theme_label_color(unsigned char *r, unsigned char *g,
                           unsigned char *b, unsigned char *a) {
  if (gtk_prefers_dark()) out_rgba(r, g, b, a, 255, 255, 255, 255);
  else out_rgba(r, g, b, a, 0, 0, 0, 255);
}
void na_theme_secondary_label_color(unsigned char *r, unsigned char *g,
                                     unsigned char *b, unsigned char *a) {
  out_rgba(r, g, b, a, 128, 128, 128, 255);
}
void na_theme_tertiary_label_color(unsigned char *r, unsigned char *g,
                                    unsigned char *b, unsigned char *a) {
  out_rgba(r, g, b, a, 150, 150, 150, 255);
}
void na_theme_quaternary_label_color(unsigned char *r, unsigned char *g,
                                      unsigned char *b, unsigned char *a) {
  out_rgba(r, g, b, a, 170, 170, 170, 255);
}
void na_theme_placeholder_text_color(unsigned char *r, unsigned char *g,
                                      unsigned char *b, unsigned char *a) {
  out_rgba(r, g, b, a, 150, 150, 150, 255);
}
void na_theme_control_text_color(unsigned char *r, unsigned char *g,
                                  unsigned char *b, unsigned char *a) {
  na_theme_label_color(r, g, b, a);
}
void na_theme_window_background_color(unsigned char *r, unsigned char *g,
                                       unsigned char *b, unsigned char *a) {
  if (gtk_prefers_dark()) out_rgba(r, g, b, a, 36, 36, 36, 255);
  else out_rgba(r, g, b, a, 242, 242, 242, 255);
}
void na_theme_control_background_color(unsigned char *r, unsigned char *g,
                                        unsigned char *b, unsigned char *a) {
  if (gtk_prefers_dark()) out_rgba(r, g, b, a, 48, 48, 48, 255);
  else out_rgba(r, g, b, a, 255, 255, 255, 255);
}
void na_theme_text_background_color(unsigned char *r, unsigned char *g,
                                     unsigned char *b, unsigned char *a) {
  na_theme_control_background_color(r, g, b, a);
}
void na_theme_separator_color(unsigned char *r, unsigned char *g,
                               unsigned char *b, unsigned char *a) {
  out_rgba(r, g, b, a, 200, 200, 200, 255);
}
void na_theme_selected_content_color(unsigned char *r, unsigned char *g,
                                      unsigned char *b, unsigned char *a) {
  out_rgba(r, g, b, a, 53, 132, 228, 255);
}
void na_theme_system_red(unsigned char *r, unsigned char *g,
                          unsigned char *b, unsigned char *a) {
  out_rgba(r, g, b, a, 255, 59, 48, 255);
}
void na_theme_system_green(unsigned char *r, unsigned char *g,
                            unsigned char *b, unsigned char *a) {
  out_rgba(r, g, b, a, 52, 199, 123, 255);
}
void na_theme_system_blue(unsigned char *r, unsigned char *g,
                           unsigned char *b, unsigned char *a) {
  out_rgba(r, g, b, a, 10, 132, 255, 255);
}
void na_theme_system_orange(unsigned char *r, unsigned char *g,
                             unsigned char *b, unsigned char *a) {
  out_rgba(r, g, b, a, 255, 149, 0, 255);
}
void na_theme_system_yellow(unsigned char *r, unsigned char *g,
                             unsigned char *b, unsigned char *a) {
  out_rgba(r, g, b, a, 255, 204, 0, 255);
}
void na_theme_system_purple(unsigned char *r, unsigned char *g,
                             unsigned char *b, unsigned char *a) {
  out_rgba(r, g, b, a, 175, 82, 222, 255);
}
void na_theme_system_pink(unsigned char *r, unsigned char *g,
                           unsigned char *b, unsigned char *a) {
  out_rgba(r, g, b, a, 255, 45, 85, 255);
}
void na_theme_system_teal(unsigned char *r, unsigned char *g,
                           unsigned char *b, unsigned char *a) {
  out_rgba(r, g, b, a, 90, 200, 250, 255);
}
void na_theme_system_indigo(unsigned char *r, unsigned char *g,
                             unsigned char *b, unsigned char *a) {
  out_rgba(r, g, b, a, 88, 86, 214, 255);
}
void na_theme_system_mint(unsigned char *r, unsigned char *g,
                           unsigned char *b, unsigned char *a) {
  out_rgba(r, g, b, a, 102, 212, 207, 255);
}
void na_theme_system_cyan(unsigned char *r, unsigned char *g,
                           unsigned char *b, unsigned char *a) {
  out_rgba(r, g, b, a, 50, 173, 230, 255);
}
void na_theme_system_brown(unsigned char *r, unsigned char *g,
                            unsigned char *b, unsigned char *a) {
  out_rgba(r, g, b, a, 162, 132, 94, 255);
}
void na_theme_system_gray(unsigned char *r, unsigned char *g,
                           unsigned char *b, unsigned char *a) {
  out_rgba(r, g, b, a, 142, 142, 147, 255);
}
