#import <Cocoa/Cocoa.h>

#define NA_WINDOW_KIND_FOCUSED 0
#define NA_WINDOW_KIND_BLURRED 1
#define NA_WINDOW_KIND_MINIMIZED 2
#define NA_WINDOW_KIND_RESTORED 3
#define NA_WINDOW_KIND_MOVED 4
#define NA_WINDOW_KIND_RESIZED 5

typedef void (*na_window_event_fn)(int kind, uint32_t window_id, double a, double b, void* ctx);

static char g_title_buffer[512];

static NSMutableDictionary<NSNumber*, NSWindow*>* g_windows = nil;
static NSMutableDictionary<NSValue*, NSNumber*>* g_ids_by_object = nil;
static NSMutableDictionary<NSNumber*, NSVisualEffectView*>* g_effect_views = nil;
static NSMutableDictionary<NSNumber*, NSNumber*>* g_title_bar_styles = nil;
static NSMutableDictionary<NSNumber*, NSNumber*>* g_visual_effects = nil;

static uint32_t g_next_sequence = 0;

static void ensure_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_windows = [NSMutableDictionary dictionary];
    g_ids_by_object = [NSMutableDictionary dictionary];
    g_effect_views = [NSMutableDictionary dictionary];
    g_title_bar_styles = [NSMutableDictionary dictionary];
    g_visual_effects = [NSMutableDictionary dictionary];
  }
}

static uint32_t allocate_window_id(void) {
  g_next_sequence += 1;
  return (1u << 24) | g_next_sequence;
}

static uint32_t ensure_window_id(NSWindow* window) {
  NSValue* key = [NSValue valueWithPointer:(__bridge const void*)window];
  NSNumber* existing = g_ids_by_object[key];
  if (existing) {
    return existing.unsignedIntValue;
  }
  uint32_t id = allocate_window_id();
  g_ids_by_object[key] = @(id);
  return id;
}

static NSWindow* window_for(uint32_t id) {
  ensure_tables();
  return g_windows[@(id)];
}

uint32_t na_window_create(void) {
  ensure_tables();
  NSWindow* window = [[NSWindow alloc] init];
  window.styleMask = NSWindowStyleMaskResizable | NSWindowStyleMaskTitled |
                     NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable;
  uint32_t id = ensure_window_id(window);
  g_windows[@(id)] = window;
  g_title_bar_styles[@(id)] = @0;
  g_visual_effects[@(id)] = @0;
  return id;
}

void na_window_free(uint32_t id) {
  ensure_tables();
  NSWindow* window = g_windows[@(id)];
  if (!window) {
    return;
  }
  [g_windows removeObjectForKey:@(id)];
  [g_effect_views removeObjectForKey:@(id)];
  [g_title_bar_styles removeObjectForKey:@(id)];
  [g_visual_effects removeObjectForKey:@(id)];
}

bool na_window_exists(uint32_t id) {
  return window_for(id) != nil;
}

static NSRect na_primary_frame(void) {
  NSArray<NSScreen*>* screens = [NSScreen screens];
  if (screens.count == 0) {
    return NSMakeRect(0, 0, 0, 0);
  }
  return [[screens objectAtIndex:0] frame];
}

static double na_rect_top_left_y(NSRect rect) {
  return na_primary_frame().size.height - rect.origin.y - rect.size.height;
}

static double na_point_top_left_y(NSPoint point) {
  return na_primary_frame().size.height - point.y;
}

static NSPoint na_bottom_left_for_window(CGPoint top_left, CGFloat window_height) {
  double bottomY = na_primary_frame().size.height - top_left.y - window_height;
  return NSMakePoint(top_left.x, bottomY);
}

void na_window_focus(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return;
  [window makeKeyAndOrderFront:nil];
}

void na_window_blur(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return;
  [window orderBack:nil];
}

bool na_window_is_focused(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return false;
  return window.isKeyWindow ? true : false;
}

void na_window_show(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return;
  window.isVisible = YES;
  if (![window isKindOfClass:[NSPanel class]]) {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
  }
  [window makeKeyAndOrderFront:nil];
}

