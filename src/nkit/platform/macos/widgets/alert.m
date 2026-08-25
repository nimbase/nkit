#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "gui_common.h"
#include <stdlib.h>

typedef void (*na_alert_click_fn)(int64_t handle, uint32_t widget_id,
                                  void* ctx);

static NSMutableDictionary<NSNumber*, NSAlert*>* g_v2_alerts = nil;
static NSMutableDictionary<NSNumber*, NSNumber*>* g_v2_styles = nil;
static NSMutableDictionary<NSNumber*, NSMutableArray<NSNumber*>*>* g_v2_button_ids =
    nil;
static NSMutableDictionary<NSNumber*, NSTextField*>* g_v2_inputs = nil;
static na_alert_click_fn g_alert_click_fn = NULL;
static int64_t g_next_alert_handle = 1;

static const char kTargetAssociationKey;

static void ensure_alert_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_v2_alerts = [NSMutableDictionary dictionary];
    g_v2_styles = [NSMutableDictionary dictionary];
    g_v2_button_ids = [NSMutableDictionary dictionary];
    g_v2_inputs = [NSMutableDictionary dictionary];
  }
}

static void alert_button_thunk(uint32_t widget_id, void* ctx) {
  if (g_alert_click_fn) {
    g_alert_click_fn((int64_t)(intptr_t)ctx, widget_id, NULL);
  }
}

int64_t na_alert_create(const char* title, const char* message, int style) {
  ensure_alert_tables();
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText =
      [NSString stringWithUTF8String:title ? title : ""];
  alert.informativeText =
      [NSString stringWithUTF8String:message ? message : ""];
  switch (style) {
    case 1: alert.alertStyle = NSAlertStyleWarning; break;
    case 2: alert.alertStyle = NSAlertStyleCritical; break;
    default: alert.alertStyle = NSAlertStyleInformational; break;
  }
  int64_t handle = g_next_alert_handle++;
  g_v2_alerts[@(handle)] = alert;
  g_v2_styles[@(handle)] = @(style);
  g_v2_button_ids[@(handle)] = [NSMutableArray array];
  return handle;
}

void na_alert_destroy(int64_t handle) {
  ensure_alert_tables();
  [g_v2_alerts removeObjectForKey:@(handle)];
  [g_v2_styles removeObjectForKey:@(handle)];
  [g_v2_button_ids removeObjectForKey:@(handle)];
  [g_v2_inputs removeObjectForKey:@(handle)];
}

void na_alert_set_click_callback(na_alert_click_fn fn) {
  g_alert_click_fn = fn;
}

void na_alert_add_button(int64_t handle, const char* label,
                         bool is_default, uint32_t widget_id) {
  NSAlert* alert = g_v2_alerts[@(handle)];
  if (!alert || !label) {
    return;
  }
  NSButton* button =
      [alert addButtonWithTitle:[NSString stringWithUTF8String:label]];
  NAGenericTarget* target =
      na_target_new(widget_id, alert_button_thunk,
                    (void*)(intptr_t)handle);
  button.target = target;
  button.action = @selector(fire:);
  objc_setAssociatedObject(button, &kTargetAssociationKey, target,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  [g_v2_button_ids[@(handle)] addObject:@(widget_id)];
  if (is_default) {
    alert.window.defaultButtonCell = button.cell;
  }
}

int na_alert_button_count(int64_t handle) {
  NSMutableArray* ids = g_v2_button_ids[@(handle)];
  return ids ? (int)ids.count : 0;
}

void na_alert_set_shows_input(int64_t handle, bool shows) {
  NSAlert* alert = g_v2_alerts[@(handle)];
  if (!alert) {
    return;
  }
  if (shows && g_v2_inputs[@(handle)] == nil) {
    NSTextField* input =
        [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 220, 24)];
    g_v2_inputs[@(handle)] = input;
    alert.accessoryView = input;
  } else if (!shows && g_v2_inputs[@(handle)] != nil) {
    alert.accessoryView = nil;
    [g_v2_inputs removeObjectForKey:@(handle)];
  }
}

void na_alert_set_input_text(int64_t handle, const char* text) {
  NSTextField* input = g_v2_inputs[@(handle)];
  if (input && text) {
    input.stringValue = [NSString stringWithUTF8String:text];
  }
}

void na_alert_set_accessory_view(int64_t handle, void* view_ptr) {
  NSAlert* alert = g_v2_alerts[@(handle)];
  NSView* view = (__bridge NSView*)view_ptr;
  if (alert && view) {
    alert.accessoryView = view;
  }
}

// Runs the panel modally; returns the ordinal of the clicked button
// (registration order, 0-based), or -1 when unavailable.
int na_alert_run_modal(int64_t handle) {
  NSAlert* alert = g_v2_alerts[@(handle)];
  if (!alert) {
    return -1;
  }
  NSInteger code = [alert runModal];
  int ordinal = (int)(code - NSAlertFirstButtonReturn);
  NSMutableArray* ids = g_v2_button_ids[@(handle)];
  if (ordinal < 0 || (ids && ordinal >= (int)ids.count)) {
    return -1;
  }
  return ordinal;
}

void na_alert_stop_modal(int64_t handle) {
  [NSApp abortModal];
}
