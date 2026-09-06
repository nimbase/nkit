#include <gtk/gtk.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>

typedef void (*na_app_fn)(void *ctx);
typedef void (*na_app_exit_fn)(int exit_code, void *ctx);
typedef void (*na_task_fn)(void *ctx);

static GtkApplication *g_app = NULL;
static GThread *g_main_thread = NULL;

static struct {
  void *ctx;
  na_app_fn on_started;
  na_app_fn on_activated;
  na_app_fn on_deactivated;
  na_app_fn on_quit_requested;
  na_app_exit_fn on_exiting;
  bool activate_fired;
} g_cb = {0};

static uint32_t g_dock_menu_id = 0;

static void fire_started(void) {
  if (g_cb.on_started) g_cb.on_started(g_cb.ctx);
}
static void fire_activated(void) {
  if (g_cb.on_activated) g_cb.on_activated(g_cb.ctx);
}

static void on_app_activate(GApplication *app, gpointer user_data) {
  (void)app;
  (void)user_data;
  if (!g_cb.activate_fired) {
    g_cb.activate_fired = true;
    fire_started();
  }
  fire_activated();
}

static void on_app_shutdown(GApplication *app, gpointer user_data) {
  (void)app;
  (void)user_data;
  if (g_cb.on_exiting) g_cb.on_exiting(0, g_cb.ctx);
}

static void ensure_app(void) {
  if (g_app) return;
  // Establishes the GDK display connection so widgets can be created
  // before g_application_run (unit tests never enter the main loop).
  gtk_init_check(NULL, NULL);
  g_app = gtk_application_new("org.nimbase.nkit", G_APPLICATION_NON_UNIQUE);
  g_signal_connect(g_app, "activate", G_CALLBACK(on_app_activate), NULL);
  g_signal_connect(g_app, "shutdown", G_CALLBACK(on_app_shutdown), NULL);
}

GtkApplication *na_linux_gtk_app(void) {
  ensure_app();
  return g_app;
}

bool na_app_init(void) {
  ensure_app();
  if (!g_main_thread) g_main_thread = g_thread_self();
  // Register non-blocking so GdkDisplay exists for screens/windows.
  GError *err = NULL;
  g_application_register(G_APPLICATION(g_app), NULL, &err);
  if (err) g_error_free(err);
  return true;
}

int na_app_run(void) {
  ensure_app();
  if (!g_main_thread) g_main_thread = g_thread_self();
  // g_application_run blocks until quit; activate fires on first window.
  int status = g_application_run(G_APPLICATION(g_app), 0, NULL);
  return status;
}

void na_app_quit(void) {
  if (g_cb.on_quit_requested) g_cb.on_quit_requested(g_cb.ctx);
  if (g_app) g_application_quit(G_APPLICATION(g_app));
}

void na_app_stop(void) {
  if (g_app) g_application_quit(G_APPLICATION(g_app));
}

void na_app_set_dock_menu(uint32_t menu_id) { g_dock_menu_id = menu_id; }
uint32_t na_app_dock_menu(void) { return g_dock_menu_id; }

bool na_app_set_icon(const char *utf8_path) {
  (void)utf8_path;
  // Window icons are set per-window via gtk_window_set_icon_name; app-level
  // icon comes from the .desktop file on Linux. Report false (not applied).
  return false;
}

bool na_app_set_dock_icon_visible(bool visible) {
  (void)visible;
  return true; // No dock on Linux; treat toggle as successful no-op.
}

void na_app_set_callbacks(void *ctx, na_app_fn on_started,
                           na_app_fn on_activated, na_app_fn on_deactivated,
                           na_app_fn on_quit_requested,
                           na_app_exit_fn on_exiting) {
  g_cb.ctx = ctx;
  g_cb.on_started = on_started;
  g_cb.on_activated = on_activated;
  g_cb.on_deactivated = on_deactivated;
  g_cb.on_quit_requested = on_quit_requested;
  g_cb.on_exiting = on_exiting;
}

// --- dispatcher (GMainContext) ---------------------------------------------

bool na_is_main_thread(void) {
  if (!g_main_thread) return true;
  return g_thread_self() == g_main_thread;
}

typedef struct {
  na_task_fn fn;
  void *ctx;
} NaTask;

static gboolean task_trampoline(gpointer data) {
  NaTask *t = (NaTask *)data;
  if (t->fn) t->fn(t->ctx);
  free(t);
  return G_SOURCE_REMOVE;
}

void na_dispatch_main(na_task_fn fn, void *ctx) {
  if (!fn) return;
  NaTask *t = (NaTask *)malloc(sizeof(NaTask));
  t->fn = fn;
  t->ctx = ctx;
  g_idle_add(task_trampoline, t);
}

void na_dispatch_main_after(int delay_ms, na_task_fn fn, void *ctx) {
  if (!fn) return;
  NaTask *t = (NaTask *)malloc(sizeof(NaTask));
  t->fn = fn;
  t->ctx = ctx;
  g_timeout_add(delay_ms < 0 ? 0 : (guint)delay_ms, task_trampoline, t);
}

bool na_run_main_loop_for(int timeout_ms) {
  if (timeout_ms < 0) timeout_ms = 0;
  gint64 deadline = g_get_monotonic_time() + (gint64)timeout_ms * 1000;
  while (g_get_monotonic_time() < deadline) {
    while (g_main_context_pending(NULL)) {
      g_main_context_iteration(NULL, FALSE);
    }
    gint64 remaining = deadline - g_get_monotonic_time();
    if (remaining <= 0) break;
    // Small sleep lets g_timeout_add sources become ready without
    // blocking indefinitely on a context with no file descriptors.
    g_usleep((guint64)(remaining < 5000 ? (guint64)remaining : 5000));
  }
  while (g_main_context_pending(NULL)) {
    g_main_context_iteration(NULL, FALSE);
  }
  return true;
}
