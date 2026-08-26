#import "gui_common.h"

@interface NAPersistentRootVC : UIViewController
@end
@implementation NAPersistentRootVC
- (BOOL)prefersStatusBarHidden { return NO; }
- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleDefault; }
@end

// Persistent root view controller that exists before the window.
// Layout attaches subviews to its view; the window inherits it later.
static NAPersistentRootVC* g_bridge_vc = nil;

static void ensure_bridge_vc(void) {
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    g_bridge_vc = [[NAPersistentRootVC alloc] init];
    g_bridge_vc.view.backgroundColor = [UIColor whiteColor];
  });
}

UIViewController* na_ios_bridge_vc(void) {
  ensure_bridge_vc();
  return g_bridge_vc;
}

typedef void (*na_window_event_fn)(int kind, uint32_t window_id,
                                   double a, double b, void* ctx);

static NSMutableDictionary<NSNumber*, UIWindow*>* g_windows = nil;
static NSMutableArray<NSNumber*>* g_window_order = nil;
static uint32_t g_next_window_id = 0;
static na_window_event_fn g_window_event_fn = NULL;
static void* g_window_event_ctx = NULL;
NSMutableArray* g_pending_ids = nil;
static NSMutableDictionary<NSNumber*, NSDictionary*>* g_pending_config = nil;
static NSMutableDictionary<NSNumber*, NSNumber*>* g_pending_root_views = nil;

static void ensure_registry(void) {
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    g_windows = [NSMutableDictionary dictionary];
    g_window_order = [NSMutableArray array];
    g_pending_ids = [NSMutableArray array];
    g_pending_config = [NSMutableDictionary dictionary];
    g_pending_root_views = [NSMutableDictionary dictionary];
  });
}

static UIWindow* window_for(uint32_t id) {
  ensure_registry();
  return g_windows[@(id)];
}

// Called from NAAppDelegate to create UIWindow with a scene.
// Reuses the bridge VC so layout views (added pre-launch) carry over.
void na_ios_create_window_for_id(uint32_t id, UIWindowScene* scene) {
  ensure_registry();
  ensure_bridge_vc();

  UIWindow* w = [[UIWindow alloc] initWithWindowScene:scene];

  NSDictionary* cfg = g_pending_config[@(id)];
  if (cfg) {
    CGFloat bgR = [cfg[@"bgR"] doubleValue];
    CGFloat bgG = [cfg[@"bgG"] doubleValue];
    CGFloat bgB = [cfg[@"bgB"] doubleValue];
    CGFloat bgA = [cfg[@"bgA"] doubleValue];
    w.backgroundColor =
        [UIColor colorWithRed:bgR green:bgG blue:bgB alpha:bgA];
    g_bridge_vc.view.backgroundColor = w.backgroundColor;
    [g_pending_config removeObjectForKey:@(id)];
  } else {
    w.backgroundColor = [UIColor whiteColor];
    g_bridge_vc.view.backgroundColor = [UIColor whiteColor];
  }

  w.frame = scene.screen.bounds;
  w.windowLevel = UIWindowLevelNormal;
  g_bridge_vc.view.frame = w.bounds;
  g_bridge_vc.view.autoresizingMask =
      UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  w.rootViewController = g_bridge_vc;

  // Apply pending root view if set before window creation.
  NSNumber* pendingRv = g_pending_root_views[@(id)];
  if (pendingRv) {
    uintptr_t ptr = pendingRv.unsignedLongLongValue;
    UIView* rv = (__bridge UIView*)((void*)ptr);
    UIView* cv = g_bridge_vc.view;
    for (UIView* sub in [cv.subviews copy]) { [sub removeFromSuperview]; }
    rv.frame = cv.bounds;
    rv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [cv addSubview:rv];
    [g_pending_root_views removeObjectForKey:@(id)];
  }

  g_windows[@(id)] = w;
  [g_window_order addObject:@(id)];
}

