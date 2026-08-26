#import "gui_common.h"
#import <objc/runtime.h>

typedef void (*na_textarea_event_fn)(uint32_t widget_id, void* ctx);

static na_textarea_event_fn g_textarea_fn = NULL;
static void* g_textarea_ctx = NULL;

void na_textarea_set_event_callback(na_textarea_event_fn fn, void* ctx) {
  g_textarea_fn = fn;
  g_textarea_ctx = ctx;
}

@interface NATextAreaTarget : NSObject
@property(nonatomic, assign) uint32_t widgetId;
@end

@implementation NATextAreaTarget
- (void)textDidChange:(NSNotification*)notification {
  if (g_textarea_fn) {
    g_textarea_fn(_widgetId, g_textarea_ctx);
  }
}
@end

static NSMutableDictionary<NSNumber*, NATextAreaTarget*>* g_textarea_targets = nil;

static void ensure_textarea_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_textarea_targets = [NSMutableDictionary dictionary];
  }
}

void* na_textarea_create(uint32_t widget_id) {
  ensure_textarea_tables();
  UITextView* textView = [[UITextView alloc] init];
  textView.translatesAutoresizingMaskIntoConstraints = NO;
  textView.font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
  textView.autocorrectionType = UITextAutocorrectionTypeDefault;
  textView.autocapitalizationType = UITextAutocapitalizationTypeSentences;

  NATextAreaTarget* target = [[NATextAreaTarget alloc] init];
  target.widgetId = widget_id;
  g_textarea_targets[@(widget_id)] = target;

  [[NSNotificationCenter defaultCenter] addObserver:target
                                           selector:@selector(textDidChange:)
                                               name:UITextViewTextDidChangeNotification
                                             object:textView];

  na_gui_register_view(textView);
  return (__bridge_retained void*)textView;
}

void na_textarea_free(uint32_t widget_id, void* ptr) {
  ensure_textarea_tables();
  if (!ptr) return;
  UITextView* textView = (__bridge_transfer UITextView*)ptr;
  NATextAreaTarget* target = g_textarea_targets[@(widget_id)];
  if (target) {
    [[NSNotificationCenter defaultCenter] removeObserver:target];
  }
  [textView removeFromSuperview];
  na_gui_unregister_view(textView);
  [g_textarea_targets removeObjectForKey:@(widget_id)];
}

void na_textarea_set_text(uint32_t widget_id, void* ptr, const char* text) {
  UITextView* textView = (__bridge UITextView*)ptr;
  if (textView) {
    textView.text = text ? [NSString stringWithUTF8String:text] : @"";
  }
}

const char* na_textarea_get_text(uint32_t widget_id, void* ptr) {
  UITextView* textView = (__bridge UITextView*)ptr;
  return textView ? na_gui_copy_string(textView.text) : na_gui_copy_string(nil);
}

void na_textarea_set_editable(uint32_t widget_id, void* ptr, bool editable) {
  UITextView* textView = (__bridge UITextView*)ptr;
  if (textView) {
    textView.editable = editable ? YES : NO;
  }
}

bool na_textarea_is_editable(uint32_t widget_id, void* ptr) {
  UITextView* textView = (__bridge UITextView*)ptr;
  return textView && textView.editable == YES;
}

void na_textarea_fire_change(uint32_t widget_id) {
  if (g_textarea_fn) {
    g_textarea_fn(widget_id, NULL);
  }
}
