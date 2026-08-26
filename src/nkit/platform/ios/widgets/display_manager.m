#import <UIKit/UIKit.h>

typedef void (*na_screens_changed_fn)(void* ctx);

static na_screens_changed_fn g_screens_changed_fn = NULL;
static void* g_screens_changed_ctx = NULL;

int na_screen_count(void);
uint32_t na_screen_display_id(int index);

static void handle_connect_disconnect(void) {
  if (g_screens_changed_fn) {
    g_screens_changed_fn(g_screens_changed_ctx);
  }
}

void na_screen_get_cursor_position(double* out_x, double* out_y) {
  // No cursor on iOS; report the center of the main screen so callers
  // get an in-bounds value.
  CGRect bounds = [UIScreen mainScreen].bounds;
  if (out_x) *out_x = bounds.size.width / 2.0;
  if (out_y) *out_y = bounds.size.height / 2.0;
}

void na_screen_set_changed_callback(na_screens_changed_fn fn, void* ctx) {
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [center addObserverForName:UIScreenDidConnectNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification* note) {
                      handle_connect_disconnect();
                    }];
    [center addObserverForName:UIScreenDidDisconnectNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification* note) {
                      handle_connect_disconnect();
                    }];
  });
  g_screens_changed_fn = fn;
  g_screens_changed_ctx = ctx;
}

// Convenience wrappers used by the display manager module.

int na_display_manager_count(void) {
  return na_screen_count();
}
