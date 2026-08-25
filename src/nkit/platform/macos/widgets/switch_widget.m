#import <Cocoa/Cocoa.h>
#import "gui_common.h"

typedef void (*na_switch_event_fn)(uint32_t widget_id, void* ctx);

static na_switch_event_fn g_switch_fn = NULL;
static void* g_switch_ctx = NULL;

static NSMutableDictionary<NSNumber*, NAGenericTarget*>* g_switch_targets = nil;

static void ensure_switch_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_switch_targets = [NSMutableDictionary dictionary];
  }
}

static void switch_action_thunk(uint32_t widget_id, void* ctx) {
  if (g_switch_fn) {
    g_switch_fn(widget_id, g_switch_ctx);
  }
}

void na_switch_set_event_callback(na_switch_event_fn fn, void* ctx) {
  g_switch_fn = fn;
  g_switch_ctx = ctx;
}

void* na_switch_create(uint32_t widget_id) {
  ensure_switch_tables();
  NSSwitch* sw = [[NSSwitch alloc] initWithFrame:NSMakeRect(0, 0, 40, 20)];
  NAGenericTarget* target = na_target_new(widget_id, switch_action_thunk, NULL);
  g_switch_targets[@(widget_id)] = target;
  na_target_attach(sw, target);
  na_gui_register_view(sw);
  return (__bridge void*)sw;
}

void na_switch_free(uint32_t widget_id, void* ptr) {
  ensure_switch_tables();
  NSSwitch* sw = (__bridge NSSwitch*)ptr;
  if (sw) {
    [sw removeFromSuperview];
    na_gui_unregister_view(sw);
  }
  [g_switch_targets removeObjectForKey:@(widget_id)];
}

void na_switch_set_state(void* ptr, bool on) {
  NSSwitch* sw = (__bridge NSSwitch*)ptr;
  if (sw) {
    sw.state = on ? NSControlStateValueOn : NSControlStateValueOff;
  }
}

bool na_switch_get_state(void* ptr) {
  NSSwitch* sw = (__bridge NSSwitch*)ptr;
  return sw && sw.state == NSControlStateValueOn;
}

void na_switch_fire(uint32_t widget_id) {
  ensure_switch_tables();
  NAGenericTarget* target = g_switch_targets[@(widget_id)];
  if (target) {
    [target fire:nil];
  }
}
