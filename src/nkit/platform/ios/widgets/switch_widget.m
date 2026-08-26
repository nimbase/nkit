#import "gui_common.h"

static void (*g_switch_event_fn)(uint32_t, void*) = NULL;
static void* g_switch_event_ctx = NULL;

@interface NASwitchTarget : NSObject
@property (nonatomic) uint32_t widgetId;
@end
@implementation NASwitchTarget
- (void)valueChanged:(UISwitch*)sender {
  if (g_switch_event_fn)
    g_switch_event_fn(self.widgetId, g_switch_event_ctx);
}
@end

static NSMutableDictionary* g_switch_targets = nil;

void na_switch_set_event_callback(void (*fn)(uint32_t, void*), void* ctx) {
  g_switch_event_fn = fn; g_switch_event_ctx = ctx;
}

void* na_switch_create(uint32_t widget_id) {
  if (!g_switch_targets) g_switch_targets = [NSMutableDictionary dictionary];
  UISwitch* sw = [[UISwitch alloc] init];
  NASwitchTarget* target = [[NASwitchTarget alloc] init];
  target.widgetId = widget_id;
  [sw addTarget:target action:@selector(valueChanged:)
      forControlEvents:UIControlEventValueChanged];
  g_switch_targets[@(widget_id)] = target;
  return (__bridge_retained void*)sw;
}

void na_switch_free(uint32_t widget_id, void* ptr) {
  if (!ptr) return;
  UISwitch* sw = (__bridge_transfer UISwitch*)ptr;
  [sw removeFromSuperview];
  [g_switch_targets removeObjectForKey:@(widget_id)];
}

void na_switch_set_state(void* ptr, bool on) {
  UISwitch* sw = (__bridge UISwitch*)ptr;
  if (sw) sw.on = on;
}

bool na_switch_get_state(void* ptr) {
  UISwitch* sw = (__bridge UISwitch*)ptr;
  return sw ? sw.isOn : false;
}

void na_switch_fire(uint32_t widget_id) {
  if (g_switch_event_fn)
    g_switch_event_fn(widget_id, g_switch_event_ctx);
}
