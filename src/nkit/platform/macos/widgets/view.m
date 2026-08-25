#import <Cocoa/Cocoa.h>
#include <stdlib.h>
#import "gui_common.h"

typedef void (*na_drop_event_fn)(uint32_t widget_id, const char* const* paths,
                                 int count, void* ctx);
typedef void (*na_frame_changed_fn)(double width, double height, void* ctx);

static na_drop_event_fn g_drop_fn = NULL;
static void* g_drop_ctx = NULL;

void na_drop_set_event_callback(na_drop_event_fn fn, void* ctx) {
  g_drop_fn = fn;
  g_drop_ctx = ctx;
}

@interface NAPlainView : NSView
@property(nonatomic, assign) BOOL dropEnabled;
@property(nonatomic, assign) uint32_t dropWidgetId;
@property(nonatomic, assign) na_frame_changed_fn frameCallback;
@property(nonatomic, assign) void* frameCtx;
@end

@implementation NAPlainView

- (void)setFrame:(NSRect)newFrame {
  BOOL sizeChanged =
      newFrame.size.width != self.frame.size.width ||
      newFrame.size.height != self.frame.size.height;
  [super setFrame:newFrame];
  if (sizeChanged && _frameCallback) {
    _frameCallback(newFrame.size.width, newFrame.size.height, _frameCtx);
  }
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
  if (!_dropEnabled) {
    return NSDragOperationNone;
  }
  NSPasteboard* pb = [sender draggingPasteboard];
  if ([pb types] && [[pb types] containsObject:NSPasteboardTypeFileURL]) {
    return NSDragOperationCopy;
  }
  return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
  if (!_dropEnabled || !g_drop_fn) {
    return NO;
  }
  NSPasteboard* pb = [sender draggingPasteboard];
  NSArray* urls =
      [pb readObjectsForClasses:@[ [NSURL class] ] options:nil];
  if (!urls || urls.count == 0) {
    return NO;
  }
  NSMutableArray<NSString*>* paths = [NSMutableArray array];
  for (NSURL* url in urls) {
    if (url.isFileURL) {
      [paths addObject:url.path];
    }
  }
  if (paths.count == 0) {
    return NO;
  }
  char** list = (char**)malloc(sizeof(char*) * paths.count);
  for (NSUInteger i = 0; i < paths.count; i++) {
    list[i] = strdup(paths[i].UTF8String);
  }
  g_drop_fn(_dropWidgetId,
            (const char* const*)list, (int)paths.count, g_drop_ctx);
  for (NSUInteger i = 0; i < paths.count; i++) {
    free(list[i]);
  }
  free(list);
  return YES;
}

@end

void* na_view_create(void) {
  NAPlainView* view = [[NAPlainView alloc] initWithFrame:NSMakeRect(0, 0, 100, 40)];
  view.dropEnabled = NO;
  na_gui_register_view(view);
  return (__bridge void*)view;
}

void na_view_destroy(void* ptr) {
  NSView* view = (__bridge NSView*)ptr;
  if (!view) {
    return;
  }
  [view removeFromSuperview];
  na_gui_unregister_view(view);
}

void na_view_set_hidden(void* ptr, bool hidden) {
  NSView* view = (__bridge NSView*)ptr;
  if (view) {
    view.hidden = hidden ? YES : NO;
  }
}

bool na_view_is_hidden(void* ptr) {
  NSView* view = (__bridge NSView*)ptr;
  return view && view.hidden == YES;
}

void na_view_set_tooltip(void* ptr, const char* tooltip) {
  NSView* view = (__bridge NSView*)ptr;
  if (view) {
    view.toolTip = tooltip ? [NSString stringWithUTF8String:tooltip] : nil;
  }
}

const char* na_view_get_tooltip(void* ptr) {
  static char tooltip_buffer[512];
  tooltip_buffer[0] = '\0';
  NSView* view = (__bridge NSView*)ptr;
  if (view && view.toolTip) {
    const char* utf8 = view.toolTip.UTF8String;
    if (utf8) {
      strncpy(tooltip_buffer, utf8, sizeof(tooltip_buffer) - 1);
      tooltip_buffer[sizeof(tooltip_buffer) - 1] = '\0';
    }
  }
  return tooltip_buffer;
}

