#import "gui_common.h"
#import <objc/runtime.h>

typedef void (*na_button_event_fn)(uint32_t widget_id, void* ctx);

static na_button_event_fn g_button_event_fn = NULL;
static void* g_button_event_ctx = NULL;

static void fire_button(uint32_t widget_id) {
  if (g_button_event_fn) {
    g_button_event_fn(widget_id, g_button_event_ctx);
  }
}

@implementation NAButtonTarget : NSObject
- (void)fire:(id)sender {
  (void)sender;
  NSNumber* wid = objc_getAssociatedObject(sender, "na_button_id");
  if (wid) {
    fire_button(wid.unsignedIntValue);
  }
}
@end

static NAButtonTarget* button_target(void) {
  static NAButtonTarget* target = nil;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    target = [[NAButtonTarget alloc] init];
  });
  return target;
}

void* na_button_create(uint32_t widget_id, int style) {
  (void)style;
  UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
  objc_setAssociatedObject(button, "na_button_id", @(widget_id),
                           OBJC_ASSOCIATION_RETAIN);
  [button addTarget:button_target()
              action:@selector(fire:)
    forControlEvents:UIControlEventTouchUpInside];
  return (__bridge_retained void*)button;
}

void na_button_free(uint32_t widget_id, void* view_ptr) {
  (void)widget_id;
  if (!view_ptr) return;
  UIButton* button = (__bridge_transfer UIButton*)view_ptr;
  [button removeFromSuperview];
}

void na_button_set_title(void* view_ptr, const char* title) {
  UIButton* button = (__bridge UIButton*)view_ptr;
  if (button) {
    [button setTitle:[NSString stringWithUTF8String:title ?: ""]
            forState:UIControlStateNormal];
  }
}

const char* na_button_get_title(void* view_ptr) {
  UIButton* button = (__bridge UIButton*)view_ptr;
  return na_gui_copy_string(button.currentTitle);
}

void na_button_set_state(void* view_ptr, int state) {
  UIButton* button = (__bridge UIButton*)view_ptr;
  if (!button) {
    return;
  }
  if (state == 1) {
    button.highlighted = YES;
  } else {
    button.highlighted = NO;
    button.selected = state == 2 ? YES : NO;
  }
}

int na_button_get_state(void* view_ptr) {
  UIButton* button = (__bridge UIButton*)view_ptr;
  if (!button) {
    return 0;
  }
  if (button.selected) {
    return 2;
  }
  return button.highlighted ? 1 : 0;
}

void na_button_set_enabled(void* view_ptr, bool enabled) {
  UIButton* button = (__bridge UIButton*)view_ptr;
  if (button) {
    button.enabled = enabled ? YES : NO;
  }
}

bool na_button_is_enabled(void* view_ptr) {
  UIButton* button = (__bridge UIButton*)view_ptr;
  return button ? button.enabled != NO : false;
}

void na_button_set_event_callback(na_button_event_fn fn, void* ctx) {
  g_button_event_fn = fn;
  g_button_event_ctx = ctx;
}

void na_button_fire(uint32_t widget_id) {
  fire_button(widget_id);
}
