#import <Cocoa/Cocoa.h>
#include <string.h>

#define NA_TRAY_EVENT_CLICKED 0
#define NA_TRAY_EVENT_RIGHT_CLICKED 1
#define NA_TRAY_EVENT_DOUBLE_CLICKED 2

typedef void (*na_tray_event_fn)(int kind, uint32_t id, void* ctx);

@class NATrayTarget;

static char g_tray_buffer[512];

static NSMutableDictionary<NSNumber*, NSStatusItem*>* g_status_items = nil;
static NSMutableDictionary<NSNumber*, NATrayTarget*>* g_tray_targets = nil;
static NSMutableDictionary<NSNumber*, NSNumber*>* g_context_menu_ids = nil;
static uint32_t g_next_tray_seq = 0;
static na_tray_event_fn g_tray_event_fn = NULL;
static void* g_tray_event_ctx = NULL;


@interface NATrayTarget : NSObject
@property(nonatomic, assign) uint32_t trayId;
- (void)handleStatusItemEvent:(id)sender;
@end

@implementation NATrayTarget
- (void)handleStatusItemEvent:(id)sender {
  NSEvent* event = [NSApp currentEvent];
  if (!event || !g_tray_event_fn) {
    return;
  }
  if (event.type == NSEventTypeRightMouseUp ||
      (event.type == NSEventTypeLeftMouseUp &&
       (event.modifierFlags & NSEventModifierFlagControl))) {
    g_tray_event_fn(NA_TRAY_EVENT_RIGHT_CLICKED, _trayId, g_tray_event_ctx);
  } else if (event.type == NSEventTypeLeftMouseUp) {
    if (event.clickCount == 2) {
      g_tray_event_fn(NA_TRAY_EVENT_DOUBLE_CLICKED, _trayId, g_tray_event_ctx);
    } else {
      g_tray_event_fn(NA_TRAY_EVENT_CLICKED, _trayId, g_tray_event_ctx);
    }
  }
}
@end

static void ensure_tray_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_status_items = [NSMutableDictionary dictionary];
    g_tray_targets = [NSMutableDictionary dictionary];
    g_context_menu_ids = [NSMutableDictionary dictionary];
  }
}

static const char* set_tray_buffer(NSString* value) {
  g_tray_buffer[0] = '\0';
  if (!value) {
    return g_tray_buffer;
  }
  const char* utf8 = value.UTF8String;
  if (utf8) {
    strncpy(g_tray_buffer, utf8, sizeof(g_tray_buffer) - 1);
    g_tray_buffer[sizeof(g_tray_buffer) - 1] = '\0';
  }
  return g_tray_buffer;
}

uint32_t na_tray_create(void) {
  ensure_tray_tables();
  NSStatusItem* item = [[NSStatusBar systemStatusBar]
      statusItemWithLength:NSVariableStatusItemLength];
  if (!item) {
    return 0;
  }
  g_next_tray_seq += 1;
  uint32_t id = (4u << 24) | g_next_tray_seq;
  g_status_items[@(id)] = item;
  return id;
}

void na_tray_free(uint32_t id) {
  ensure_tray_tables();
  NSStatusItem* item = g_status_items[@(id)];
  if (!item) {
    return;
  }
  item.menu = nil;
  [[NSStatusBar systemStatusBar] removeStatusItem:item];
  [g_status_items removeObjectForKey:@(id)];
  [g_tray_targets removeObjectForKey:@(id)];
  [g_context_menu_ids removeObjectForKey:@(id)];
}

void na_tray_setup_handlers(uint32_t id) {
  ensure_tray_tables();
  NSStatusItem* item = g_status_items[@(id)];
  if (!item || !item.button) {
    return;
  }
  if (g_tray_targets[@(id)]) {
    return;
  }
  NATrayTarget* target = [[NATrayTarget alloc] init];
  target.trayId = id;
  item.button.target = target;
  item.button.action = @selector(handleStatusItemEvent:);
  [(NSButtonCell*)item.button.cell sendActionOn:NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp];
  g_tray_targets[@(id)] = target;
}

void na_tray_teardown_handlers(uint32_t id) {
  ensure_tray_tables();
  NSStatusItem* item = g_status_items[@(id)];
  if (item && item.button) {
    item.button.target = nil;
    item.button.action = nil;
  }
  [g_tray_targets removeObjectForKey:@(id)];
}

bool na_tray_exists(uint32_t id) {
  ensure_tray_tables();
  return g_status_items[@(id)] != nil;
}

void na_tray_set_icon_path(uint32_t id, const char* utf8_path) {
  NSStatusItem* item = g_status_items[@(id)];
  if (!item || !item.button) {
    return;
  }
  if (!utf8_path) {
    item.button.image = nil;
    return;
  }
  @autoreleasepool {
    NSImage* image = [[NSImage alloc]
        initWithContentsOfFile:[NSString stringWithUTF8String:utf8_path]];
    if (image) {
      image.size = NSMakeSize(18, 18);
      image.template = YES;
      item.button.image = image;
    }
  }
}

