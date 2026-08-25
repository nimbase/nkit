#import <Cocoa/Cocoa.h>
#import "gui_common.h"

typedef void (*na_button_event_fn)(uint32_t widget_id, void* ctx);

static na_button_event_fn g_button_fn = NULL;
static void* g_button_ctx = NULL;
static NSMutableDictionary<NSNumber*, NAGenericTarget*>* g_button_targets = nil;

static void ensure_button_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_button_targets = [NSMutableDictionary dictionary];
  }
}

static void button_action_thunk(uint32_t widget_id, void* ctx) {
  if (g_button_fn) {
    g_button_fn(widget_id, g_button_ctx);
  }
}

void na_button_set_event_callback(na_button_event_fn fn, void* ctx) {
  g_button_fn = fn;
  g_button_ctx = ctx;
}

#define NA_BUTTON_STYLE_PUSH 0
#define NA_BUTTON_STYLE_MOMENTARY_PUSH 1
#define NA_BUTTON_STYLE_TOGGLE 2
#define NA_BUTTON_STYLE_CHECKBOX 3
#define NA_BUTTON_STYLE_RADIO 4

void* na_button_create(uint32_t widget_id, int style) {
  ensure_button_tables();
  NSButton* button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 80, 32)];
  switch (style) {
    case NA_BUTTON_STYLE_MOMENTARY_PUSH:
      [button setButtonType:NSButtonTypeMomentaryChange];
      button.bezelStyle = NSBezelStyleRounded;
      break;
    case NA_BUTTON_STYLE_TOGGLE:
      [button setButtonType:NSButtonTypePushOnPushOff];
      button.bezelStyle = NSBezelStyleRounded;
      break;
    case NA_BUTTON_STYLE_CHECKBOX:
      [button setButtonType:NSButtonTypeSwitch];
      button.bezelStyle = NSBezelStyleRegularSquare;
      button.bordered = NO;
      break;
    case NA_BUTTON_STYLE_RADIO:
      [button setButtonType:NSButtonTypeRadio];
      button.bezelStyle = NSBezelStyleRegularSquare;
      button.bordered = NO;
      break;
    case NA_BUTTON_STYLE_PUSH:
    default:
      [button setButtonType:NSButtonTypeMomentaryLight];
      button.bezelStyle = NSBezelStyleRounded;
      break;
  }
  NAGenericTarget* target = na_target_new(widget_id, button_action_thunk, NULL);
  g_button_targets[@(widget_id)] = target;
  na_target_attach(button, target);
  na_gui_register_view(button);
  return (__bridge void*)button;
}

void na_button_free(uint32_t widget_id, void* ptr) {
  ensure_button_tables();
  NSButton* button = (__bridge NSButton*)ptr;
  if (button) {
    [button removeFromSuperview];
    na_gui_unregister_view(button);
  }
  [g_button_targets removeObjectForKey:@(widget_id)];
}

void na_button_set_title(void* ptr, const char* title) {
  NSButton* button = (__bridge NSButton*)ptr;
  if (button) {
    button.title = title ? [NSString stringWithUTF8String:title] : @"";
  }
}

const char* na_button_get_title(void* ptr) {
  NSButton* button = (__bridge NSButton*)ptr;
  return button ? na_gui_copy_string(button.title) : na_gui_copy_string(nil);
}

void na_button_set_state(void* ptr, int state) {
  NSButton* button = (__bridge NSButton*)ptr;
  if (button) {
    button.state = (NSControlStateValue)state;
  }
}

int na_button_get_state(void* ptr) {
  NSButton* button = (__bridge NSButton*)ptr;
  return button ? (int)button.state : 0;
}

void na_button_set_enabled(void* ptr, bool enabled) {
  NSButton* button = (__bridge NSButton*)ptr;
  if (button) {
    button.enabled = enabled ? YES : NO;
  }
}

bool na_button_is_enabled(void* ptr) {
  NSButton* button = (__bridge NSButton*)ptr;
  return button ? button.enabled == YES : false;
}

void na_button_fire(uint32_t widget_id) {
  ensure_button_tables();
  NAGenericTarget* target = g_button_targets[@(widget_id)];
  if (target) {
    [target fire:nil];
  }
}