void na_window_show_inactive(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return;
  window.isVisible = YES;
  [window orderFrontRegardless];
}

void na_window_hide(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return;
  window.isVisible = NO;
  [window orderOut:nil];
}

bool na_window_is_visible(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return false;
  return window.isVisible ? true : false;
}

void na_window_maximize(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return;
  if (!window.isZoomed) {
    [window zoom:nil];
  }
}

void na_window_unmaximize(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return;
  if (window.isZoomed) {
    [window zoom:nil];
  }
}

bool na_window_is_maximized(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return false;
  return window.isZoomed ? true : false;
}

void na_window_minimize(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return;
  if (!window.isMiniaturized) {
    [window miniaturize:nil];
  }
}

void na_window_restore(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return;
  if (window.isMiniaturized) {
    [window deminiaturize:nil];
  }
}

bool na_window_is_minimized(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return false;
  return window.isMiniaturized ? true : false;
}

void na_window_set_full_screen(uint32_t id, bool full_screen) {
  NSWindow* window = window_for(id);
  if (!window) return;
  if (full_screen != ((window.styleMask & NSWindowStyleMaskFullScreen) != 0)) {
    [window toggleFullScreen:nil];
  }
}

bool na_window_is_full_screen(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return false;
  return (window.styleMask & NSWindowStyleMaskFullScreen) != 0;
}

void na_window_set_bounds(uint32_t id, double x, double y, double w, double h) {
  NSWindow* window = window_for(id);
  if (!window) return;
  NSRect top_left_rect = NSMakeRect(x, y, w, h);
  double bottom_y = na_primary_frame().size.height - y - h;
  NSRect ns_rect = NSMakeRect(top_left_rect.origin.x, bottom_y, w, h);
  [window setFrame:ns_rect display:YES];
}

void na_window_get_bounds(uint32_t id,
                          double* out_x,
                          double* out_y,
                          double* out_w,
                          double* out_h) {
  NSWindow* window = window_for(id);
  if (!window) {
    *out_x = 0; *out_y = 0; *out_w = 0; *out_h = 0;
    return;
  }
  NSRect frame = window.frame;
  *out_x = frame.origin.x;
  *out_y = na_rect_top_left_y(frame);
  *out_w = frame.size.width;
  *out_h = frame.size.height;
}

void na_window_set_size(uint32_t id, double width, double height, bool animate) {
  NSWindow* window = window_for(id);
  if (!window) return;
  NSRect frame = window.frame;
  frame.origin.y += (frame.size.height - height);
  frame.size.width = width;
  frame.size.height = height;
  if (animate) {
    [[window animator] setFrame:frame display:YES animate:YES];
  } else {
    [window setFrame:frame display:YES];
  }
}

void na_window_get_size(uint32_t id, double* out_w, double* out_h) {
  NSWindow* window = window_for(id);
  if (!window) {
    *out_w = 0; *out_h = 0;
    return;
  }
  NSRect frame = window.frame;
  *out_w = frame.size.width;
  *out_h = frame.size.height;
}

void na_window_set_content_size(uint32_t id, double width, double height) {
  NSWindow* window = window_for(id);
  if (!window) return;
  [window setContentSize:NSMakeSize(width, height)];
}

void na_window_set_max_size(uint32_t id, double width, double height) {
  NSWindow* window = window_for(id);
  if (!window) return;
  [window setMaxSize:NSMakeSize(width, height)];
}

void* na_window_native(uint32_t id) {
  NSWindow* window = window_for(id);
  return (__bridge void*)window;
}

void na_window_set_min_size(uint32_t id, double width, double height) {
  NSWindow* window = window_for(id);
  if (!window) return;
  [window setMinSize:NSMakeSize(width, height)];
}

void na_window_get_content_size(uint32_t id, double* out_w, double* out_h) {
  NSWindow* window = window_for(id);
  if (!window) {
    *out_w = 0; *out_h = 0;
    return;
  }
  NSRect frame = [window contentRectForFrameRect:window.frame];
  *out_w = frame.size.width;
  *out_h = frame.size.height;
}

