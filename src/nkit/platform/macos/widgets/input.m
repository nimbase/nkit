#import <Cocoa/Cocoa.h>
#import "gui_common.h"

typedef void (*na_input_event_fn)(uint32_t widget_id, void* ctx);

static na_input_event_fn g_input_fn = NULL;
static void* g_input_ctx = NULL;

void na_input_set_event_callback(na_input_event_fn fn, void* ctx) {
  g_input_fn = fn;
  g_input_ctx = ctx;
}

@interface NAInputDelegate : NSObject <NSTextFieldDelegate>
@property(nonatomic, assign) uint32_t widgetId;
@end

@implementation NAInputDelegate
- (void)controlTextDidChange:(NSNotification*)notification {
  if (g_input_fn) {
    g_input_fn(_widgetId, g_input_ctx);
  }
}
- (void)controlTextDidEndEditing:(NSNotification*)notification {
  if (g_input_fn) {
    g_input_fn(_widgetId, (void*)1);
  }
}
@end

static NSMutableDictionary<NSNumber*, NAInputDelegate*>* g_input_delegates = nil;

static void ensure_input_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_input_delegates = [NSMutableDictionary dictionary];
  }
}

#define NA_INPUT_STYLE_SINGLE_LINE 0
#define NA_INPUT_STYLE_SECURE 1
#define NA_INPUT_STYLE_SEARCH 2

void* na_input_create(uint32_t widget_id, int style) {
  ensure_input_tables();
  NSTextField* field = nil;
  switch (style) {
    case NA_INPUT_STYLE_SECURE:
      field = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 0, 160, 24)];
      break;
    case NA_INPUT_STYLE_SEARCH:
      field = [[NSSearchField alloc] initWithFrame:NSMakeRect(0, 0, 160, 28)];
      break;
    default:
      field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 160, 24)];
      break;
  }
  field.bezelStyle = NSTextFieldRoundedBezel;
  NAInputDelegate* delegate = [[NAInputDelegate alloc] init];
  delegate.widgetId = widget_id;
  g_input_delegates[@(widget_id)] = delegate;
  field.delegate = delegate;
  na_gui_register_view(field);
  return (__bridge void*)field;
}

void na_input_free(uint32_t widget_id, void* ptr) {
  ensure_input_tables();
  NSTextField* field = (__bridge NSTextField*)ptr;
  if (field) {
    [field removeFromSuperview];
    field.delegate = nil;
    na_gui_unregister_view(field);
  }
  [g_input_delegates removeObjectForKey:@(widget_id)];
}

void na_input_set_text(void* ptr, const char* text) {
  NSTextField* field = (__bridge NSTextField*)ptr;
  if (field) {
    field.stringValue = text ? [NSString stringWithUTF8String:text] : @"";
  }
}

const char* na_input_get_text(void* ptr) {
  NSTextField* field = (__bridge NSTextField*)ptr;
  return field ? na_gui_copy_string(field.stringValue) : na_gui_copy_string(nil);
}

void na_input_set_placeholder(void* ptr, const char* placeholder) {
  NSTextField* field = (__bridge NSTextField*)ptr;
  if (field) {
    field.placeholderString =
        placeholder ? [NSString stringWithUTF8String:placeholder] : nil;
  }
}

const char* na_input_get_placeholder(void* ptr) {
  NSTextField* field = (__bridge NSTextField*)ptr;
  return field && field.placeholderString
             ? na_gui_copy_string(field.placeholderString)
             : na_gui_copy_string(nil);
}

void na_input_set_editable(void* ptr, bool editable) {
  NSTextField* field = (__bridge NSTextField*)ptr;
  if (field) {
    field.editable = editable ? YES : NO;
  }
}

bool na_input_is_editable(void* ptr) {
  NSTextField* field = (__bridge NSTextField*)ptr;
  return field && field.editable == YES;
}

void na_input_focus(uint32_t widget_id, void* ptr) {
  NSTextField* field = (__bridge NSTextField*)ptr;
  if (field && field.window) {
    [field.window makeFirstResponder:field];
  }
}

void na_input_fire_change(uint32_t widget_id) {
  if (g_input_fn) {
    g_input_fn(widget_id, NULL);
  }
}