static NSMutableDictionary<NSValue*, NSNumber*>* g_view_tags = nil;

static void ensure_view_tags(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_view_tags = [NSMutableDictionary dictionary];
  }
}

void na_view_set_tag(void* ptr, int tag) {
  NSView* view = (__bridge NSView*)ptr;
  if (view) {
    ensure_view_tags();
    g_view_tags[[NSValue valueWithPointer:(__bridge const void*)view]] = @(tag);
  }
}

int na_view_get_tag(void* ptr) {
  NSView* view = (__bridge NSView*)ptr;
  if (!view) {
    return 0;
  }
  ensure_view_tags();
  NSNumber* value = g_view_tags[[NSValue valueWithPointer:(__bridge const void*)view]];
  return value ? value.intValue : 0;
}

void na_view_set_frame(void* ptr, double x, double y, double w, double h) {
  NSView* view = (__bridge NSView*)ptr;
  if (view) {
    view.frame = NSMakeRect(x, y, w, h);
  }
}

void na_view_get_frame(void* ptr, double* outX, double* outY, double* outW, double* outH) {
  NSView* view = (__bridge NSView*)ptr;
  if (!view) {
    return;
  }
  NSRect frame = view.frame;
  if (outX) *outX = frame.origin.x;
  if (outY) *outY = frame.origin.y;
  if (outW) *outW = frame.size.width;
  if (outH) *outH = frame.size.height;
}

void na_view_add_subview(void* parentPtr, void* childPtr) {
  NSView* parent = (__bridge NSView*)parentPtr;
  NSView* child = (__bridge NSView*)childPtr;
  if (parent && child) {
    [parent addSubview:child];
  }
}

void na_view_remove_from_parent(void* ptr) {
  NSView* view = (__bridge NSView*)ptr;
  if (view) {
    [view removeFromSuperview];
  }
}

void na_view_remove_all(void* parentPtr) {
  NSView* parent = (__bridge NSView*)parentPtr;
  if (parent) {
    [[parent subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
  }
}

int na_view_subview_count(void* parentPtr) {
  NSView* parent = (__bridge NSView*)parentPtr;
  return parent ? (int)[[parent subviews] count] : 0;
}

void na_view_layout(void* ptr) {
  NSView* view = (__bridge NSView*)ptr;
  if (view) {
    [view layoutSubtreeIfNeeded];
  }
}

void na_view_constrain_fill(void* parentPtr, void* childPtr, double left, double top,
                            double right, double bottom) {
  NSView* parent = (__bridge NSView*)parentPtr;
  NSView* child = (__bridge NSView*)childPtr;
  if (!parent || !child || child.superview != parent) {
    return;
  }
  child.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [child.leadingAnchor constraintEqualToAnchor:parent.leadingAnchor constant:left],
    [child.topAnchor constraintEqualToAnchor:parent.topAnchor constant:top],
    [child.trailingAnchor constraintEqualToAnchor:parent.trailingAnchor constant:-right],
    [child.bottomAnchor constraintEqualToAnchor:parent.bottomAnchor constant:-bottom],
  ]];
}

void na_view_constrain_fill_superview(void* childPtr, double left, double top,
                                      double right, double bottom) {
  NSView* child = (__bridge NSView*)childPtr;
  if (!child || !child.superview) {
    return;
  }
  NSView* parent = child.superview;
  child.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [child.leadingAnchor constraintEqualToAnchor:parent.leadingAnchor constant:left],
    [child.topAnchor constraintEqualToAnchor:parent.topAnchor constant:top],
    [child.trailingAnchor constraintEqualToAnchor:parent.trailingAnchor constant:-right],
    [child.bottomAnchor constraintEqualToAnchor:parent.bottomAnchor constant:-bottom],
  ]];
}