void na_tray_set_icon_ptr(uint32_t id, void* ns_image_ptr) {
  NSStatusItem* item = g_status_items[@(id)];
  if (!item || !item.button) {
    return;
  }
  if (!ns_image_ptr) {
    item.button.image = nil;
    return;
  }
  NSImage* image = (__bridge NSImage*)ns_image_ptr;
  image.size = NSMakeSize(18, 18);
  image.template = YES;
  item.button.image = image;
}

void na_tray_clear_icon(uint32_t id) {
  NSStatusItem* item = g_status_items[@(id)];
  if (item && item.button) {
    item.button.image = nil;
  }
}

void na_tray_set_title(uint32_t id, const char* utf8_title) {
  NSStatusItem* item = g_status_items[@(id)];
  if (!item || !item.button) {
    return;
  }
  item.button.title = utf8_title ? [NSString stringWithUTF8String:utf8_title] : @"";
}

const char* na_tray_get_title(uint32_t id) {
  NSStatusItem* item = g_status_items[@(id)];
  if (!item || !item.button) {
    g_tray_buffer[0] = '\0';
    return g_tray_buffer;
  }
  return set_tray_buffer(item.button.title);
}

void na_tray_set_tooltip(uint32_t id, const char* utf8_tooltip) {
  NSStatusItem* item = g_status_items[@(id)];
  if (!item || !item.button) {
    return;
  }
  item.button.toolTip = utf8_tooltip ? [NSString stringWithUTF8String:utf8_tooltip] : nil;
}

const char* na_tray_get_tooltip(uint32_t id) {
  NSStatusItem* item = g_status_items[@(id)];
  if (!item || !item.button) {
    g_tray_buffer[0] = '\0';
    return g_tray_buffer;
  }
  NSString* tooltip = item.button.toolTip;
  if (!tooltip || tooltip.length == 0) {
    g_tray_buffer[0] = '\0';
    return g_tray_buffer;
  }
  return set_tray_buffer(tooltip);
}

void na_tray_set_context_menu(uint32_t id, uint32_t menu_id) {
  ensure_tray_tables();
  if (menu_id == 0) {
    [g_context_menu_ids removeObjectForKey:@(id)];
  } else {
    g_context_menu_ids[@(id)] = @(menu_id);
  }
}

uint32_t na_tray_get_context_menu(uint32_t id) {
  ensure_tray_tables();
  NSNumber* menuId = g_context_menu_ids[@(id)];
  return menuId ? menuId.unsignedIntValue : 0;
}

void na_tray_get_bounds(uint32_t id,
                        double* out_x,
                        double* out_y,
                        double* out_w,
                        double* out_h) {
  *out_x = 0; *out_y = 0; *out_w = 0; *out_h = 0;
  NSStatusItem* item = g_status_items[@(id)];
  if (!item || !item.button || !item.button.window) {
    return;
  }
  NSStatusBarButton* button = item.button;
  NSRect windowRect = [button convertRect:button.bounds toView:nil];
  NSRect screenRect = [button.window convertRectToScreen:windowRect];
  NSArray<NSScreen*>* screens = [NSScreen screens];
  double primaryHeight = screens.count > 0 ? screens[0].frame.size.height : 0;
  double topY = primaryHeight - screenRect.origin.y - screenRect.size.height;
  *out_x = screenRect.origin.x;
  *out_y = topY;
  *out_w = screenRect.size.width;
  *out_h = screenRect.size.height;
}

bool na_tray_set_visible(uint32_t id, bool visible) {
  NSStatusItem* item = g_status_items[@(id)];
  if (!item) {
    return false;
  }
  item.visible = visible ? YES : NO;
  return true;
}

bool na_tray_is_visible(uint32_t id) {
  NSStatusItem* item = g_status_items[@(id)];
  if (!item) {
    return false;
  }
  return item.isVisible ? true : false;
}

extern void* na_menu_native_ptr(uint32_t menu_id);

bool na_tray_open_context_menu(uint32_t id) {
  ensure_tray_tables();
  NSStatusItem* item = g_status_items[@(id)];
  NSNumber* menuIdNumber = g_context_menu_ids[@(id)];
  if (!item || !item.button || !menuIdNumber) {
    return false;
  }
  NSMenu* menu = (__bridge NSMenu*)na_menu_native_ptr(menuIdNumber.unsignedIntValue);
  if (!menu) {
    return false;
  }
  item.menu = menu;
  [item.button performClick:nil];
  return true;
}

bool na_tray_close_context_menu(uint32_t id) {
  ensure_tray_tables();
  NSNumber* menuIdNumber = g_context_menu_ids[@(id)];
  if (!menuIdNumber) {
    return true;
  }
  NSMenu* menu = (__bridge NSMenu*)na_menu_native_ptr(menuIdNumber.unsignedIntValue);
  if (!menu) {
    return true;
  }
  [menu cancelTracking];
  return true;
}

void na_tray_set_event_callback(na_tray_event_fn fn, void* ctx) {
  ensure_tray_tables();
  g_tray_event_fn = fn;
  g_tray_event_ctx = ctx;
}