uint32_t na_window_create(void) {
  ensure_registry();
  ++g_next_window_id;
  uint32_t id = g_next_window_id;
  [g_pending_ids addObject:@(id)];
  if (g_window_event_fn) {
    g_window_event_fn(0, id, 0.0, 0.0, g_window_event_ctx);
  }
  return id;
}

void na_window_free(uint32_t id) {
  UIWindow* w = window_for(id);
  if (w) {
    w.hidden = YES;
    [g_windows removeObjectForKey:@(id)];
    [g_window_order removeObject:@(id)];
  }
  [g_pending_ids removeObject:@(id)];
  [g_pending_config removeObjectForKey:@(id)];
}

bool na_window_exists(uint32_t id) {
  return window_for(id) != nil || [g_pending_ids containsObject:@(id)];
}

void na_window_focus(uint32_t id) {
  UIWindow* w = window_for(id);
  if (w) { [w makeKeyWindow]; }
}

void na_window_blur(uint32_t id) {
  UIWindow* w = window_for(id);
  if (w && w.keyWindow) { [w resignKeyWindow]; }
}

bool na_window_is_focused(uint32_t id) {
  UIWindow* w = window_for(id);
  return w != nil && w.isKeyWindow;
}

void na_window_show(uint32_t id) {
  UIWindow* w = window_for(id);
  if (w) { w.hidden = NO; [w makeKeyAndVisible]; }
}

void na_window_show_inactive(uint32_t id) { na_window_show(id); }

void na_window_hide(uint32_t id) {
  UIWindow* w = window_for(id);
  if (w) { w.hidden = YES; }
}

bool na_window_is_visible(uint32_t id) {
  UIWindow* w = window_for(id);
  return w != nil && !w.isHidden;
}

void na_window_maximize(uint32_t id) { (void)id; }
void na_window_unmaximize(uint32_t id) { (void)id; }
bool na_window_is_maximized(uint32_t id) { (void)id; return false; }
void na_window_minimize(uint32_t id) { (void)id; }
void na_window_restore(uint32_t id) { na_window_show(id); }
bool na_window_is_minimized(uint32_t id) { (void)id; return false; }

void na_window_set_full_screen(uint32_t id, bool fs) {
  UIWindow* w = window_for(id);
  if (w) { w.rootViewController.modalPresentationStyle =
      fs ? UIModalPresentationFullScreen : UIModalPresentationPageSheet; }
}

bool na_window_is_full_screen(uint32_t id) {
  UIWindow* w = window_for(id);
  return w && w.rootViewController.modalPresentationStyle == UIModalPresentationFullScreen;
}

void na_window_set_bounds(uint32_t id, double x, double y, double ww, double hh) {
  UIWindow* w = window_for(id);
  if (w) { w.frame = CGRectMake(x, y, ww, hh); }
}

void na_window_get_bounds(uint32_t id, double* ox, double* oy, double* ow, double* oh) {
  UIWindow* w = window_for(id);
  CGRect f = w ? w.frame : CGRectMake(0, 0, 420, 320);
  if (ox) *ox = f.origin.x; if (oy) *oy = f.origin.y;
  if (ow) *ow = f.size.width; if (oh) *oh = f.size.height;
}

void na_window_set_size(uint32_t id, double ww, double hh, bool anim) {
  UIWindow* w = window_for(id);
  if (!w) { return; }
  CGRect f = w.frame; f.size.width = ww; f.size.height = hh;
  if (anim) { [UIView animateWithDuration:0.3 animations:^{ w.frame = f; }]; }
  else { w.frame = f; }
}

void na_window_get_size(uint32_t id, double* ow, double* oh) {
  UIWindow* w = window_for(id);
  CGSize s = w ? w.frame.size : CGSizeMake(420, 320);
  if (ow) *ow = s.width; if (oh) *oh = s.height;
}

void na_window_set_content_size(uint32_t id, double w, double h) { na_window_set_size(id, w, h, false); }
void na_window_get_content_size(uint32_t id, double* ow, double* oh) { na_window_get_size(id, ow, oh); }
void na_window_set_content_bounds(uint32_t id, double x, double y, double w, double h) { na_window_set_bounds(id, x, y, w, h); }
void na_window_get_content_bounds(uint32_t id, double* ox, double* oy, double* ow, double* oh) { na_window_get_bounds(id, ox, oy, ow, oh); }

