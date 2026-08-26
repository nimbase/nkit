#import "gui_common.h"

char g_gui_text_buffer[2048];

@implementation NAGenericTarget

- (void)fire:(id)sender {
  (void)sender;
  @try {
    if (_actionFn) {
      _actionFn(_widgetId, _actionCtx);
    }
  } @catch (NSException* exception) {
    NSLog(@"nkit gui action exception: %@", exception.reason);
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

void na_target_attach(UIControl* control, NAGenericTarget* target) {
  if (!control || !target) {
    return;
  }
  [control addTarget:target
              action:@selector(fire:)
    forControlEvents:UIControlEventTouchUpInside];
}

void na_gui_register_view(UIView* view) {
  static NSMutableSet* liveViews = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    liveViews = [NSMutableSet set];
  });
  [liveViews addObject:view];
}

void na_gui_unregister_view(UIView* view) {
  static NSMutableSet* liveViews = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    liveViews = [NSMutableSet set];
  });
  [liveViews removeObject:view];
}
