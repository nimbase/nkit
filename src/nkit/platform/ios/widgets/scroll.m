#import "gui_common.h"

void* na_scroll_create(void) {
  UIScrollView* scroll = [[UIScrollView alloc] init];
  scroll.clipsToBounds = YES;
  scroll.translatesAutoresizingMaskIntoConstraints = NO;
  na_gui_register_view(scroll);
  return (__bridge_retained void*)scroll;
}

void na_scroll_free(void* ptr) {
  if (!ptr) return;
  UIScrollView* scroll = (__bridge_transfer UIScrollView*)ptr;
  [scroll removeFromSuperview];
  na_gui_unregister_view(scroll);
}

void na_scroll_set_document(void* scrollPtr, void* docPtr) {
  UIScrollView* scroll = (__bridge UIScrollView*)scrollPtr;
  UIView* doc = (__bridge UIView*)docPtr;
  if (!scroll || !doc) {
    return;
  }
  doc.translatesAutoresizingMaskIntoConstraints = NO;
  [scroll addSubview:doc];
  [NSLayoutConstraint activateConstraints:@[
    [doc.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
    [doc.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
    [doc.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
    [doc.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
    [doc.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],
  ]];
}

void na_scroll_fit_width(void* ptr, double leftInset, double rightInset) {
  UIScrollView* scroll = (__bridge UIScrollView*)ptr;
  if (!scroll) {
    return;
  }
  UIView* doc = scroll.subviews.firstObject;
  if (!doc) {
    return;
  }
  [NSLayoutConstraint activateConstraints:@[
    [doc.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor
                                     constant:leftInset],
    [doc.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor
                                      constant:-rightInset],
  ]];
}

void na_scroll_set_has_vertical_bar(void* ptr, bool has) {
  // iOS uses momentum scrolling by default; vertical indicator is on by default.
  // We can toggle the indicator style.
  UIScrollView* scroll = (__bridge UIScrollView*)ptr;
  if (scroll) {
    scroll.showsVerticalScrollIndicator = has ? YES : NO;
  }
}

void na_scroll_set_has_horizontal_bar(void* ptr, bool has) {
  UIScrollView* scroll = (__bridge UIScrollView*)ptr;
  if (scroll) {
    scroll.showsHorizontalScrollIndicator = has ? YES : NO;
  }
}

void na_scroll_set_border(void* ptr, bool bordered) {
  UIScrollView* scroll = (__bridge UIScrollView*)ptr;
  if (scroll) {
    scroll.layer.borderWidth = bordered ? 1.0 : 0.0;
  }
}

void na_scroll_set_background(void* ptr, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
  UIScrollView* scroll = (__bridge UIScrollView*)ptr;
  if (scroll) {
    scroll.backgroundColor =
        [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:a / 255.0];
  }
}
