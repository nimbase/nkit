#import "gui_common.h"
#import <objc/runtime.h>

typedef void (*na_colorwell_event_fn)(uint32_t widget_id, void* ctx);

static na_colorwell_event_fn g_colorwell_fn = NULL;
static void* g_colorwell_ctx = NULL;

static void fire_colorwell(uint32_t widget_id) {
  if (g_colorwell_fn) {
    g_colorwell_fn(widget_id, g_colorwell_ctx);
  }
}

@interface NAColorWellTarget : NSObject
@end

@implementation NAColorWellTarget
- (void)fire:(id)sender {
  NSNumber* wid = objc_getAssociatedObject(sender, "na_colorwell_id");
  if (wid) {
    fire_colorwell(wid.unsignedIntValue);
  }
}
@end

static NAColorWellTarget* colorwell_target(void) {
  static NAColorWellTarget* target = nil;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    target = [[NAColorWellTarget alloc] init];
  });
  return target;
}

static void colorwell_store_color(void* view_ptr, uint8_t r, uint8_t g,
                                  uint8_t b, uint8_t a) {
  UIView* v = (__bridge UIView*)view_ptr;
  if (v) {
    objc_setAssociatedObject(
        v, "na_colorwell_rgba",
        @[ @(r), @(g), @(b), @(a) ], OBJC_ASSOCIATION_RETAIN);
  }
}

void* na_colorwell_create(uint32_t widget_id) {
  UIView* view = nil;
  if (@available(iOS 14.0, *)) {
    UIColorWell* well = [[UIColorWell alloc] init];
    well.selectedColor = [UIColor systemBlueColor];
    objc_setAssociatedObject(well, "na_colorwell_id", @(widget_id),
                             OBJC_ASSOCIATION_RETAIN);
    [well addTarget:colorwell_target()
             action:@selector(fire:)
   forControlEvents:UIControlEventValueChanged];
    view = well;
    colorwell_store_color((__bridge void*)well, 0, 122, 255, 255);
  } else {
    // Pre-14 fallback: a plain swatch view that still stores a color.
    UIView* swatch = [[UIView alloc] init];
    swatch.backgroundColor = [UIColor systemBlueColor];
    objc_setAssociatedObject(swatch, "na_colorwell_id", @(widget_id),
                             OBJC_ASSOCIATION_RETAIN);
    view = swatch;
    colorwell_store_color((__bridge void*)swatch, 0, 122, 255, 255);
  }
  return (__bridge_retained void*)view;
}

void na_colorwell_free(uint32_t widget_id, void* view_ptr) {
  (void)widget_id;
  if (!view_ptr) return;
  UIView* view = (__bridge_transfer UIView*)view_ptr;
  [view removeFromSuperview];
}

void na_colorwell_set_color(void* view_ptr, uint8_t r, uint8_t g, uint8_t b,
                            uint8_t a) {
  UIView* view = (__bridge UIView*)view_ptr;
  if (!view) return;
  UIColor* c = [UIColor colorWithRed:r / 255.0
                               green:g / 255.0
                                blue:b / 255.0
                               alpha:a / 255.0];
  if ([view isKindOfClass:[UIColorWell class]]) {
    ((UIColorWell*)view).selectedColor = c;
  } else {
    view.backgroundColor = c;
  }
  colorwell_store_color(view_ptr, r, g, b, a);
}

void na_colorwell_get_color(void* view_ptr, uint8_t* outR, uint8_t* outG,
                            uint8_t* outB, uint8_t* outA) {
  UIView* view = (__bridge UIView*)view_ptr;
  uint8_t r = 0, g = 122, b = 255, a = 255;
  if (view) {
    if ([view isKindOfClass:[UIColorWell class]]) {
      UIColor* c = ((UIColorWell*)view).selectedColor;
      CGFloat fr = 0, fg = 0, fb = 0, fa = 1;
      if (c && [c getRed:&fr green:&fg blue:&fb alpha:&fa]) {
        r = (uint8_t)(fr * 255.0);
        g = (uint8_t)(fg * 255.0);
        b = (uint8_t)(fb * 255.0);
        a = (uint8_t)(fa * 255.0);
      }
    } else {
      NSArray* stored = objc_getAssociatedObject(view, "na_colorwell_rgba");
      if (stored && stored.count == 4) {
        r = [stored[0] unsignedCharValue];
        g = [stored[1] unsignedCharValue];
        b = [stored[2] unsignedCharValue];
        a = [stored[3] unsignedCharValue];
      }
    }
  }
  if (outR) *outR = r;
  if (outG) *outG = g;
  if (outB) *outB = b;
  if (outA) *outA = a;
}

void na_colorwell_set_enabled(void* view_ptr, bool enabled) {
  UIView* view = (__bridge UIView*)view_ptr;
  if (view && [view isKindOfClass:[UIControl class]]) {
    ((UIControl*)view).enabled = enabled ? YES : NO;
  }
}

bool na_colorwell_is_enabled(void* view_ptr) {
  UIView* view = (__bridge UIView*)view_ptr;
  if (view && [view isKindOfClass:[UIControl class]]) {
    return ((UIControl*)view).enabled != NO;
  }
  return view != nil;
}

void na_colorwell_set_event_callback(na_colorwell_event_fn fn, void* ctx) {
  g_colorwell_fn = fn;
  g_colorwell_ctx = ctx;
}

void na_colorwell_fire(uint32_t widget_id) {
  fire_colorwell(widget_id);
}
