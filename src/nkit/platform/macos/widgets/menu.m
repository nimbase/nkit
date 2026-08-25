#import <Cocoa/Cocoa.h>
#include <string.h>
#include <ctype.h>

#define NA_MENU_EVENT_ITEM_CLICKED 0
#define NA_MENU_EVENT_MENU_OPENED 1
#define NA_MENU_EVENT_MENU_CLOSED 2

#define NA_ITEM_TYPE_NORMAL 0
#define NA_ITEM_TYPE_CHECKBOX 1
#define NA_ITEM_TYPE_RADIO 2
#define NA_ITEM_TYPE_SEPARATOR 3
#define NA_ITEM_TYPE_SUBMENU 4

typedef void (*na_menu_event_fn)(int kind, uint32_t id, void* ctx);

@class NATarget;
@class NADelegate;

static char g_menu_buffer[512];

static NSMutableDictionary<NSNumber*, NSMenu*>* g_menus = nil;
static NSMutableDictionary<NSNumber*, NSMenuItem*>* g_items = nil;
static NSMutableDictionary<NSNumber*, NATarget*>* g_item_targets = nil;
static NSMutableDictionary<NSNumber*, NADelegate*>* g_menu_delegates = nil;
static NSMutableDictionary<NSNumber*, NSNumber*>* g_radio_groups = nil;
static NSMutableDictionary<NSNumber*, NSNumber*>* g_accel_mods = nil;
static uint32_t g_next_menu_seq = 0;
static uint32_t g_next_item_seq = 0;
static na_menu_event_fn g_menu_event_fn = NULL;
static void* g_menu_event_ctx = NULL;

static void ensure_menu_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_menus = [NSMutableDictionary dictionary];
    g_items = [NSMutableDictionary dictionary];
    g_item_targets = [NSMutableDictionary dictionary];
    g_menu_delegates = [NSMutableDictionary dictionary];
    g_radio_groups = [NSMutableDictionary dictionary];
    g_accel_mods = [NSMutableDictionary dictionary];
  }
}

@interface NATarget : NSObject
@property(nonatomic, assign) uint32_t itemId;
@property(nonatomic, assign) int itemType;
- (void)handleClick:(id)sender;
@end

@implementation NATarget
- (void)handleClick:(id)sender {
  @try {
    NSMenuItem* item = (NSMenuItem*)sender;
    if (!item || !item.isEnabled) {
      return;
    }
    if (g_menu_event_fn) {
      g_menu_event_fn(NA_MENU_EVENT_ITEM_CLICKED, _itemId, g_menu_event_ctx);
    }
  } @catch (NSException* exception) {
    NSLog(@"nativeapi menu click exception: %@", exception.reason);
  }
}
@end

@interface NADelegate : NSObject <NSMenuDelegate>
@property(nonatomic, assign) uint32_t menuId;
@end

@implementation NADelegate
- (void)menuWillOpen:(NSMenu*)menu {
  if (g_menu_event_fn) {
    g_menu_event_fn(NA_MENU_EVENT_MENU_OPENED, _menuId, g_menu_event_ctx);
  }
}

- (BOOL)menu:(NSMenu*)menu validateMenuItem:(NSMenuItem*)item {
  return item.isEnabled;
}

- (void)menuDidClose:(NSMenu*)menu {
  if (g_menu_event_fn) {
    g_menu_event_fn(NA_MENU_EVENT_MENU_CLOSED, _menuId, g_menu_event_ctx);
  }
}
@end

static const char* set_menu_buffer(NSString* value) {
  g_menu_buffer[0] = '\0';
  if (!value) {
    return g_menu_buffer;
  }
  const char* utf8 = value.UTF8String;
  if (utf8) {
    strncpy(g_menu_buffer, utf8, sizeof(g_menu_buffer) - 1);
    g_menu_buffer[sizeof(g_menu_buffer) - 1] = '\0';
  }
  return g_menu_buffer;
}

