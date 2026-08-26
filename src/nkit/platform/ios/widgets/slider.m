#import "gui_common.h"

static void (*g_slider_event_fn)(uint32_t, double, bool, void*) = NULL;
static void* g_slider_event_ctx = NULL;

@interface NASliderTarget : NSObject
@property (nonatomic) uint32_t widgetId;
@end
@implementation NASliderTarget
- (void)valueChanged:(UISlider*)sender {
  if (g_slider_event_fn)
    g_slider_event_fn(self.widgetId, (double)sender.value, sender.isTracking,
                      g_slider_event_ctx);
}
- (void)valueTouchUp:(UISlider*)sender {
  if (g_slider_event_fn)
    g_slider_event_fn(self.widgetId, (double)sender.value, false,
                      g_slider_event_ctx);
}
@end

static NSMutableDictionary* g_slider_targets = nil;

void na_slider_set_event_callback(void (*fn)(uint32_t, double, bool, void*), void* ctx) {
  g_slider_event_fn = fn; g_slider_event_ctx = ctx;
}

void* na_slider_create(uint32_t widget_id) {
  if (!g_slider_targets) g_slider_targets = [NSMutableDictionary dictionary];
  UISlider* sl = [[UISlider alloc] init];
  sl.minimumValue = 0.0;
  sl.maximumValue = 1.0;
  sl.value = 0.0;
  NASliderTarget* target = [[NASliderTarget alloc] init];
  target.widgetId = widget_id;
  [sl addTarget:target action:@selector(valueChanged:)
      forControlEvents:UIControlEventValueChanged | UIControlEventTouchDown];
  [sl addTarget:target action:@selector(valueTouchUp:)
      forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
  g_slider_targets[@(widget_id)] = target;
  return (__bridge_retained void*)sl;
}

void na_slider_free(uint32_t widget_id, void* ptr) {
  if (!ptr) return;
  UISlider* sl = (__bridge_transfer UISlider*)ptr;
  [sl removeFromSuperview];
  [g_slider_targets removeObjectForKey:@(widget_id)];
}

void na_slider_set_range(void* ptr, double min, double max) {
  UISlider* sl = (__bridge UISlider*)ptr;
  if (sl) { sl.minimumValue = min; sl.maximumValue = max; }
}

double na_slider_get_min(void* ptr) {
  UISlider* sl = (__bridge UISlider*)ptr;
  return sl ? (double)sl.minimumValue : 0.0;
}

double na_slider_get_max(void* ptr) {
  UISlider* sl = (__bridge UISlider*)ptr;
  return sl ? (double)sl.maximumValue : 1.0;
}

void na_slider_set_value(void* ptr, double value) {
  UISlider* sl = (__bridge UISlider*)ptr;
  if (sl) sl.value = (float)value;
}

double na_slider_get_value(void* ptr) {
  UISlider* sl = (__bridge UISlider*)ptr;
  return sl ? (double)sl.value : 0.0;
}
