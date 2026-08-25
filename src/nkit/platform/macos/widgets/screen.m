#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>

typedef void (*na_screens_changed_fn)(void* ctx);

static char g_screen_name_buffer[256];

static NSRect na_primary_screen_frame(void) {
  NSArray<NSScreen*>* screens = [NSScreen screens];
  if (screens.count == 0) {
    return NSMakeRect(0, 0, 0, 0);
  }
  return [[screens objectAtIndex:0] frame];
}

static double na_rect_top_left_y(NSRect rect) {
  NSRect primary = na_primary_screen_frame();
  return primary.size.height - rect.origin.y - rect.size.height;
}

static double na_point_top_left_y(NSPoint point) {
  NSRect primary = na_primary_screen_frame();
  return primary.size.height - point.y;
}

static NSScreen* na_find_screen(uint32_t display_id) {
  NSArray<NSScreen*>* screens = [NSScreen screens];
  for (NSScreen* screen in screens) {
    uint32_t sid = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] unsignedIntValue];
    if (sid == display_id) {
      return screen;
    }
  }
  return nil;
}

int na_screen_count(void) {
  return (int)[[NSScreen screens] count];
}

uint32_t na_screen_display_id(int index) {
  NSArray<NSScreen*>* screens = [NSScreen screens];
  if (index < 0 || index >= (int)screens.count) {
    return 0;
  }
  NSScreen* screen = [screens objectAtIndex:index];
  return [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] unsignedIntValue];
}

bool na_screen_is_primary(uint32_t display_id) {
  NSArray<NSScreen*>* screens = [NSScreen screens];
  if (screens.count == 0) {
    return false;
  }
  NSNumber* firstNumber = [[[screens objectAtIndex:0] deviceDescription]
      objectForKey:@"NSScreenNumber"];
  return [firstNumber unsignedIntValue] == display_id;
}

const char* na_screen_get_name(uint32_t display_id) {
  g_screen_name_buffer[0] = '\0';
  NSScreen* screen = na_find_screen(display_id);
  if (!screen) {
    return g_screen_name_buffer;
  }
  NSString* name = [screen localizedName];
  if (!name) {
    return g_screen_name_buffer;
  }
  strncpy(g_screen_name_buffer, [name UTF8String], sizeof(g_screen_name_buffer) - 1);
  g_screen_name_buffer[sizeof(g_screen_name_buffer) - 1] = '\0';
  return g_screen_name_buffer;
}

void na_screen_get_frame(uint32_t display_id,
                         double* out_x,
                         double* out_y,
                         double* out_w,
                         double* out_h) {
  NSScreen* screen = na_find_screen(display_id);
  if (!screen) {
    *out_x = 0;
    *out_y = 0;
    *out_w = 0;
    *out_h = 0;
    return;
  }
  NSRect frame = [screen frame];
  *out_x = frame.origin.x;
  *out_y = na_rect_top_left_y(frame);
  *out_w = frame.size.width;
  *out_h = frame.size.height;
}

void na_screen_get_work_area(uint32_t display_id,
                             double* out_x,
                             double* out_y,
                             double* out_w,
                             double* out_h) {
  NSScreen* screen = na_find_screen(display_id);
  if (!screen) {
    *out_x = 0;
    *out_y = 0;
    *out_w = 0;
    *out_h = 0;
    return;
  }
  NSRect visibleFrame = [screen visibleFrame];
  *out_x = visibleFrame.origin.x;
  *out_y = na_rect_top_left_y(visibleFrame);
  *out_w = visibleFrame.size.width;
  *out_h = visibleFrame.size.height;
}

double na_screen_get_scale_factor(uint32_t display_id) {
  NSScreen* screen = na_find_screen(display_id);
  if (!screen) {
    return 1.0;
  }
  return [screen backingScaleFactor];
}

int na_screen_get_refresh_rate(uint32_t display_id) {
  CGDisplayModeRef mode = CGDisplayCopyDisplayMode((CGDirectDisplayID)display_id);
  if (!mode) {
    return 60;
  }
  double rate = CGDisplayModeGetRefreshRate(mode);
  CGDisplayModeRelease(mode);
  return rate > 0 ? (int)rate : 60;
}

void na_screen_get_cursor_position(double* out_x, double* out_y) {
  NSPoint mouseLocation = [NSEvent mouseLocation];
  *out_x = mouseLocation.x;
  *out_y = na_point_top_left_y(mouseLocation);
}

static struct {
  na_screens_changed_fn fn;
  void* ctx;
} g_screens_changed = {NULL, NULL};

static id g_screens_observer = nil;

void na_screen_set_changed_callback(na_screens_changed_fn fn, void* ctx) {
  g_screens_changed.fn = fn;
  g_screens_changed.ctx = ctx;
  if (g_screens_observer) {
    return;
  }
  g_screens_observer = [[NSNotificationCenter defaultCenter]
      addObserverForName:NSApplicationDidChangeScreenParametersNotification
                  object:nil
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification* notification) {
                @autoreleasepool {
                  if (g_screens_changed.fn) {
                    g_screens_changed.fn(g_screens_changed.ctx);
                  }
                }
              }];
}
