#import "gui_common.h"

static void (*g_segmented_event_fn)(uint32_t, int64_t, void*) = NULL;
static void* g_segmented_event_ctx = NULL;

@interface NASegmentedTarget : NSObject
@property (nonatomic) uint32_t widgetId;
@end
@implementation NASegmentedTarget
- (void)valueChanged:(UISegmentedControl*)sender {
  if (g_segmented_event_fn)
    g_segmented_event_fn(self.widgetId, (int64_t)sender.selectedSegmentIndex,
                         g_segmented_event_ctx);
}
@end

static NSMutableDictionary* g_segmented_targets = nil;

void na_segmented_set_event_callback(void (*fn)(uint32_t, int64_t, void*), void* ctx) {
  g_segmented_event_fn = fn; g_segmented_event_ctx = ctx;
}

void* na_segmented_create(uint32_t widget_id) {
  if (!g_segmented_targets) g_segmented_targets = [NSMutableDictionary dictionary];
  UISegmentedControl* sc = [[UISegmentedControl alloc] initWithItems:@[]];
  NASegmentedTarget* target = [[NASegmentedTarget alloc] init];
  target.widgetId = widget_id;
  [sc addTarget:target action:@selector(valueChanged:)
      forControlEvents:UIControlEventValueChanged];
  g_segmented_targets[@(widget_id)] = target;
  return (__bridge_retained void*)sc;
}

void na_segmented_free(uint32_t widget_id, void* ptr) {
  if (!ptr) return;
  UISegmentedControl* sc = (__bridge_transfer UISegmentedControl*)ptr;
  [sc removeFromSuperview];
  [g_segmented_targets removeObjectForKey:@(widget_id)];
}

void na_segmented_set_labels(void* ptr, const char** labels, int count) {
  UISegmentedControl* sc = (__bridge UISegmentedControl*)ptr;
  if (!sc) return;
  [sc removeAllSegments];
  for (int i = 0; i < count; i++) {
    NSString* s = [NSString stringWithUTF8String:labels[i] ?: ""];
    [sc insertSegmentWithTitle:s atIndex:i animated:NO];
  }
}

int na_segmented_count(void* ptr) {
  UISegmentedControl* sc = (__bridge UISegmentedControl*)ptr;
  return sc ? (int)sc.numberOfSegments : 0;
}

int64_t na_segmented_selected(void* ptr) {
  UISegmentedControl* sc = (__bridge UISegmentedControl*)ptr;
  return sc ? (int64_t)sc.selectedSegmentIndex : -1;
}

void na_segmented_select(void* ptr, int64_t index) {
  UISegmentedControl* sc = (__bridge UISegmentedControl*)ptr;
  if (sc && index >= 0 && index < (int64_t)sc.numberOfSegments)
    sc.selectedSegmentIndex = (NSInteger)index;
}

void na_segmented_fire(uint32_t widget_id, void* ptr) {
  if (g_segmented_event_fn) {
    UISegmentedControl* sc = (__bridge UISegmentedControl*)ptr;
    int64_t idx = sc ? (int64_t)sc.selectedSegmentIndex : -1;
    g_segmented_event_fn(widget_id, idx, g_segmented_event_ctx);
  }
}
