#import "gui_common.h"
#import <objc/runtime.h>

typedef void (*na_input_event_fn)(uint32_t widget_id, void* ctx);

static na_input_event_fn g_input_fn = NULL;
static void* g_input_ctx = NULL;

void na_input_set_event_callback(na_input_event_fn fn, void* ctx) {
  g_input_fn = fn;
  g_input_ctx = ctx;
}

@interface NAInputTarget : NSObject
@property(nonatomic, assign) uint32_t widgetId;
@end

@implementation NAInputTarget
- (void)editingChanged:(UITextField*)sender {
  if (g_input_fn) {
    g_input_fn(_widgetId, g_input_ctx);
  }
}
- (void)editingDidEnd:(UITextField*)sender {
  if (g_input_fn) {
    g_input_fn(_widgetId, (void*)1);
  }
}
@end

static NSMutableDictionary<NSNumber*, NAInputTarget*>* g_input_targets = nil;

static void ensure_input_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_input_targets = [NSMutableDictionary dictionary];
  }
}

#define NA_INPUT_STYLE_SINGLE_LINE 0
#define NA_INPUT_STYLE_SECURE 1
#define NA_INPUT_STYLE_SEARCH 2

void* na_input_create(uint32_t widget_id, int style) {
  ensure_input_tables();
  UITextField* field = nil;
  switch (style) {
    case NA_INPUT_STYLE_SECURE: {
      field = [[UITextField alloc] init];
      field.secureTextEntry = YES;
      break;
    }
    case NA_INPUT_STYLE_SEARCH: {
      field = [[UITextField alloc] init];
      field.autocorrectionType = UITextAutocorrectionTypeNo;
      break;
    }
    default:
      field = [[UITextField alloc] init];
      break;
  }
  field.borderStyle = UITextBorderStyleRoundedRect;
  field.translatesAutoresizingMaskIntoConstraints = NO;

  NAInputTarget* target = [[NAInputTarget alloc] init];
  target.widgetId = widget_id;
  g_input_targets[@(widget_id)] = target;

  [field addTarget:target action:@selector(editingChanged:)
      forControlEvents:UIControlEventEditingChanged];
  [field addTarget:target action:@selector(editingDidEnd:)
      forControlEvents:UIControlEventEditingDidEndOnExit];

  na_gui_register_view(field);
  return (__bridge_retained void*)field;
}

void na_input_free(uint32_t widget_id, void* ptr) {
  ensure_input_tables();
  if (!ptr) return;
  UITextField* field = (__bridge_transfer UITextField*)ptr;
  [field removeFromSuperview];
  na_gui_unregister_view(field);
  [g_input_targets removeObjectForKey:@(widget_id)];
}

void na_input_set_text(void* ptr, const char* text) {
  UITextField* field = (__bridge UITextField*)ptr;
  if (field) {
    field.text = text ? [NSString stringWithUTF8String:text] : @"";
  }
}

const char* na_input_get_text(void* ptr) {
  UITextField* field = (__bridge UITextField*)ptr;
  return field ? na_gui_copy_string(field.text) : na_gui_copy_string(nil);
}

void na_input_set_placeholder(void* ptr, const char* placeholder) {
  UITextField* field = (__bridge UITextField*)ptr;
  if (field) {
    field.placeholder = placeholder ? [NSString stringWithUTF8String:placeholder] : nil;
  }
}

const char* na_input_get_placeholder(void* ptr) {
  UITextField* field = (__bridge UITextField*)ptr;
  return field && field.placeholder
             ? na_gui_copy_string(field.placeholder)
             : na_gui_copy_string(nil);
}

void na_input_set_editable(void* ptr, bool editable) {
  UITextField* field = (__bridge UITextField*)ptr;
  if (field) {
    field.enabled = editable ? YES : NO;
  }
}

bool na_input_is_editable(void* ptr) {
  UITextField* field = (__bridge UITextField*)ptr;
  return field && field.enabled == YES;
}

void na_input_focus(uint32_t widget_id, void* ptr) {
  UITextField* field = (__bridge UITextField*)ptr;
  if (field) {
    [field becomeFirstResponder];
  }
}

void na_input_fire_change(uint32_t widget_id) {
  if (g_input_fn) {
    g_input_fn(widget_id, NULL);
  }
}