void na_window_set_content_bounds(uint32_t id, double x, double y, double w, double h) {
  NSWindow* window = window_for(id);
  if (!window) return;
  double bottom_y = na_primary_frame().size.height - y - h;
  NSRect content_rect = NSMakeRect(x, bottom_y, w, h);
  NSRect frame_rect = [window frameRectForContentRect:content_rect];
  [window setFrame:frame_rect display:YES];
}

void na_window_get_content_bounds(uint32_t id,
                                  double* out_x,
                                  double* out_y,
                                  double* out_w,
                                  double* out_h) {
  NSWindow* window = window_for(id);
  if (!window) {
    *out_x = 0; *out_y = 0; *out_w = 0; *out_h = 0;
    return;
  }
  NSRect content_rect = [window contentRectForFrameRect:window.frame];
  *out_x = content_rect.origin.x;
  *out_y = na_rect_top_left_y(content_rect);
  *out_w = content_rect.size.width;
  *out_h = content_rect.size.height;
}

void na_window_set_minimum_size(uint32_t id, double width, double height) {
  NSWindow* window = window_for(id);
  if (!window) return;
  window.minSize = NSMakeSize(width, height);
}

void na_window_get_minimum_size(uint32_t id, double* out_w, double* out_h) {
  NSWindow* window = window_for(id);
  if (!window) {
    *out_w = 0; *out_h = 0;
    return;
  }
  *out_w = window.minSize.width;
  *out_h = window.minSize.height;
}

void na_window_set_maximum_size(uint32_t id, double width, double height) {
  NSWindow* window = window_for(id);
  if (!window) return;
  window.maxSize = NSMakeSize(width, height);
}

void na_window_get_maximum_size(uint32_t id, double* out_w, double* out_h) {
  NSWindow* window = window_for(id);
  if (!window) {
    *out_w = 0; *out_h = 0;
    return;
  }
  *out_w = window.maxSize.width;
  *out_h = window.maxSize.height;
}

void na_window_set_position(uint32_t id, double x, double y) {
  NSWindow* window = window_for(id);
  if (!window) return;
  NSRect frame = window.frame;
  CGPoint top_left = CGPointMake(x, y);
  NSPoint bottom_left = na_bottom_left_for_window(top_left, frame.size.height);
  [window setFrameOrigin:bottom_left];
}

void na_window_get_position(uint32_t id, double* out_x, double* out_y) {
  NSWindow* window = window_for(id);
  if (!window) {
    *out_x = 0; *out_y = 0;
    return;
  }
  NSRect frame = window.frame;
  *out_x = frame.origin.x;
  *out_y = na_rect_top_left_y(frame);
}

void na_window_center(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return;
  [window center];
}

void na_window_set_title(uint32_t id, const char* utf8_title) {
  NSWindow* window = window_for(id);
  if (!window || !utf8_title) return;
  window.title = [NSString stringWithUTF8String:utf8_title];
}

const char* na_window_get_title(uint32_t id) {
  g_title_buffer[0] = '\0';
  NSWindow* window = window_for(id);
  if (!window || !window.title) {
    return g_title_buffer;
  }
  strncpy(g_title_buffer, window.title.UTF8String, sizeof(g_title_buffer) - 1);
  g_title_buffer[sizeof(g_title_buffer) - 1] = '\0';
  return g_title_buffer;
}

static void set_style_mask_bit(NSWindow* window, NSUInteger bit, bool enabled) {
  NSUInteger mask = window.styleMask;
  if (enabled) {
    mask |= bit;
  } else {
    mask &= ~bit;
  }
  window.styleMask = mask;
}

void na_window_set_resizable(uint32_t id, bool resizable) {
  NSWindow* window = window_for(id);
  if (!window) return;
  set_style_mask_bit(window, NSWindowStyleMaskResizable, resizable);
}

bool na_window_is_resizable(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return false;
  return (window.styleMask & NSWindowStyleMaskResizable) != 0;
}