uint32_t na_menu_create(void) {
  ensure_menu_tables();
  g_next_menu_seq += 1;
  uint32_t id = (2u << 24) | g_next_menu_seq;
  NSMenu* menu = [[NSMenu alloc] init];
  menu.autoenablesItems = NO;
  NADelegate* delegate = [[NADelegate alloc] init];
  delegate.menuId = id;
  menu.delegate = delegate;
  g_menus[@(id)] = menu;
  g_menu_delegates[@(id)] = delegate;
  return id;
}

void na_menu_free(uint32_t id) {
  ensure_menu_tables();
  NSMenu* menu = g_menus[@(id)];
  if (menu) {
    menu.delegate = nil;
  }
  [g_menus removeObjectForKey:@(id)];
  [g_menu_delegates removeObjectForKey:@(id)];
}

void* na_menu_native_ptr(uint32_t id) {
  ensure_menu_tables();
  return (__bridge void*)g_menus[@(id)];
}

uint32_t na_menu_id_for_native(void* native_menu) {
  ensure_menu_tables();
  if (!native_menu) {
    return 0;
  }
  NSMenu* menu = (__bridge NSMenu*)native_menu;
  for (NSNumber* key in g_menus) {
    if (g_menus[key] == menu) {
      return key.unsignedIntValue;
    }
  }
  return 0;
}

uint32_t na_menu_item_create(const char* utf8_label, int type) {
  ensure_menu_tables();
  g_next_item_seq += 1;
  uint32_t id = (3u << 24) | g_next_item_seq;
  NSMenuItem* item = nil;
  NSString* label = [NSString stringWithUTF8String:utf8_label ? utf8_label : ""];
  if (type == NA_ITEM_TYPE_SEPARATOR) {
    item = [NSMenuItem separatorItem];
  } else {
    item = [[NSMenuItem alloc] initWithTitle:label action:nil keyEquivalent:@""];
  }
  NATarget* target = [[NATarget alloc] init];
  target.itemId = id;
  target.itemType = type;
  if (type != NA_ITEM_TYPE_SEPARATOR) {
    item.target = target;
    item.action = @selector(handleClick:);
  }
  g_items[@(id)] = item;
  g_item_targets[@(id)] = target;
  return id;
}

void na_menu_item_free(uint32_t id) {
  ensure_menu_tables();
  NSMenuItem* item = g_items[@(id)];
  if (item) {
    item.target = nil;
    item.action = nil;
  }
  [g_items removeObjectForKey:@(id)];
  [g_item_targets removeObjectForKey:@(id)];
  [g_radio_groups removeObjectForKey:@(id)];
  [g_accel_mods removeObjectForKey:@(id)];
}

void na_menu_add_item(uint32_t menu_id, uint32_t item_id) {
  NSMenu* menu = g_menus[@(menu_id)];
  NSMenuItem* item = g_items[@(item_id)];
  if (!menu || !item) {
    return;
  }
  [menu addItem:item];
}

void na_menu_insert_item(uint32_t menu_id, uint32_t item_id, int index) {
  NSMenu* menu = g_menus[@(menu_id)];
  NSMenuItem* item = g_items[@(item_id)];
  if (!menu || !item) {
    return;
  }
  [menu insertItem:item atIndex:index];
}

bool na_menu_remove_item(uint32_t menu_id, uint32_t item_id) {
  NSMenu* menu = g_menus[@(menu_id)];
  NSMenuItem* item = g_items[@(item_id)];
  if (!menu || !item) {
    return false;
  }
  [menu removeItem:item];
  return true;
}

void na_menu_clear(uint32_t menu_id) {
  NSMenu* menu = g_menus[@(menu_id)];
  if (!menu) {
    return;
  }
  [menu removeAllItems];
}

void na_menu_item_set_label(uint32_t id, const char* utf8_label) {
  NSMenuItem* item = g_items[@(id)];
  if (!item) {
    return;
  }
  item.title = [NSString stringWithUTF8String:utf8_label ? utf8_label : ""];
}

const char* na_menu_item_get_title(uint32_t id) {
  NSMenuItem* item = g_items[@(id)];
  if (!item) {
    g_menu_buffer[0] = '\0';
    return g_menu_buffer;
  }
  return set_menu_buffer(item.title);
}