void na_view_constrain_size(void* ptr, double width, double height) {
  NSView* view = (__bridge NSView*)ptr;
  if (!view) {
    return;
  }
  view.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [view.widthAnchor constraintEqualToConstant:width],
    [view.heightAnchor constraintEqualToConstant:height],
  ]];
}

void na_view_set_content_hugging(void* ptr, int orientation, double priority) {
  NSView* view = (__bridge NSView*)ptr;
  if (!view) {
    return;
  }
  NSLayoutConstraintOrientation nsOrientation =
      orientation == 1 ? NSLayoutConstraintOrientationVertical
                       : NSLayoutConstraintOrientationHorizontal;
  [view setContentHuggingPriority:(NSLayoutPriority)priority
                   forOrientation:nsOrientation];
}

void na_view_set_wants_layer(void* ptr, bool wants) {
  NSView* view = (__bridge NSView*)ptr;
  if (view) {
    view.wantsLayer = wants ? YES : NO;
  }
}

void na_view_set_corner_radius(void* ptr, double radius) {
  NSView* view = (__bridge NSView*)ptr;
  if (view) {
    view.wantsLayer = YES;
    view.layer.cornerRadius = radius;
    view.layer.masksToBounds = YES;
  }
}

static void apply_layer_color(CALayer* layer, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
  CGFloat red = r / 255.0;
  CGFloat green = g / 255.0;
  CGFloat blue = b / 255.0;
  CGFloat alpha = a / 255.0;
  CGColorRef color = CGColorCreateGenericRGB(red, green, blue, alpha);
  layer.backgroundColor = color;
  CFRelease(color);
}

void na_view_set_background_color(void* ptr, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
  NSView* view = (__bridge NSView*)ptr;
  if (view) {
    view.wantsLayer = YES;
    apply_layer_color(view.layer, r, g, b, a);
  }
}

void na_view_clear_background_color(void* ptr) {
  NSView* view = (__bridge NSView*)ptr;
  if (view) {
    view.wantsLayer = YES;
    view.layer.backgroundColor = NULL;
  }
}

void na_view_set_border(void* ptr, uint8_t r, uint8_t g, uint8_t b, uint8_t a, double width) {
  NSView* view = (__bridge NSView*)ptr;
  if (view) {
    view.wantsLayer = YES;
    CGFloat red = r / 255.0;
    CGFloat green = g / 255.0;
    CGFloat blue = b / 255.0;
    CGFloat alpha = a / 255.0;
    CGColorRef color = CGColorCreateGenericRGB(red, green, blue, alpha);
    view.layer.borderColor = color;
    CFRelease(color);
    view.layer.borderWidth = width;
  }
}

void na_view_measure(void* ptr, double maxWidth, double maxHeight, double* outW,
                     double* outH) {
  NSView* view = (__bridge NSView*)ptr;
  if (!view) {
    return;
  }
  NSSize fitting = [view fittingSize];
  double w = fitting.width;
  double h = fitting.height;
  if (w <= 0.0) {
    w = view.frame.size.width;
  }
  if (h <= 0.0) {
    h = view.frame.size.height;
  }
  if (outW) {
    *outW = w;
  }
  if (outH) {
    *outH = h;
  }
}

void na_view_set_drop_enabled(void* ptr, bool enabled, uint32_t widget_id) {
  NAPlainView* view = (__bridge NAPlainView*)ptr;
  if (view) {
    view.dropEnabled = enabled ? YES : NO;
    view.dropWidgetId = widget_id;
  }
}

void na_view_set_alpha(void* ptr, double alpha) {
  NSView* view = (__bridge NSView*)ptr;
  if (view) {
    [view setAlphaValue:(CGFloat)alpha];
  }
}

double na_view_get_alpha(void* ptr) {
  NSView* view = (__bridge NSView*)ptr;
  return view ? (double)view.alphaValue : 1.0;
}

void na_view_set_frame_callback(void* ptr, na_frame_changed_fn fn,
                                void* ctx) {
  NAPlainView* view = (__bridge NAPlainView*)ptr;
  if (view) {
    view.frameCallback = fn;
    view.frameCtx = ctx;
  }
}
