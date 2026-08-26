#import <UIKit/UIKit.h>
#import <stdio.h>

typedef void (*na_app_fn)(void* ctx);
typedef void (*na_app_exit_fn)(int exit_code, void* ctx);

static struct {
  void* ctx;
  na_app_fn on_started;
  na_app_fn on_activated;
  na_app_fn on_deactivated;
  na_app_fn on_quit_requested;
  na_app_exit_fn on_exiting;
} g_ios_app_callbacks = {NULL, NULL, NULL, NULL, NULL, NULL};

extern void na_ios_create_window_for_id(uint32_t id, UIWindowScene* scene);
extern NSMutableArray* g_pending_ids;

static void log_msg(const char* msg) {
  FILE* f = fopen("/tmp/nkit_launch.log", "a");
  if (f) { fprintf(f, "%s\n", msg); fclose(f); }
}

@interface NAAppDelegate : NSObject <UIApplicationDelegate>
@end

@implementation NAAppDelegate

- (BOOL)application:(UIApplication*)application
    didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
  char buf[512];
  snprintf(buf, sizeof(buf), "didFinishLaunching: scenes=%lu pending=%lu",
           (unsigned long)application.connectedScenes.count,
           (unsigned long)g_pending_ids.count);
  log_msg(buf);

  UIWindowScene* scene = nil;
  for (UIScene* s in application.connectedScenes) {
    if ([s isKindOfClass:[UIWindowScene class]] &&
        s.activationState == UISceneActivationStateForegroundActive) {
      scene = (UIWindowScene*)s;
    }
  }
  if (!scene && application.connectedScenes.count > 0) {
    scene = (UIWindowScene*)application.connectedScenes.anyObject;
  }
  snprintf(buf, sizeof(buf), "  scene=%p", scene);
  log_msg(buf);

  if (scene && g_pending_ids.count > 0) {
    for (NSNumber* nid in [g_pending_ids copy]) {
      snprintf(buf, sizeof(buf), "  creating window id=%u", nid.unsignedIntValue);
      log_msg(buf);
      na_ios_create_window_for_id(nid.unsignedIntValue, scene);
    }
    [g_pending_ids removeAllObjects];
  }

  UIWindow* keyWin = nil;
  for (UIWindow* w in [UIApplication.sharedApplication windows]) {
    if (w.windowScene == scene && !keyWin) {
      keyWin = w;
    }
  }
  if (keyWin) {
    [keyWin makeKeyAndVisible];
    snprintf(buf, sizeof(buf), "  made key: %p", keyWin);
    log_msg(buf);
  } else {
    log_msg("  NO key window");
  }

  if (g_ios_app_callbacks.on_started) {
    g_ios_app_callbacks.on_started(g_ios_app_callbacks.ctx);
  }
  return YES;
}

- (void)applicationDidBecomeActive:(UIApplication*)application {
  if (g_ios_app_callbacks.on_activated) {
    g_ios_app_callbacks.on_activated(g_ios_app_callbacks.ctx);
  }
}

- (void)applicationWillResignActive:(UIApplication*)application {
  if (g_ios_app_callbacks.on_deactivated) {
    g_ios_app_callbacks.on_deactivated(g_ios_app_callbacks.ctx);
  }
}

- (void)applicationWillTerminate:(UIApplication*)application {
  if (g_ios_app_callbacks.on_exiting) {
    g_ios_app_callbacks.on_exiting(0, g_ios_app_callbacks.ctx);
  }
}

@end

BOOL na_app_init(void) {
  // Truncate previous log
  FILE* f = fopen("/tmp/nkit_launch.log", "w");
  if (f) fclose(f);
  log_msg("na_app_init");
  return YES;
}

int na_app_run(void) {
  log_msg("na_app_run");
  @autoreleasepool {
    int argc = 0;
    char* argv0[1] = {NULL};
    char** argv = argv0;
    NSString* delegateClassName = NSStringFromClass([NAAppDelegate class]);
    UIApplicationMain(argc, argv, nil, delegateClassName);
  }
  log_msg("na_app_run returned");
  return 0;
}

void na_app_quit(void) { }
void na_app_stop(void) { }

bool na_app_set_icon(const char* utf8_path) {
  (void)utf8_path; return false;
}

bool na_app_set_dock_icon_visible(bool visible) {
  (void)visible; return false;
}

void na_app_set_dock_menu(uint32_t menu_id) { (void)menu_id; }
uint32_t na_app_dock_menu(void) { return 0; }

void na_app_set_callbacks(void* ctx,
                          na_app_fn on_started,
                          na_app_fn on_activated,
                          na_app_fn on_deactivated,
                          na_app_fn on_quit_requested,
                          na_app_exit_fn on_exiting) {
  g_ios_app_callbacks.ctx = ctx;
  g_ios_app_callbacks.on_started = on_started;
  g_ios_app_callbacks.on_activated = on_activated;
  g_ios_app_callbacks.on_deactivated = on_deactivated;
  g_ios_app_callbacks.on_quit_requested = on_quit_requested;
  g_ios_app_callbacks.on_exiting = on_exiting;
}
