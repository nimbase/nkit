#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#include <string.h>
#include <stdbool.h>
#import "gui_common.h"

typedef void (*na_toolbar_click_fn)(uint32_t widget_id, void* ctx);
typedef void (*na_toolbar_search_fn)(uint32_t widget_id, bool submitted,
                                     const char* text);

extern void* na_window_native(uint32_t window_id);

#define NA_TOOLBAR_KIND_BUTTON 0
#define NA_TOOLBAR_KIND_SEPARATOR 1
#define NA_TOOLBAR_KIND_SPACE 2
#define NA_TOOLBAR_KIND_SEARCH 3

static NSMutableDictionary<NSNumber*, NSToolbar*>* g_toolbars = nil;
static NSMutableDictionary<NSNumber*, NSMutableArray<NSString*>*>* g_toolbar_items =
    nil;
// Parallel to g_toolbar_items: the Nim widget id behind each entry, so
// separators/spaces (which share AppKit's standard identifiers) stay
// removable and addressable by ordinal.
static NSMutableDictionary<NSNumber*, NSMutableArray<NSNumber*>*>* g_toolbar_wids =
    nil;
static NSMutableDictionary<NSNumber*, NSNumber*>* g_item_widget_ids = nil;
static NSMutableDictionary<NSNumber*, NSString*>* g_item_labels = nil;
static NSMutableDictionary<NSNumber*, NSString*>* g_item_symbols = nil;
static NSMutableDictionary<NSNumber*, NSNumber*>* g_item_kinds = nil;
static NSMutableDictionary<NSNumber*, NSString*>* g_item_tooltips = nil;
static NSMutableDictionary<NSNumber*, NSNumber*>* g_item_enabled = nil;
static NSMutableDictionary<NSString*, NSSearchField*>* g_search_fields = nil;
static NSMutableDictionary<NSNumber*, NSString*>* g_search_placeholders = nil;
static char g_toolbar_search_buffer[2048];
static na_toolbar_click_fn g_toolbar_fn = NULL;
static na_toolbar_search_fn g_toolbar_search_fn = NULL;
static int64_t g_next_toolbar_handle = 1;

static void ensure_toolbar_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_toolbars = [NSMutableDictionary dictionary];
    g_toolbar_items = [NSMutableDictionary dictionary];
    g_toolbar_wids = [NSMutableDictionary dictionary];
    g_item_widget_ids = [NSMutableDictionary dictionary];
    g_item_labels = [NSMutableDictionary dictionary];
    g_item_symbols = [NSMutableDictionary dictionary];
    g_item_kinds = [NSMutableDictionary dictionary];
    g_item_tooltips = [NSMutableDictionary dictionary];
    g_item_enabled = [NSMutableDictionary dictionary];
    g_search_fields = [NSMutableDictionary dictionary];
    g_search_placeholders = [NSMutableDictionary dictionary];
  }
}

static NSString* toolbar_identifier_for(uint32_t widget_id) {
  return [NSString stringWithFormat:@"na-item-%u", widget_id];
}

static void toolbar_item_thunk(uint32_t widget_id, void* ctx) {
  if (g_toolbar_fn) {
    g_toolbar_fn(widget_id, NULL);
  }
}

static void toolbar_search_submit_thunk(uint32_t widget_id, void* ctx) {
  if (!g_toolbar_search_fn) {
    return;
  }
  ensure_toolbar_tables();
  NSString* ident = toolbar_identifier_for(widget_id);
  NSSearchField* field = g_search_fields[ident];
  g_toolbar_search_fn(widget_id, true,
                      field ? field.stringValue.UTF8String : "");
}

@interface NASearchDelegate : NSObject <NSSearchFieldDelegate>
@property(nonatomic, assign) uint32_t widgetId;
@end

