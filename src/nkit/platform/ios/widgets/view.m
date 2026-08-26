#import "gui_common.h"

@interface NAPlainView : UIView
@property(nonatomic, copy) void (^frameCallback)(double w, double h, void* ctx);
@property(nonatomic, assign) void* frameCtx;
@end

@implementation NAPlainView

- (void)setFrame:(CGRect)frame {
  [super setFrame:frame];
  if (_frameCallback) {
    _frameCallback(frame.size.width, frame.size.height, _frameCtx);
  }
}

@end

static NAPlainView* plain_view(void* ptr) {
  return (__bridge NAPlainView*)ptr;
}

void* na_view_create(void) {
  NAPlainView* view = [[NAPlainView alloc] init];
  return (__bridge_retained void*)view;
}

void na_view_destroy(void* view_ptr) {
  if (!view_ptr) return;
  UIView* view = (__bridge_transfer UIView*)view_ptr;
  [view removeFromSuperview];
  na_gui_unregister_view(view);
}

void na_view_set_frame(void* view_ptr, double x, double y,
                       double w, double h) {
  UIView* view = (__bridge UIView*)view_ptr;
  if (view) {
    view.frame = CGRectMake(x, y, w, h);
  }
}

void na_view_get_frame(void* view_ptr, double* out_x, double* out_y,
                       double* out_w, double* out_h) {
  UIView* view = (__bridge UIView*)view_ptr;
  CGRect frame = view ? view.frame : CGRectZero;
  if (out_x) *out_x = frame.origin.x;
  if (out_y) *out_y = frame.origin.y;
  if (out_w) *out_w = frame.size.width;
  if (out_h) *out_h = frame.size.height;
}

void na_view_add_subview(void* parent_ptr, void* child_ptr) {
  UIView* parent = (__bridge UIView*)parent_ptr;
  UIView* child = (__bridge UIView*)child_ptr;
  if (parent && child) {
    [parent addSubview:child];
  }
}

void na_view_remove_from_parent(void* view_ptr) {
  UIView* view = (__bridge UIView*)view_ptr;
  if (view) {
    [view removeFromSuperview];
  }
}

void na_view_remove_all(void* parent_ptr) {
  UIView* parent = (__bridge UIView*)parent_ptr;
  if (!parent) {
    return;
  }
  for (UIView* sub in parent.subviews) {
    [sub removeFromSuperview];
  }
}

int na_view_subview_count(void* parent_ptr) {
  UIView* parent = (__bridge UIView*)parent_ptr;
  return parent ? (int)parent.subviews.count : 0;
}

void na_view_set_hidden(void* view_ptr, bool hidden) {
  UIView* view = (__bridge UIView*)view_ptr;
  if (view) {
    view.hidden = hidden ? YES : NO;
  }
}

bool na_view_is_hidden(void* view_ptr) {
  UIView* view = (__bridge UIView*)view_ptr;
  return view ? view.isHidden : false;
}

void na_view_layout(void* view_ptr) {
  // Auto Layout resolves on the next layout pass; nothing to force.
  (void)view_ptr;
}

// Constraint helpers: the layout solver computes frames itself on iOS,
// so fill/size constraints map onto explicit frames.

void na_view_constrain_fill(void* parent_ptr, void* child_ptr,
                            double left, double top,
                            double right, double bottom) {
  UIView* parent = (__bridge UIView*)parent_ptr;
  UIView* child = (__bridge UIView*)child_ptr;
  if (!parent || !child) {
    return;
  }
  child.frame = CGRectMake(left, top,
                           parent.bounds.size.width - left - right,
                           parent.bounds.size.height - top - bottom);
}

void na_view_constrain_fill_superview(void* child_ptr,
                                      double left, double top,
                                      double right, double bottom) {
  UIView* child = (__bridge UIView*)child_ptr;
  if (!child || !child.superview) {
    return;
  }
  na_view_constrain_fill((__bridge void*)child.superview, child_ptr,
                         left, top, right, bottom);
}

void na_view_constrain_size(void* view_ptr, double width, double height) {
  UIView* view = (__bridge UIView*)view_ptr;
  if (view) {
    CGRect f = view.frame;
    f.size.width = width;
    f.size.height = height;
    view.frame = f;
  }
}