void na_window_set_movable(uint32_t id, bool movable) {
  NSWindow* window = window_for(id);
  if (!window) return;
  window.movable = movable ? YES : NO;
}

bool na_window_is_movable(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return false;
  return window.isMovable ? true : false;
}

void na_window_set_minimizable(uint32_t id, bool minimizable) {
  NSWindow* window = window_for(id);
  if (!window) return;
  set_style_mask_bit(window, NSWindowStyleMaskMiniaturizable, minimizable);
}

bool na_window_is_minimizable(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return false;
  return (window.styleMask & NSWindowStyleMaskMiniaturizable) != 0;
}

void na_window_set_maximizable(uint32_t id, bool maximizable) {
  NSWindow* window = window_for(id);
  if (!window) return;
  set_style_mask_bit(window, NSWindowStyleMaskResizable, maximizable);
}

bool na_window_is_maximizable(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return false;
  return (window.styleMask & NSWindowStyleMaskResizable) != 0;
}

void na_window_set_closable(uint32_t id, bool closable) {
  NSWindow* window = window_for(id);
  if (!window) return;
  set_style_mask_bit(window, NSWindowStyleMaskClosable, closable);
}

bool na_window_is_closable(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return false;
  return (window.styleMask & NSWindowStyleMaskClosable) != 0;
}

void na_window_set_always_on_top(uint32_t id, bool always_on_top) {
  NSWindow* window = window_for(id);
  if (!window) return;
  window.level = always_on_top ? NSFloatingWindowLevel : NSNormalWindowLevel;
}

bool na_window_is_always_on_top(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return false;
  return window.level == NSFloatingWindowLevel;
}

void na_window_set_visible_on_all_workspaces(uint32_t id, bool visible) {
  NSWindow* window = window_for(id);
  if (!window) return;
  window.collectionBehavior = visible ? NSWindowCollectionBehaviorCanJoinAllSpaces
                                      : NSWindowCollectionBehaviorDefault;
}

bool na_window_is_visible_on_all_workspaces(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return false;
  return (window.collectionBehavior & NSWindowCollectionBehaviorCanJoinAllSpaces) != 0;
}

void na_window_set_ignore_mouse_events(uint32_t id, bool ignore) {
  NSWindow* window = window_for(id);
  if (!window) return;
  window.ignoresMouseEvents = ignore ? YES : NO;
}

bool na_window_is_ignore_mouse_events(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return false;
  return window.ignoresMouseEvents ? true : false;
}

bool na_window_is_focusable(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return false;
  return window.canBecomeKeyWindow ? true : false;
}

void na_window_set_has_shadow(uint32_t id, bool has_shadow) {
  NSWindow* window = window_for(id);
  if (!window) return;
  window.hasShadow = has_shadow ? YES : NO;
  [window invalidateShadow];
}

bool na_window_has_shadow(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return false;
  return window.hasShadow ? true : false;
}

void na_window_set_opacity(uint32_t id, float opacity) {
  NSWindow* window = window_for(id);
  if (!window) return;
  window.alphaValue = opacity;
}

float na_window_get_opacity(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return 1.0f;
  return window.alphaValue;
}

void na_window_set_background_color(uint32_t id, unsigned char r, unsigned char g,
                                    unsigned char b, unsigned char a) {
  NSWindow* window = window_for(id);
  if (!window) return;
  NSColor* color = [NSColor colorWithRed:r / 255.0
                                   green:g / 255.0
                                    blue:b / 255.0
                                   alpha:a / 255.0];
  window.backgroundColor = color;
}

