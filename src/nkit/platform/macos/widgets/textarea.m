#import <Cocoa/Cocoa.h>
#import "gui_common.h"

typedef void (*na_textarea_event_fn)(uint32_t widget_id, void* ctx);
typedef void (*na_textarea_focus_fn)(uint32_t widget_id, bool focused,
                                     void* ctx);

static na_textarea_event_fn g_textarea_fn = NULL;
static void* g_textarea_ctx = NULL;
static na_textarea_focus_fn g_textarea_focus_fn = NULL;
static void* g_textarea_focus_ctx = NULL;

void na_textarea_set_event_callback(na_textarea_event_fn fn, void* ctx) {
  g_textarea_fn = fn;
  g_textarea_ctx = ctx;
}

void na_textarea_set_focus_callback(na_textarea_focus_fn fn, void* ctx) {
  g_textarea_focus_fn = fn;
  g_textarea_focus_ctx = ctx;
}

@interface NATextAreaDelegate : NSObject <NSTextViewDelegate>
@property(nonatomic, assign) uint32_t widgetId;
@end

// Subclass only to observe first-responder changes: NSTextView posts no
// notification on plain focus gain/loss (only once editing starts).
@interface NATextView : NSTextView
@property(nonatomic, assign) uint32_t naWidgetId;
@end

@implementation NATextView
- (BOOL)becomeFirstResponder {
  BOOL ok = [super becomeFirstResponder];
  if (ok && g_textarea_focus_fn) {
    g_textarea_focus_fn(_naWidgetId, true, g_textarea_focus_ctx);
  }
  return ok;
}
- (BOOL)resignFirstResponder {
  BOOL ok = [super resignFirstResponder];
  if (ok && g_textarea_focus_fn) {
    g_textarea_focus_fn(_naWidgetId, false, g_textarea_focus_ctx);
  }
  return ok;
}
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
  // Rounded corners echoing NSTextFieldRoundedBezel used by text inputs.
  // The native bezel keeps drawing (and adapting to appearances); the
  // layer just clips it to a rounded shape.
  scroll.wantsLayer = YES;
  scroll.layer.cornerRadius = 6.0;
  scroll.layer.masksToBounds = YES;

  NATextView* textView = [[NATextView alloc] initWithFrame:NSMakeRect(0, 0, 200, 120)];
  textView.naWidgetId = widget_id;
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
  // Canonical scroll-view setup: the document tracks the viewport width
  // (so wrapping always uses the full visible width no matter how the
  // solver resizes the scroll view later) while the container's infinite
  // height lets long content lay out past the viewport and scroll.
  // A fixed frame + finite container (the old code) wrapped early at the
  // creation width and clipped anything past ~one viewport of text.
  textView.autoresizingMask = NSViewWidthSizable;
  textView.textContainer.containerSize =
      NSMakeSize(contentSize.width, CGFLOAT_MAX);
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

void na_textarea_set_allows_undo(uint32_t widget_id, void* ptr, bool allow) {
  // Lets apps with their own (e.g. model-level) undo manager disable the
  // built-in per-keystroke text undo so the two histories can't fight.
  // Default stays YES.
  NSTextView* textView = textarea_for(ptr, widget_id);
  if (textView) {
    textView.allowsUndo = allow ? YES : NO;
  }
}

void na_textarea_fire_change(uint32_t widget_id) {
  if (g_textarea_fn) {
    g_textarea_fn(widget_id, NULL);
  }
}

void na_textarea_fire_focus(uint32_t widget_id, bool focused) {
  if (g_textarea_focus_fn) {
    g_textarea_focus_fn(widget_id, focused, NULL);
  }
}