void na_view_set_content_hugging(void* view_ptr, int orientation,
                                 double priority) {
  UIView* view = (__bridge UIView*)view_ptr;
  if (!view) {
    return;
  }
  UILayoutPriority p = (UILayoutPriority)priority;
  if (orientation == 0) {
    [view setContentHuggingPriority:p forAxis:UILayoutConstraintAxisHorizontal];
  } else {
    [view setContentHuggingPriority:p forAxis:UILayoutConstraintAxisVertical];
  }
}

void na_view_measure(void* view_ptr, double max_width, double max_height,
                     double* out_w, double* out_h) {
  UIView* view = (__bridge UIView*)view_ptr;
  CGSize fitting = CGSizeMake(max_width, max_height);
  CGSize size = view ? [view systemLayoutSizeFittingSize:fitting]
                     : CGSizeZero;
  if (out_w) *out_w = size.width;
  if (out_h) *out_h = size.height;
}

void na_view_set_background_color(void* view_ptr, uint8_t r, uint8_t g,
                                  uint8_t b, uint8_t a) {
  UIView* view = (__bridge UIView*)view_ptr;
  if (view) {
    view.backgroundColor =
        [UIColor colorWithRed:r / 255.0 green:g / 255.0
                          blue:b / 255.0 alpha:a / 255.0];
  }
}

void na_view_clear_background_color(void* view_ptr) {
  UIView* view = (__bridge UIView*)view_ptr;
  if (view) {
    view.backgroundColor = nil;
  }
}

void na_view_set_border(void* view_ptr, uint8_t r, uint8_t g, uint8_t b,
                        uint8_t a, double width) {
  UIView* view = (__bridge UIView*)view_ptr;
  if (!view) {
    return;
  }
  view.layer.borderColor =
      [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0
                      alpha:a / 255.0].CGColor;
  view.layer.borderWidth = width;
}

void na_view_set_corner_radius(void* view_ptr, double radius) {
  UIView* view = (__bridge UIView*)view_ptr;
  if (view) {
    view.layer.cornerRadius = radius;
    view.clipsToBounds = radius > 0.5;
  }
}

void na_view_set_alpha(void* view_ptr, double alpha) {
  UIView* view = (__bridge UIView*)view_ptr;
  if (view) {
    view.alpha = alpha;
  }
}

double na_view_get_alpha(void* view_ptr) {
  UIView* view = (__bridge UIView*)view_ptr;
  return view ? view.alpha : 1.0;
}

void na_view_set_wants_layer(void* view_ptr, bool wants) {
  // iOS views are always layer-backed.
  (void)view_ptr; (void)wants;
}

void na_view_set_tag(void* view_ptr, int tag) {
  UIView* view = (__bridge UIView*)view_ptr;
  if (view) {
    view.tag = tag;
  }
}

int na_view_get_tag(void* view_ptr) {
  UIView* view = (__bridge UIView*)view_ptr;
  return view ? (int)view.tag : 0;
}

void na_view_set_tooltip(void* view_ptr, const char* tooltip) {
  // Tooltips are a pointer-device concept; store via accessibility hint.
  UIView* view = (__bridge UIView*)view_ptr;
  if (view) {
    view.accessibilityHint =
        [NSString stringWithUTF8String:tooltip ?: ""];
  }
}

const char* na_view_get_tooltip(void* view_ptr) {
  extern char g_gui_text_buffer[2048];
  UIView* view = (__bridge UIView*)view_ptr;
  NSString* hint = view.accessibilityHint;
  g_gui_text_buffer[0] = '\0';
  if (hint.UTF8String) {
    strncpy(g_gui_text_buffer, hint.UTF8String,
            sizeof(g_gui_text_buffer) - 1);
  }
  return g_gui_text_buffer;
}

void na_view_set_frame_callback(void* view_ptr,
                                void (*fn)(double w, double h, void* ctx),
                                void* ctx) {
  NAPlainView* view = plain_view(view_ptr);
  if (view) {
    view.frameCtx = ctx;
    view.frameCallback = fn ? ^(double w, double h, void* c) { fn(w, h, c); }
                            : NULL;
  }
}

void na_view_set_drop_enabled(void* view_ptr, bool enabled,
                              uint32_t widget_id) {
  // Drag and drop arrives with the services phase.
  (void)view_ptr; (void)enabled; (void)widget_id;
}
