#import "gui_common.h"

@implementation NAGenericTarget

- (void)fire:(id)sender {
  @try {
    if (_actionFn) {
      _actionFn(_widgetId, _actionCtx);
    }
  } @catch (NSException* exception) {
    NSLog(@"nativeapi gui action exception: %@", exception.reason);
  }
}

@end

NAGenericTarget* na_target_new(uint32_t widget_id, na_gui_action_fn fn, void* ctx) {
  NAGenericTarget* target = [[NAGenericTarget alloc] init];
  target.actionFn = fn;
  target.actionCtx = ctx;
  target.widgetId = widget_id;
  return target;
}

void na_target_attach(NSControl* control, NAGenericTarget* target) {
  if (!control || !target) {
    return;
  }
  control.target = target;
  control.action = @selector(fire:);
}

void na_gui_register_view(NSView* view) {
  static NSHashTable* liveViews = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    liveViews = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPersonality |
                                              NSPointerFunctionsStrongMemory];
  });
  [liveViews addObject:view];
}

void na_gui_unregister_view(NSView* view) {
  static NSHashTable* liveViews = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    liveViews = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPersonality |
                                              NSPointerFunctionsStrongMemory];
  });
  [liveViews removeObject:view];
}
