#import <Cocoa/Cocoa.h>
#import "gui_common.h"

void* na_scroll_create(void) {
  NSScrollView* scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 200, 200)];
  scroll.hasVerticalScroller = YES;
  scroll.autohidesScrollers = YES;
  scroll.borderType = NSNoBorder;
  scroll.drawsBackground = NO;
  na_gui_register_view(scroll);
  return (__bridge void*)scroll;
}

void na_scroll_free(void* ptr) {
  NSScrollView* scroll = (__bridge NSScrollView*)ptr;
  if (scroll) {
    [scroll removeFromSuperview];
    na_gui_unregister_view(scroll);
  }
}

void na_scroll_set_document(void* scrollPtr, void* docPtr) {
  NSScrollView* scroll = (__bridge NSScrollView*)scrollPtr;
  NSView* doc = (__bridge NSView*)docPtr;
  if (!scroll || !doc) {
    return;
  }
  doc.translatesAutoresizingMaskIntoConstraints = NO;
  scroll.documentView = doc;
}

void na_scroll_fit_width(void* ptr, double leftInset, double rightInset) {
  NSScrollView* scroll = (__bridge NSScrollView*)ptr;
  NSView* doc = scroll.documentView;
  if (!scroll || !doc) {
    return;
  }
  NSClipView* clip = scroll.contentView;
  [NSLayoutConstraint activateConstraints:@[
    [doc.leadingAnchor constraintEqualToAnchor:clip.leadingAnchor constant:leftInset],
    [doc.trailingAnchor constraintEqualToAnchor:clip.trailingAnchor constant:-rightInset],
  ]];
}

void na_scroll_set_has_vertical_bar(void* ptr, bool has) {
  NSScrollView* scroll = (__bridge NSScrollView*)ptr;
  if (scroll) {
    scroll.hasVerticalScroller = has ? YES : NO;
  }
}

void na_scroll_set_has_horizontal_bar(void* ptr, bool has) {
  NSScrollView* scroll = (__bridge NSScrollView*)ptr;
  if (scroll) {
    scroll.hasHorizontalScroller = has ? YES : NO;
  }
}

void na_scroll_set_border(void* ptr, bool bordered) {
  NSScrollView* scroll = (__bridge NSScrollView*)ptr;
  if (scroll) {
    scroll.borderType = bordered ? NSBezelBorder : NSNoBorder;
  }
}

void na_scroll_set_background(void* ptr, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
  NSScrollView* scroll = (__bridge NSScrollView*)ptr;
  if (scroll) {
    scroll.drawsBackground = YES;
    scroll.backgroundColor =
        [NSColor colorWithSRGBRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:a / 255.0];
  }
}