void na_window_get_background_color(uint32_t id,
                                    unsigned char* out_r,
                                    unsigned char* out_g,
                                    unsigned char* out_b,
                                    unsigned char* out_a) {
  NSWindow* window = window_for(id);
  if (!window) {
    *out_r = 255; *out_g = 255; *out_b = 255; *out_a = 255;
    return;
  }
  NSColor* rgb = [window.backgroundColor colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
  if (!rgb) {
    *out_r = 255; *out_g = 255; *out_b = 255; *out_a = 255;
    return;
  }
  CGFloat r, g, b, a;
  [rgb getRed:&r green:&g blue:&b alpha:&a];
  *out_r = (unsigned char)(r * 255);
  *out_g = (unsigned char)(g * 255);
  *out_b = (unsigned char)(b * 255);
  *out_a = (unsigned char)(a * 255);
}

void na_window_set_title_bar_style(uint32_t id, int style) {
  NSWindow* window = window_for(id);
  if (!window) return;
  g_title_bar_styles[@(id)] = @(style);
  if (style == 1) {
    window.titleVisibility = NSWindowTitleHidden;
    window.titlebarAppearsTransparent = YES;
    window.styleMask |= NSWindowStyleMaskFullSizeContentView;
  } else {
    window.titleVisibility = NSWindowTitleVisible;
    window.titlebarAppearsTransparent = NO;
    window.styleMask &= ~NSWindowStyleMaskFullSizeContentView;
  }
  window.opaque = NO;
  window.hasShadow = YES;
  NSButton* closeButton = [window standardWindowButton:NSWindowCloseButton];
  NSButton* miniButton = [window standardWindowButton:NSWindowMiniaturizeButton];
  NSButton* zoomButton = [window standardWindowButton:NSWindowZoomButton];
  NSView* titleBarView = closeButton.superview.superview;
  if (titleBarView) {
    titleBarView.hidden = NO;
  }
  closeButton.hidden = NO;
  miniButton.hidden = NO;
  zoomButton.hidden = NO;
}

int na_window_get_title_bar_style(uint32_t id) {
  ensure_tables();
  NSNumber* style = g_title_bar_styles[@(id)];
  return style ? style.intValue : 0;
}

void na_window_set_visual_effect(uint32_t id, int effect) {
  NSWindow* window = window_for(id);
  if (!window) return;
  NSNumber* current = g_visual_effects[@(id)];
  if (current && current.intValue == effect) {
    return;
  }
  g_visual_effects[@(id)] = @(effect);

  if (effect == 0) {
    NSVisualEffectView* view = g_effect_views[@(id)];
    if (view) {
      [view removeFromSuperview];
      [g_effect_views removeObjectForKey:@(id)];
    }
    window.opaque = YES;
    window.backgroundColor = [NSColor windowBackgroundColor];
    return;
  }

  NSVisualEffectView* view = g_effect_views[@(id)];
  if (!view) {
    NSView* contentView = window.contentView;
    view = [[NSVisualEffectView alloc] initWithFrame:contentView.bounds];
    view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    view.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    [contentView addSubview:view positioned:NSWindowBelow relativeTo:nil];
    g_effect_views[@(id)] = view;
  }

  window.opaque = NO;
  window.backgroundColor = [NSColor clearColor];

  switch (effect) {
    case 1:
      view.material = NSVisualEffectMaterialSidebar;
      break;
    case 2:
      view.material = NSVisualEffectMaterialUnderWindowBackground;
      break;
    case 3:
      view.material = NSVisualEffectMaterialWindowBackground;
      break;
    default:
      break;
  }
  view.state = NSVisualEffectStateActive;
}

int na_window_get_visual_effect(uint32_t id) {
  ensure_tables();
  NSNumber* effect = g_visual_effects[@(id)];
  return effect ? effect.intValue : 0;
}

void na_window_start_dragging(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window) return;
  if (window.currentEvent) {
    [window performWindowDragWithEvent:window.currentEvent];
  }
}

int na_window_list_ids(uint32_t* out_ids, int max_count) {
  ensure_tables();
  int count = 0;
  for (NSNumber* idNumber in g_windows) {
    if (count >= max_count) {
      return count;
    }
    out_ids[count] = idNumber.unsignedIntValue;
    count += 1;
  }
  NSArray<NSWindow*>* appWindows = [[NSApplication sharedApplication] windows];
  for (NSWindow* window in appWindows) {
    if (count >= max_count) {
      break;
    }
    uint32_t id = ensure_window_id(window);
    BOOL known = NO;
    for (int i = 0; i < count; i++) {
      if (out_ids[i] == id) {
        known = YES;
        break;
      }
    }
    if (!known) {
      out_ids[count] = id;
      count += 1;
    }
  }
  return count;
}