@implementation NASearchDelegate
- (void)controlTextDidChange:(NSNotification*)note {
  if (!g_toolbar_search_fn) {
    return;
  }
  NSSearchField* field = (NSSearchField*)note.object;
  g_toolbar_search_fn(_widgetId, false,
                      field ? field.stringValue.UTF8String : "");
}
@end

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
  // Standard slots keep their AppKit identifiers. Note
  // NSToolbarSeparatorItemIdentifier is deprecated and ignored since
  // macOS 11; fixed gaps use NSToolbarSpaceItemIdentifier.
  if ([identifier isEqualToString:NSToolbarSpaceItemIdentifier]) {
    return [[NSToolbarItem alloc]
        initWithItemIdentifier:NSToolbarSpaceItemIdentifier];
  }
  if ([identifier isEqualToString:NSToolbarFlexibleSpaceItemIdentifier]) {
    return [[NSToolbarItem alloc]
        initWithItemIdentifier:NSToolbarFlexibleSpaceItemIdentifier];
  }
  NSNumber* widgetId = g_item_widget_ids[identifier];
  if (!widgetId) {
    return [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
  }
  int kind = [g_item_kinds[identifier] intValue];
  if (kind == NA_TOOLBAR_KIND_SEARCH) {
    NSToolbarItem* item =
        [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
    NSString* label = g_item_labels[widgetId];
    item.label = label ?: @"Search";
    item.paletteLabel = item.label;
    NSSearchField* field = g_search_fields[identifier];
    if (!field) {
      field = [[NSSearchField alloc] init];
      NSString* ph = g_search_placeholders[widgetId];
      field.placeholderString = ph ?: @"";
      field.delegate = nil;
      g_search_fields[identifier] = field;
    }
    NSString* tip = g_item_tooltips[widgetId];
    if (tip) {
      field.toolTip = tip;
    }
    NASearchDelegate* delegate = [[NASearchDelegate alloc] init];
    delegate.widgetId = widgetId.unsignedIntValue;
    field.delegate = delegate;
    objc_setAssociatedObject(field, &"na_search_delegate"[0], delegate,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NAGenericTarget* target = na_target_new(widgetId.unsignedIntValue,
                                            toolbar_search_submit_thunk, NULL);
    field.target = target;
    field.action = @selector(fire:);
    objc_setAssociatedObject(field, &"na_target"[0], target,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    item.view = field;
    item.minSize = NSMakeSize(120, 28);
    item.maxSize = NSMakeSize(400, 28);
    return item;
  }
  NSToolbarItem* item =
      [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
  NSString* label = g_item_labels[widgetId];
  item.label = label ?: @"";
  item.paletteLabel = item.label;
  NSString* tip = g_item_tooltips[widgetId];
  if (tip) {
    item.toolTip = tip;
  }
  NSNumber* enabled = g_item_enabled[widgetId];
  item.enabled = (!enabled || enabled.boolValue) ? YES : NO;

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

- (NSArray<NSString*>*)toolbarSelectableItemIdentifiers:(NSToolbar*)toolbar {
  NSMutableArray<NSString*>* ids = g_toolbar_items[@(self.handle)];
  NSMutableArray<NSString*>* selectable = [NSMutableArray array];
  for (NSString* ident in ids) {
    if (g_item_widget_ids[ident] &&
        [g_item_kinds[ident] intValue] == NA_TOOLBAR_KIND_BUTTON) {
      [selectable addObject:ident];
    }
  }
  return selectable;
}

- (BOOL)validateToolbarItem:(NSToolbarItem*)item {
  NSNumber* widgetId = g_item_widget_ids[item.itemIdentifier];
  if (widgetId) {
    NSNumber* enabled = g_item_enabled[widgetId];
    if (enabled && !enabled.boolValue) {
      return NO;
    }
  }
  return YES;
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
  g_toolbar_wids[@(handle)] = [NSMutableArray array];
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
  NSMutableArray<NSNumber*>* wids = g_toolbar_wids[@(handle)];
  NSToolbar* toolbar = g_toolbars[@(handle)];
  if (!ids || !wids || !toolbar || !label) {
    return -1;
  }
  NSString* identifier = toolbar_identifier_for(widget_id);
  [ids addObject:identifier];
  [wids addObject:@(widget_id)];
  g_item_widget_ids[identifier] = @(widget_id);
  g_item_kinds[identifier] = @(NA_TOOLBAR_KIND_BUTTON);
  g_item_enabled[@(widget_id)] = @(YES);
  g_item_labels[@(widget_id)] = [NSString stringWithUTF8String:label];
  if (symbol_name && symbol_name[0] != 0) {
    g_item_symbols[@(widget_id)] =
        [NSString stringWithUTF8String:symbol_name];
  }
  [toolbar insertItemWithItemIdentifier:identifier atIndex:ids.count - 1];
  return (int)ids.count - 1;
}

int na_toolbar_add_space(int64_t handle, bool flexible, uint32_t widget_id) {
  ensure_toolbar_tables();
  NSMutableArray<NSString*>* ids = g_toolbar_items[@(handle)];
  NSMutableArray<NSNumber*>* wids = g_toolbar_wids[@(handle)];
  NSToolbar* toolbar = g_toolbars[@(handle)];
  if (!ids || !wids || !toolbar) {
    return -1;
  }
  NSString* identifier = flexible ? NSToolbarFlexibleSpaceItemIdentifier
                                  : NSToolbarSpaceItemIdentifier;
  [ids addObject:identifier];
  [wids addObject:@(widget_id)];
  [toolbar insertItemWithItemIdentifier:identifier atIndex:ids.count - 1];
  return (int)ids.count - 1;
}

int na_toolbar_add_search(int64_t handle, const char* placeholder,
                          uint32_t widget_id) {
  ensure_toolbar_tables();
  NSMutableArray<NSString*>* ids = g_toolbar_items[@(handle)];
  NSMutableArray<NSNumber*>* wids = g_toolbar_wids[@(handle)];
  NSToolbar* toolbar = g_toolbars[@(handle)];
  if (!ids || !wids || !toolbar) {
    return -1;
  }
  NSString* identifier = toolbar_identifier_for(widget_id);
  [ids addObject:identifier];
  [wids addObject:@(widget_id)];
  g_item_widget_ids[identifier] = @(widget_id);
  g_item_kinds[identifier] = @(NA_TOOLBAR_KIND_SEARCH);
  g_item_labels[@(widget_id)] = @"Search";
  g_search_placeholders[@(widget_id)] =
      (placeholder && placeholder[0] != 0)
          ? [NSString stringWithUTF8String:placeholder]
          : @"";
  [toolbar insertItemWithItemIdentifier:identifier atIndex:ids.count - 1];
  return (int)ids.count - 1;
}

void na_toolbar_remove_item(int64_t handle, uint32_t widget_id) {
  ensure_toolbar_tables();
  NSMutableArray<NSString*>* ids = g_toolbar_items[@(handle)];
  NSMutableArray<NSNumber*>* wids = g_toolbar_wids[@(handle)];
  NSToolbar* toolbar = g_toolbars[@(handle)];
  if (!ids || !wids || !toolbar) {
    return;
  }
  NSUInteger idx = [wids indexOfObject:@(widget_id)];
  if (idx != NSNotFound) {
    NSString* identifier = ids[idx];
    [toolbar removeItemAtIndex:idx];
    [ids removeObjectAtIndex:idx];
    [wids removeObjectAtIndex:idx];
    NSNumber* widNum = g_item_widget_ids[identifier];
    if (widNum) {
      [g_item_labels removeObjectForKey:widNum];
      [g_item_symbols removeObjectForKey:widNum];
      [g_item_tooltips removeObjectForKey:widNum];
      [g_item_enabled removeObjectForKey:widNum];
      [g_search_placeholders removeObjectForKey:widNum];
    }
    [g_item_widget_ids removeObjectForKey:identifier];
    [g_item_kinds removeObjectForKey:identifier];
    [g_search_fields removeObjectForKey:identifier];
  }
}

int na_toolbar_item_count(int64_t handle) {
  ensure_toolbar_tables();
  NSMutableArray<NSString*>* ids = g_toolbar_items[@(handle)];
  return ids ? (int)ids.count : 0;
}

static NSToolbarItem* toolbar_visible_item(int64_t handle,
                                           uint32_t widget_id) {
  NSToolbar* toolbar = g_toolbars[@(handle)];
  NSMutableArray<NSNumber*>* wids = g_toolbar_wids[@(handle)];
  if (!toolbar || !wids) {
    return nil;
  }
  // Ordinal order tracks toolbar.items order (append-only, pre-customize).
  NSUInteger idx = [wids indexOfObject:@(widget_id)];
  if (idx != NSNotFound && idx < toolbar.items.count) {
    return toolbar.items[idx];
  }
  return nil;
}

void na_toolbar_set_item_tooltip(int64_t handle, uint32_t widget_id,
                                 const char* tooltip) {
  ensure_toolbar_tables();
  NSNumber* widNum = @(widget_id);
  if (!tooltip || tooltip[0] == '\0') {
    [g_item_tooltips removeObjectForKey:widNum];
  } else {
    g_item_tooltips[widNum] = [NSString stringWithUTF8String:tooltip];
  }
  NSToolbarItem* item = toolbar_visible_item(handle, widget_id);
  if (item) {
    item.toolTip = (tooltip && tooltip[0] != '\0')
        ? [NSString stringWithUTF8String:tooltip]
        : nil;
  }
  NSString* identifier = toolbar_identifier_for(widget_id);
  NSSearchField* field = g_search_fields[identifier];
  if (field) {
    field.toolTip = (tooltip && tooltip[0] != '\0')
        ? [NSString stringWithUTF8String:tooltip]
        : nil;
  }
}

void na_toolbar_set_item_enabled(int64_t handle, uint32_t widget_id,
                                 bool enabled) {
  ensure_toolbar_tables();
  g_item_enabled[@(widget_id)] = @(enabled ? YES : NO);
  NSToolbarItem* item = toolbar_visible_item(handle, widget_id);
  if (item) {
    item.enabled = enabled ? YES : NO;
  }
}

bool na_toolbar_is_item_enabled(int64_t handle, uint32_t widget_id) {
  ensure_toolbar_tables();
  NSNumber* enabled = g_item_enabled[@(widget_id)];
  return !enabled || enabled.boolValue ? true : false;
}

void na_toolbar_set_display_mode(int64_t handle, int mode) {
  ensure_toolbar_tables();
  NSToolbar* toolbar = g_toolbars[@(handle)];
  if (toolbar) {
    // 0 iconOnly, 1 iconAndLabel, 2 labelOnly.
    toolbar.displayMode = (NSToolbarDisplayMode)mode;
  }
}

void na_toolbar_set_size_mode(int64_t handle, bool small) {
  ensure_toolbar_tables();
  NSToolbar* toolbar = g_toolbars[@(handle)];
  if (toolbar) {
    toolbar.sizeMode = small ? NSToolbarSizeModeSmall
                             : NSToolbarSizeModeRegular;
  }
}

void na_toolbar_set_allows_customization(int64_t handle, bool allowed) {
  ensure_toolbar_tables();
  NSToolbar* toolbar = g_toolbars[@(handle)];
  if (toolbar) {
    toolbar.allowsUserCustomization = allowed ? YES : NO;
  }
}

void na_toolbar_set_shows_baseline_separator(int64_t handle, bool show) {
  ensure_toolbar_tables();
  NSToolbar* toolbar = g_toolbars[@(handle)];
  if (toolbar) {
    toolbar.showsBaselineSeparator = show ? YES : NO;
  }
}

void na_toolbar_set_selected_item(int64_t handle, uint32_t widget_id) {
  ensure_toolbar_tables();
  NSToolbar* toolbar = g_toolbars[@(handle)];
  if (!toolbar) {
    return;
  }
  if (widget_id == 0) {
    toolbar.selectedItemIdentifier = nil;
  } else {
    toolbar.selectedItemIdentifier = toolbar_identifier_for(widget_id);
  }
}

const char* na_toolbar_get_search_text(int64_t handle, uint32_t widget_id) {
  ensure_toolbar_tables();
  g_toolbar_search_buffer[0] = '\0';
  NSString* identifier = toolbar_identifier_for(widget_id);
  NSSearchField* field = g_search_fields[identifier];
  (void)handle;
  if (field) {
    const char* utf8 = field.stringValue.UTF8String;
    if (utf8) {
      strncpy(g_toolbar_search_buffer, utf8,
              sizeof(g_toolbar_search_buffer) - 1);
      g_toolbar_search_buffer[sizeof(g_toolbar_search_buffer) - 1] = '\0';
    }
  }
  return g_toolbar_search_buffer;
}

void na_toolbar_set_search_callback(na_toolbar_search_fn fn) {
  g_toolbar_search_fn = fn;
}

void na_toolbar_fire_search(uint32_t widget_id, bool submitted,
                            const char* text) {
  if (g_toolbar_search_fn) {
    g_toolbar_search_fn(widget_id, submitted, text ? text : "");
  }
}
