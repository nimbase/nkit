#import <Cocoa/Cocoa.h>
#import "gui_common.h"

typedef void (*na_segmented_event_fn)(uint32_t widget_id, int64_t index, void* ctx);

static na_segmented_event_fn g_segmented_fn = NULL;
static void* g_segmented_ctx = NULL;

static NSMutableDictionary<NSNumber*, NAGenericTarget*>* g_segmented_targets = nil;

static void ensure_segmented_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_segmented_targets = [NSMutableDictionary dictionary];
  }
}

static void segmented_action_thunk(uint32_t widget_id, void* ctx) {
  NSSegmentedControl* control = (__bridge NSSegmentedControl*)ctx;
  if (g_segmented_fn && control) {
    g_segmented_fn(widget_id, (int64_t)control.selectedSegment, g_segmented_ctx);
  }
}

void na_segmented_set_event_callback(na_segmented_event_fn fn, void* ctx) {
  g_segmented_fn = fn;
  g_segmented_ctx = ctx;
}

void* na_segmented_create(uint32_t widget_id) {
  ensure_segmented_tables();
  NSSegmentedControl* control =
      [NSSegmentedControl segmentedControlWithLabels:@[] trackingMode:NSSegmentSwitchTrackingSelectOne
                                              target:nil
                                              action:nil];
  NAGenericTarget* target = na_target_new(widget_id, segmented_action_thunk, (__bridge void*)control);
  g_segmented_targets[@(widget_id)] = target;
  na_target_attach(control, target);
  na_gui_register_view(control);
  return (__bridge void*)control;
}

void na_segmented_free(uint32_t widget_id, void* ptr) {
  ensure_segmented_tables();
  NSSegmentedControl* control = (__bridge NSSegmentedControl*)ptr;
  if (control) {
    [control removeFromSuperview];
    na_gui_unregister_view(control);
  }
  [g_segmented_targets removeObjectForKey:@(widget_id)];
}

void na_segmented_set_labels(void* ptr, const char** labels, int count) {
  NSSegmentedControl* control = (__bridge NSSegmentedControl*)ptr;
  if (!control || count <= 0) {
    return;
  }
  NSMutableArray<NSString*>* names = [NSMutableArray arrayWithCapacity:count];
  for (int i = 0; i < count; i++) {
    [names addObject:labels[i] ? [NSString stringWithUTF8String:labels[i]] : @""];
  }
  control.segmentCount = count;
  for (int i = 0; i < count; i++) {
    [control setLabel:names[i] forSegment:i];
  }
  if (count > 0 && control.selectedSegment >= (NSUInteger)count) {
    NSSegmentedCell* cell = (NSSegmentedCell*)control.cell;
    [cell setSelectedSegment:0];
  }
}

int na_segmented_count(void* ptr) {
  NSSegmentedControl* control = (__bridge NSSegmentedControl*)ptr;
  return control ? (int)control.segmentCount : 0;
}

int64_t na_segmented_selected(void* ptr) {
  NSSegmentedControl* control = (__bridge NSSegmentedControl*)ptr;
  return control ? (int64_t)control.selectedSegment : -1;
}

void na_segmented_select(void* ptr, int64_t index) {
  NSSegmentedControl* control = (__bridge NSSegmentedControl*)ptr;
  if (control && index >= 0 && index < (int64_t)control.segmentCount) {
    NSSegmentedCell* cell = (NSSegmentedCell*)control.cell;
    [cell setSelectedSegment:(NSInteger)index];
  }
}

void na_segmented_fire(uint32_t widget_id, void* ptr) {
  ensure_segmented_tables();
  NAGenericTarget* target = g_segmented_targets[@(widget_id)];
  if (target) {
    [target fire:nil];
  }
}
