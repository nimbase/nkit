#import <Cocoa/Cocoa.h>
#import "gui_common.h"

typedef void (*na_textarea_event_fn)(uint32_t widget_id, void* ctx);

static na_textarea_event_fn g_textarea_fn = NULL;
static void* g_textarea_ctx = NULL;

void na_textarea_set_event_callback(na_textarea_event_fn fn, void* ctx) {
  g_textarea_fn = fn;
  g_textarea_ctx = ctx;
}

@interface NATextAreaDelegate : NSObject <NSTextViewDelegate>
@property(nonatomic, assign) uint32_t widgetId;
@end

@implementation NATextAreaDelegate
- (void)textDidChange:(NSNotification*)notification {
  if (g_textarea_fn) {
    g_textarea_fn(_widgetId, g_textarea_ctx);
  }
}
@end

static NSMutableDictionary<NSNumber*, NSValue*>* g_textarea_texts = nil;
static NSMutableDictionary<NSNumber*, NATextAreaDelegate*>* g_textarea_delegates = nil;

static void ensure_textarea_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_textarea_texts = [NSMutableDictionary dictionary];
    g_textarea_delegates = [NSMutableDictionary dictionary];
  }
}

void* na_textarea_create(uint32_t widget_id) {
  ensure_textarea_tables();
  NSScrollView* scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 200, 120)];
  scroll.hasVerticalScroller = YES;
  scroll.autohidesScrollers = YES;
  scroll.borderType = NSBezelBorder;

  NSTextView* textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 200, 120)];
  textView.richText = NO;
  textView.automaticQuoteSubstitutionEnabled = NO;
  textView.automaticDashSubstitutionEnabled = NO;
  textView.automaticTextReplacementEnabled = NO;
  textView.verticallyResizable = YES;
  textView.horizontallyResizable = NO;
  textView.font = [NSFont systemFontOfSize:[NSFont systemFontSize]];

  NSSize contentSize = scroll.contentSize;
  textView.frame = NSMakeRect(0, 0, contentSize.width, contentSize.height);
  textView.minSize = NSMakeSize(0.0, contentSize.height);
  textView.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
  textView.textContainer.containerSize = scroll.contentSize;
  textView.textContainer.widthTracksTextView = YES;

  [scroll setDocumentView:textView];

  NATextAreaDelegate* delegate = [[NATextAreaDelegate alloc] init];
  delegate.widgetId = widget_id;
  textView.delegate = delegate;

  g_textarea_texts[@(widget_id)] = [NSValue valueWithPointer:(__bridge const void*)textView];
  g_textarea_delegates[@(widget_id)] = delegate;

  na_gui_register_view(scroll);
  return (__bridge void*)scroll;
}

void na_textarea_free(uint32_t widget_id, void* ptr) {
  ensure_textarea_tables();
  NSScrollView* scroll = (__bridge NSScrollView*)ptr;
  if (scroll) {
    [scroll removeFromSuperview];
    na_gui_unregister_view(scroll);
  }
  [g_textarea_texts removeObjectForKey:@(widget_id)];
  [g_textarea_delegates removeObjectForKey:@(widget_id)];
}

static NSTextView* textarea_for(void* ptr, uint32_t widget_id) {
  NSScrollView* scroll = (__bridge NSScrollView*)ptr;
  if (!scroll || ![scroll.documentView isKindOfClass:[NSTextView class]]) {
    return nil;
  }
  return (NSTextView*)scroll.documentView;
}

void na_textarea_set_text(uint32_t widget_id, void* ptr, const char* text) {
  NSTextView* textView = textarea_for(ptr, widget_id);
  if (textView) {
    NSString* value = text ? [NSString stringWithUTF8String:text] : @"";
    [textView setString:value];
  }
}

const char* na_textarea_get_text(uint32_t widget_id, void* ptr) {
  NSTextView* textView = textarea_for(ptr, widget_id);
  return textView ? na_gui_copy_string(textView.string) : na_gui_copy_string(nil);
}

void na_textarea_set_editable(uint32_t widget_id, void* ptr, bool editable) {
  NSTextView* textView = textarea_for(ptr, widget_id);
  if (textView) {
    textView.editable = editable ? YES : NO;
  }
}

bool na_textarea_is_editable(uint32_t widget_id, void* ptr) {
  NSTextView* textView = textarea_for(ptr, widget_id);
  return textView && textView.editable == YES;
}

void na_textarea_fire_change(uint32_t widget_id) {
  if (g_textarea_fn) {
    g_textarea_fn(widget_id, NULL);
  }
}