void na_menu_item_set_icon_ptr(uint32_t id, void* ns_image_ptr) {
  NSMenuItem* item = g_items[@(id)];
  if (!item) {
    return;
  }
  if (!ns_image_ptr) {
    item.image = nil;
    return;
  }
  NSImage* image = (__bridge NSImage*)ns_image_ptr;
  image.size = NSMakeSize(16, 16);
  image.template = YES;
  item.image = image;
}

void na_menu_item_set_tooltip(uint32_t id, const char* utf8_tooltip) {
  NSMenuItem* item = g_items[@(id)];
  if (!item) {
    return;
  }
  item.toolTip = utf8_tooltip ? [NSString stringWithUTF8String:utf8_tooltip] : nil;
}

void na_menu_item_set_enabled(uint32_t id, bool enabled) {
  NSMenuItem* item = g_items[@(id)];
  if (!item) {
    return;
  }
  item.enabled = enabled ? YES : NO;
}

bool na_menu_item_is_enabled(uint32_t id) {
  NSMenuItem* item = g_items[@(id)];
  if (!item) {
    return false;
  }
  return item.isEnabled ? true : false;
}

void na_menu_item_set_state(uint32_t id, int state) {
  NSMenuItem* item = g_items[@(id)];
  if (!item) {
    return;
  }
  NATarget* target = g_item_targets[@(id)];
  int type = target ? target.itemType : NA_ITEM_TYPE_NORMAL;
  if (type == NA_ITEM_TYPE_CHECKBOX || type == NA_ITEM_TYPE_RADIO) {
    NSControlStateValue nsState =
        (state == 1) ? NSControlStateValueOn
                     : ((state == 2) ? NSControlStateValueMixed : NSControlStateValueOff);
    if (type == NA_ITEM_TYPE_RADIO && state == 2) {
      return;
    }
    item.state = nsState;
    NSNumber* group = g_radio_groups[@(id)];
    if (type == NA_ITEM_TYPE_RADIO && state == 1 && group && group.intValue >= 0) {
      NSMenu* parent = item.menu;
      if (parent) {
        for (NSMenuItem* sibling in parent.itemArray) {
          if (sibling == item) {
            continue;
          }
          NATarget* siblingTarget = sibling.target;
          if ([siblingTarget isKindOfClass:[NATarget class]] &&
              ((NATarget*)siblingTarget).itemType == NA_ITEM_TYPE_RADIO) {
            sibling.state = NSControlStateValueOff;
          }
        }
      }
    }
  }
}

void na_menu_item_set_radio_group(uint32_t id, int group) {
  ensure_menu_tables();
  g_radio_groups[@(id)] = @(group);
}

int na_menu_item_get_radio_group(uint32_t id) {
  ensure_menu_tables();
  NSNumber* group = g_radio_groups[@(id)];
  return group ? group.intValue : -1;
}