void na_window_set_min_size(uint32_t id, double w, double h) { (void)id; (void)w; (void)h; }
void na_window_get_min_size(uint32_t id, double* ow, double* oh) { (void)id; if (ow) *ow=0; if (oh) *oh=0; }
void na_window_set_max_size(uint32_t id, double w, double h) { (void)id; (void)w; (void)h; }
void na_window_get_max_size(uint32_t id, double* ow, double* oh) { (void)id; if (ow) *ow=0; if (oh) *oh=0; }
void na_window_set_minimum_size(uint32_t id, double w, double h) { na_window_set_min_size(id, w, h); }
void na_window_get_minimum_size(uint32_t id, double* ow, double* oh) { na_window_get_min_size(id, ow, oh); }
void na_window_set_maximum_size(uint32_t id, double w, double h) { na_window_set_max_size(id, w, h); }
void na_window_get_maximum_size(uint32_t id, double* ow, double* oh) { na_window_get_max_size(id, ow, oh); }

void na_window_set_position(uint32_t id, double x, double y) {
  UIWindow* w = window_for(id);
  if (w) { CGRect f = w.frame; f.origin.x = x; f.origin.y = y; w.frame = f; }
}

void na_window_get_position(uint32_t id, double* ox, double* oy) {
  CGPoint p = window_for(id) ? window_for(id).frame.origin : CGPointZero;
  if (ox) *ox = p.x; if (oy) *oy = p.y;
}

void na_window_center(uint32_t id) {
  UIWindow* w = window_for(id);
  if (!w) { return; }
  CGRect sb = (w.screen ?: [UIScreen mainScreen]).bounds;
  CGRect f = w.frame;
  f.origin.x = (sb.size.width - f.size.width) / 2.0;
  f.origin.y = (sb.size.height - f.size.height) / 2.0;
  w.frame = f;
}

void na_window_set_title(uint32_t id, const char* t) {
  UIViewController* vc = window_for(id).rootViewController;
  if (vc) { vc.title = [NSString stringWithUTF8String:t ?: ""]; }
}

const char* na_window_get_title(uint32_t id) {
  static char buf[2048];
  UIViewController* vc = window_for(id).rootViewController;
  NSString* t = vc.title;
  buf[0] = '\0';
  if (t.UTF8String) { strncpy(buf, t.UTF8String, sizeof(buf)-1); }
  return buf;
}

void na_window_set_resizable(uint32_t id, bool v) { (void)id; (void)v; }
bool na_window_is_resizable(uint32_t id) { (void)id; return false; }
void na_window_set_movable(uint32_t id, bool v) { (void)id; (void)v; }
bool na_window_is_movable(uint32_t id) { (void)id; return false; }
void na_window_set_minimizable(uint32_t id, bool v) { (void)id; (void)v; }
bool na_window_is_minimizable(uint32_t id) { (void)id; return true; }
void na_window_set_maximizable(uint32_t id, bool v) { (void)id; (void)v; }
bool na_window_is_maximizable(uint32_t id) { (void)id; return false; }
void na_window_set_closable(uint32_t id, bool v) { (void)id; (void)v; }
bool na_window_is_closable(uint32_t id) { (void)id; return true; }
bool na_window_is_focusable(uint32_t id) { (void)id; return true; }

void na_window_set_always_on_top(uint32_t id, bool top) {
  UIWindow* w = window_for(id);
  if (!w) { return; }
  if (top) {
    double h = w.windowLevel;
    for (UIWindow* o in g_windows.objectEnumerator)
      if (o != w && o.windowLevel > h) h = o.windowLevel;
    w.windowLevel = h + 1.0;
  } else { w.windowLevel = UIWindowLevelNormal; }
}