uint32_t na_window_main_window_id(void) {
  NSApplication* app = [NSApplication sharedApplication];
  NSWindow* main = app.mainWindow;
  if (!main) {
    NSArray<NSWindow*>* windows = app.windows;
    if (windows.count > 0) {
      main = [windows objectAtIndex:0];
    }
  }
  if (!main) {
    return 0;
  }
  uint32_t id = ensure_window_id(main);
  if (![g_windows objectForKey:@(id)]) {
    g_windows[@(id)] = main;
  }
  return id;
}

static struct {
  na_window_event_fn fn;
  void* ctx;
} g_window_events = {NULL, NULL};

@implementation NAWindowEventsObserver : NSObject
- (void)handle:(NSNotification*)notification {
  @autoreleasepool {
    if (!g_window_events.fn) {
      return;
    }
    NSWindow* window = notification.object;
    if (!window) {
      return;
    }
    uint32_t id = ensure_window_id(window);
    NSString* name = notification.name;
    double a = 0;
    double b = 0;
    int kind;
    if ([name isEqual:NSWindowDidBecomeKeyNotification]) {
      kind = NA_WINDOW_KIND_FOCUSED;
    } else if ([name isEqual:NSWindowDidResignKeyNotification]) {
      kind = NA_WINDOW_KIND_BLURRED;
    } else if ([name isEqual:NSWindowDidMiniaturizeNotification]) {
      kind = NA_WINDOW_KIND_MINIMIZED;
    } else if ([name isEqual:NSWindowDidDeminiaturizeNotification]) {
      kind = NA_WINDOW_KIND_RESTORED;
    } else if ([name isEqual:NSWindowDidMoveNotification]) {
      kind = NA_WINDOW_KIND_MOVED;
      a = window.frame.origin.x;
      b = na_rect_top_left_y(window.frame);
    } else if ([name isEqual:NSWindowDidResizeNotification]) {
      kind = NA_WINDOW_KIND_RESIZED;
      a = window.frame.size.width;
      b = window.frame.size.height;
    } else {
      return;
    }
    g_window_events.fn(kind, id, a, b, g_window_events.ctx);
  }
}
@end

static NAWindowEventsObserver* g_window_observer = nil;

void na_window_set_event_callback(na_window_event_fn fn, void* ctx) {
  ensure_tables();
  g_window_events.fn = fn;
  g_window_events.ctx = ctx;
  if (g_window_observer) {
    return;
  }
  g_window_observer = [[NAWindowEventsObserver alloc] init];
  NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
  NSArray* names = @[
    NSWindowDidBecomeKeyNotification,
    NSWindowDidResignKeyNotification,
    NSWindowDidMiniaturizeNotification,
    NSWindowDidDeminiaturizeNotification,
    NSWindowDidMoveNotification,
    NSWindowDidResizeNotification
  ];
  for (NSString* name in names) {
    [center addObserver:g_window_observer
               selector:@selector(handle:)
                   name:name
                 object:nil];
  }
}

void* na_window_content_view(uint32_t id) {
  NSWindow* window = window_for(id);
  if (!window || !window.contentView) {
    return NULL;
  }
  return (__bridge void*)window.contentView;
}

void na_window_set_root_view(uint32_t id, void* viewPtr) {
  NSWindow* window = window_for(id);
  NSView* root = (__bridge NSView*)viewPtr;
  if (!window || !root) {
    return;
  }
  NSView* content = window.contentView;
  [[content subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
  root.translatesAutoresizingMaskIntoConstraints = NO;
  [content addSubview:root];
  [NSLayoutConstraint activateConstraints:@[
    [root.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
    [root.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
    [root.topAnchor constraintEqualToAnchor:content.topAnchor],
    [root.bottomAnchor constraintEqualToAnchor:content.bottomAnchor]
  ]];
  [content layoutSubtreeIfNeeded];
}
