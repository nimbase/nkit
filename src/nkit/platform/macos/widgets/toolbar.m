#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "gui_common.h"

typedef void (*na_toolbar_click_fn)(uint32_t widget_id, void* ctx);

extern void* na_window_native(uint32_t window_id);

static NSMutableDictionary<NSNumber*, NSToolbar*>* g_toolbars = nil;
static NSMutableDictionary<NSNumber*, NSMutableArray<NSString*>*>* g_toolbar_items =
    nil;
static NSMutableDictionary<NSNumber*, NSNumber*>* g_item_widget_ids = nil;
static NSMutableDictionary<NSNumber*, NSString*>* g_item_labels = nil;
static NSMutableDictionary<NSNumber*, NSString*>* g_item_symbols = nil;
static na_toolbar_click_fn g_toolbar_fn = NULL;
static int64_t g_next_toolbar_handle = 1;

static void ensure_toolbar_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_toolbars = [NSMutableDictionary dictionary];
    g_toolbar_items = [NSMutableDictionary dictionary];
    g_item_widget_ids = [NSMutableDictionary dictionary];
    g_item_labels = [NSMutableDictionary dictionary];
    g_item_symbols = [NSMutableDictionary dictionary];
  }
}

static void toolbar_item_thunk(uint32_t widget_id, void* ctx) {
  if (g_toolbar_fn) {
    g_toolbar_fn(widget_id, NULL);
  }
}

@interface NAToolbarDelegate : NSObject <NSToolbarDelegate>
@property(nonatomic, assign) int64_t handle;
@end

@implementation NAToolbarDelegate

- (NSArray<NSString*>*)itemIdentifiers {
  NSMutableArray<NSString*>* ids =
      g_toolbar_items[@(self.handle)];
  return ids ? [ids copy] : @[];
}

- (NSArray<NSString*>*)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar {
  return [self itemIdentifiers];
}

- (NSArray<NSString*>*)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar {
  return [self itemIdentifiers];
}

- (NSToolbarItem*)toolbar:(NSToolbar*)toolbar
    itemForItemIdentifier:(NSString*)identifier
    willBeInsertedIntoToolbar:(BOOL)flag {
  NSNumber* widgetId = g_item_widget_ids[identifier];
  if (!widgetId) {
    return [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
  }
  NSToolbarItem* item =
      [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
  NSString* label = g_item_labels[widgetId];
  item.label = label ?: @"";
  item.paletteLabel = item.label;

  NSString* symbolName = g_item_symbols[widgetId];
  if (symbolName.length > 0) {
    if (@available(macOS 11.0, *)) {
      item.image = [NSImage imageWithSystemSymbolName:symbolName
                             accessibilityDescription:nil];
    }
  }

  NAGenericTarget* target =
      na_target_new(widgetId.unsignedIntValue, toolbar_item_thunk, NULL);
  item.target = target;
  item.action = @selector(fire:);
  objc_setAssociatedObject(item, &"na_target"[0], target,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  return item;
}

@end

int64_t na_toolbar_attach(uint32_t window_id) {
  ensure_toolbar_tables();
  NSWindow* window = (__bridge NSWindow*)na_window_native(window_id);
  if (!window) {
    return 0;
  }
  NSToolbar* toolbar =
      [[NSToolbar alloc] initWithIdentifier:@"nativeapi.toolbar"];
  NAToolbarDelegate* delegate = [[NAToolbarDelegate alloc] init];
  delegate.handle = g_next_toolbar_handle;
  toolbar.delegate = delegate;
  toolbar.displayMode = NSToolbarDisplayModeIconOnly;
  objc_setAssociatedObject(toolbar, &"na_delegate"[0], delegate,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  window.toolbar = toolbar;

  int64_t handle = g_next_toolbar_handle++;
  g_toolbars[@(handle)] = toolbar;
  g_toolbar_items[@(handle)] = [NSMutableArray array];
  return handle;
}

void na_toolbar_set_click_callback(na_toolbar_click_fn fn) {
  g_toolbar_fn = fn;
}

// Adds an item; returns its ordinal position or -1 on failure.
int na_toolbar_add_item(int64_t handle, const char* label,
                        const char* symbol_name, uint32_t widget_id) {
  ensure_toolbar_tables();
  NSMutableArray<NSString*>* ids = g_toolbar_items[@(handle)];
  NSToolbar* toolbar = g_toolbars[@(handle)];
  if (!ids || !toolbar || !label) {
    return -1;
  }
  NSString* identifier =
      [NSString stringWithFormat:@"na-item-%u", widget_id];
  [ids addObject:identifier];
  g_item_widget_ids[identifier] = @(widget_id);
  g_item_labels[@(widget_id)] = [NSString stringWithUTF8String:label];
  if (symbol_name && symbol_name[0] != 0) {
    g_item_symbols[@(widget_id)] =
        [NSString stringWithUTF8String:symbol_name];
  }
  [toolbar insertItemWithItemIdentifier:identifier atIndex:ids.count - 1];
  return (int)ids.count - 1;
}

void na_toolbar_remove_item(int64_t handle, uint32_t widget_id) {
  ensure_toolbar_tables();
  NSString* identifier =
      [NSString stringWithFormat:@"na-item-%u", widget_id];
  NSMutableArray<NSString*>* ids = g_toolbar_items[@(handle)];
  NSToolbar* toolbar = g_toolbars[@(handle)];
  if (!ids || !toolbar) {
    return;
  }
  NSUInteger idx = [ids indexOfObject:identifier];
  if (idx != NSNotFound) {
    [toolbar removeItemAtIndex:idx];
    [ids removeObjectAtIndex:idx];
    NSNumber* widNum = g_item_widget_ids[identifier];
    [g_item_widget_ids removeObjectForKey:identifier];
    [g_item_labels removeObjectForKey:widNum];
    [g_item_symbols removeObjectForKey:widNum];
  }
}

int na_toolbar_item_count(int64_t handle) {
  ensure_toolbar_tables();
  NSMutableArray<NSString*>* ids = g_toolbar_items[@(handle)];
  return ids ? (int)ids.count : 0;
}