bool na_window_is_always_on_top(uint32_t id) { (void)id; return false; }
void na_window_set_visible_on_all_workspaces(uint32_t id, bool v) { (void)id; (void)v; }
bool na_window_is_visible_on_all_workspaces(uint32_t id) { (void)id; return false; }
void na_window_set_ignore_mouse_events(uint32_t id, bool v) { (void)id; (void)v; }
bool na_window_is_ignore_mouse_events(uint32_t id) { (void)id; return false; }
void na_window_start_dragging(uint32_t id) { (void)id; }
void na_window_set_has_shadow(uint32_t id, bool v) { (void)id; (void)v; }
bool na_window_has_shadow(uint32_t id) { (void)id; return true; }

void na_window_set_opacity(uint32_t id, float o) {
  UIWindow* w = window_for(id); if (w) w.alpha = o;
}

float na_window_get_opacity(uint32_t id) {
  UIWindow* w = window_for(id); return w ? w.alpha : 1.0f;
}

void na_window_set_background_color(uint32_t id, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
  ensure_registry();
  UIColor* c = [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a/255.0];
  UIWindow* w = window_for(id);
  if (w) { w.rootViewController.view.backgroundColor = c; }
  else { g_pending_config[@(id)] = @{ @"bgR":@(r/255.),@"bgG":@(g/255.),@"bgB":@(b/255.),@"bgA":@(a/255.) }; }
}

void na_window_get_background_color(uint32_t id, uint8_t* or, uint8_t* og, uint8_t* ob, uint8_t* oa) {
  UIViewController* vc = window_for(id).rootViewController;
  UIColor* c = vc.view.backgroundColor ?: [UIColor whiteColor];
  CGFloat r=1,g=1,b=1,a=1; [c getRed:&r green:&g blue:&b alpha:&a];
  if (or)*or=(uint8_t)(r*255+.5); if (og)*og=(uint8_t)(g*255+.5);
  if (ob)*ob=(uint8_t)(b*255+.5); if (oa)*oa=(uint8_t)(a*255+.5);
}

void na_window_set_title_bar_style(uint32_t id, int s) { (void)id; (void)s; }
int na_window_get_title_bar_style(uint32_t id) { (void)id; return 0; }
void na_window_set_visual_effect(uint32_t id, int e) { (void)id; (void)e; }
int na_window_get_visual_effect(uint32_t id) { (void)id; return 0; }

int na_window_list_ids(uint32_t* out, int max) {
  ensure_registry(); int n = 0;
  for (NSNumber* k in g_window_order) { if (n>=max) break; if(out)out[n]=k.unsignedIntValue; ++n; }
  return n;
}

uint32_t na_window_main_window_id(void) {
  ensure_registry();
  for (UIWindow* w in [UIApplication.sharedApplication windows]) {
    if (w.isKeyWindow) {
      for (NSNumber* k in g_window_order)
        if (g_windows[k] == w) return k.unsignedIntValue;
    }
  }
  return g_window_order.firstObject.unsignedIntValue ?: 0;
}

void na_window_set_event_callback(na_window_event_fn fn, void* ctx) {
  g_window_event_fn = fn; g_window_event_ctx = ctx;
}

void* na_window_native(uint32_t id) {
  return (__bridge void*)window_for(id);
}

void* na_window_content_view(uint32_t id) {
  // Always return the bridge VC's view — it persists across the
  // pre-launch and post-launch phases.
  ensure_bridge_vc();
  return (__bridge void*)g_bridge_vc.view;
}

void na_window_set_root_view(uint32_t id, void* vp) {
  ensure_registry();
  UIWindow* win = window_for(id);
  if (win && vp) {
    // Window exists — attach immediately.
    UIView* rv = (__bridge UIView*)vp;
    UIView* cv = win.rootViewController.view;
    for (UIView* sub in [cv.subviews copy]) { [sub removeFromSuperview]; }
    rv.frame = cv.bounds;
    rv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [cv addSubview:rv];
  } else if (vp) {
    // Window not yet created — store as pending NSNumber pointer.
    g_pending_root_views[@(id)] = @((uintptr_t)vp);
  }
}
