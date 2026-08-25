#import <Cocoa/Cocoa.h>
#import "gui_common.h"

typedef void (*na_slider_event_fn)(uint32_t widget_id, double value, bool dragging, void* ctx);

static na_slider_event_fn g_slider_fn = NULL;
static void* g_slider_ctx = NULL;

static NSMutableDictionary<NSNumber*, NAGenericTarget*>* g_slider_targets = nil;

static void ensure_slider_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_slider_targets = [NSMutableDictionary dictionary];
  }
}

#define NA_SLIDER_EVENT_CHANGED 0
#define NA_SLIDER_EVENT_RELEASED 1

@interface NASliderTarget : NSObject
@property(nonatomic, assign) uint32_t widgetId;
@end

@implementation NASliderTarget
- (void)sliderChanged:(id)sender {
  if (g_slider_fn) {
    NSSlider* slider = (NSSlider*)sender;
    g_slider_fn(_widgetId, slider.doubleValue, false, g_slider_ctx);
  }
}
- (void)sliderReleased:(id)sender {
  if (g_slider_fn) {
    NSSlider* slider = (NSSlider*)sender;
    g_slider_fn(_widgetId, slider.doubleValue, true, g_slider_ctx);
  }
}
@end

void na_slider_set_event_callback(na_slider_event_fn fn, void* ctx) {
  g_slider_fn = fn;
  g_slider_ctx = ctx;
}

void* na_slider_create(uint32_t widget_id) {
  ensure_slider_tables();
  NSSlider* slider = [[NSSlider alloc] initWithFrame:NSMakeRect(0, 0, 160, 24)];
  slider.minValue = 0.0;
  slider.maxValue = 100.0;
  slider.doubleValue = 0.0;
  slider.continuous = YES;

  NASliderTarget* target = [[NASliderTarget alloc] init];
  target.widgetId = widget_id;
  g_slider_targets[@(widget_id)] = target;
  slider.target = target;
  slider.action = @selector(sliderChanged:);

  NSGestureRecognizer* releaseGesture =
      [[NSClickGestureRecognizer alloc] initWithTarget:target
                                                action:@selector(sliderReleased:)];
  [slider addGestureRecognizer:releaseGesture];

  na_gui_register_view(slider);
  return (__bridge void*)slider;
}

void na_slider_free(uint32_t widget_id, void* ptr) {
  ensure_slider_tables();
  NSSlider* slider = (__bridge NSSlider*)ptr;
  if (slider) {
    [slider removeFromSuperview];
    na_gui_unregister_view(slider);
  }
  [g_slider_targets removeObjectForKey:@(widget_id)];
}

void na_slider_set_range(void* ptr, double min, double max) {
  NSSlider* slider = (__bridge NSSlider*)ptr;
  if (slider && max > min) {
    slider.minValue = min;
    slider.maxValue = max;
  }
}

double na_slider_get_min(void* ptr) {
  NSSlider* slider = (__bridge NSSlider*)ptr;
  return slider ? slider.minValue : 0.0;
}

double na_slider_get_max(void* ptr) {
  NSSlider* slider = (__bridge NSSlider*)ptr;
  return slider ? slider.maxValue : 0.0;
}

void na_slider_set_value(void* ptr, double value) {
  NSSlider* slider = (__bridge NSSlider*)ptr;
  if (slider) {
    slider.doubleValue = value;
  }
}

double na_slider_get_value(void* ptr) {
  NSSlider* slider = (__bridge NSSlider*)ptr;
  return slider ? slider.doubleValue : 0.0;
}