static void apply_accelerator(NSMenuItem* item, const char* utf8_key, unsigned int modifiers) {
  NSString* keyEquivalent = @"";
  NSUInteger mask = 0;
  NSString* key = [NSString stringWithUTF8String:utf8_key ? utf8_key : ""];
  if (key.length == 1) {
    unichar c = (unichar)tolower([key characterAtIndex:0]);
    keyEquivalent = [NSString stringWithFormat:@"%C", c];
  } else if (key.length > 1) {
    NSDictionary* specials = @{
      @"F1": @(NSF1FunctionKey),
      @"F2": @(NSF2FunctionKey),
      @"F3": @(NSF3FunctionKey),
      @"F4": @(NSF4FunctionKey),
      @"F5": @(NSF5FunctionKey),
      @"F6": @(NSF6FunctionKey),
      @"F7": @(NSF7FunctionKey),
      @"F8": @(NSF8FunctionKey),
      @"F9": @(NSF9FunctionKey),
      @"F10": @(NSF10FunctionKey),
      @"F11": @(NSF11FunctionKey),
      @"F12": @(NSF12FunctionKey),
      @"Enter": @"\r",
      @"Return": @"\r",
      @"Tab": @"\t",
      @"Space": @" ",
      @"Escape": @(0x1B),
      @"Delete": @"\b",
      @"Backspace": @"\b",
      @"ArrowUp": @(NSUpArrowFunctionKey),
      @"ArrowDown": @(NSDownArrowFunctionKey),
      @"ArrowLeft": @(NSLeftArrowFunctionKey),
      @"ArrowRight": @(NSRightArrowFunctionKey)
    };
    NSNumber* special = specials[key];
    if (special) {
      if ([key isEqualToString:@"Enter"] || [key isEqualToString:@"Return"] ||
          [key isEqualToString:@"Tab"] || [key isEqualToString:@"Space"] ||
          [key isEqualToString:@"Delete"] || [key isEqualToString:@"Backspace"]) {
        keyEquivalent = special;
      } else {
        keyEquivalent = [NSString stringWithFormat:@"%C", (unichar)special.intValue];
      }
    }
  }
  if (modifiers & 2u) mask |= NSEventModifierFlagControl;
  if (modifiers & 4u) mask |= NSEventModifierFlagOption;
  if (modifiers & 1u) mask |= NSEventModifierFlagShift;
  if (modifiers & 8u) mask |= NSEventModifierFlagCommand;
  item.keyEquivalent = keyEquivalent;
  item.keyEquivalentModifierMask = mask;
}

void na_menu_item_set_accelerator(uint32_t id, const char* utf8_key, unsigned int modifiers) {
  NSMenuItem* item = g_items[@(id)];
  if (!item) {
    return;
  }
  ensure_menu_tables();
  g_accel_mods[@(id)] = @(modifiers);
  apply_accelerator(item, utf8_key, modifiers);
}

unsigned int na_menu_item_get_accelerator_modifiers(uint32_t id) {
  ensure_menu_tables();
  NSNumber* mods = g_accel_mods[@(id)];
  return mods ? mods.unsignedIntValue : 0;
}

void na_menu_item_set_submenu(uint32_t item_id, uint32_t submenu_menu_id) {  NSMenuItem* item = g_items[@(item_id)];
  if (!item) {
    return;
  }
  if (submenu_menu_id == 0) {
    item.submenu = nil;
  } else {
    NSMenu* submenu = g_menus[@(submenu_menu_id)];
    if (submenu) {
      item.submenu = submenu;
    }
  }
}

static double primary_screen_height(void) {
  NSArray<NSScreen*>* screens = [NSScreen screens];
  if (screens.count == 0) {
    return 0;
  }
  return screens[0].frame.size.height;
}

void na_menu_popup(uint32_t menu_id, double x, double y_top_left, int placement) {
  NSMenu* menu = g_menus[@(menu_id)];
  if (!menu) {
    return;
  }
  NSSize size = menu.size;
  double width = size.width;
  double height = size.height;
  switch (placement) {
    case 0: x -= width / 2.0; y_top_left -= height; break;
    case 1: y_top_left -= height; break;
    case 2: x -= width; y_top_left -= height; break;
    case 3: y_top_left -= height / 2.0; break;
    case 4: break;
    case 5: y_top_left -= height; break;
    case 6: x -= width / 2.0; break;
    case 7: break;
    case 8: x -= width; break;
    case 9: x -= width; y_top_left -= height / 2.0; break;
    case 10: x -= width; break;
    case 11: x -= width; y_top_left -= height; break;
    default: break;
  }
  double bottom_y = primary_screen_height() - y_top_left;
  NSPoint location = NSMakePoint(x, bottom_y);
  dispatch_async(dispatch_get_main_queue(), ^{
    @autoreleasepool {
      [menu popUpMenuPositioningItem:nil atLocation:location inView:nil];
    }
  });
}

void na_menu_cancel_tracking(uint32_t menu_id) {
  NSMenu* menu = g_menus[@(menu_id)];
  if (!menu) {
    return;
  }
  [menu cancelTracking];
}

void na_menu_set_event_callback(na_menu_event_fn fn, void* ctx) {
  ensure_menu_tables();
  g_menu_event_fn = fn;
  g_menu_event_ctx = ctx;
}
