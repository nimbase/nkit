#import "gui_common.h"

void* na_separator_create(int orientation) {
  UIView* sep = [[UIView alloc] init];
  sep.backgroundColor = [UIColor separatorColor];
  sep.translatesAutoresizingMaskIntoConstraints = NO;
  [sep addConstraint:[NSLayoutConstraint constraintWithItem:sep
                                                  attribute:NSLayoutAttributeHeight
                                                  relatedBy:NSLayoutRelationEqual
                                                     toItem:nil
                                                  attribute:NSLayoutAttributeNotAnAttribute
                                                 multiplier:1.0 constant:0.5]];
  return (__bridge_retained void*)sep;
}

void na_separator_free(void* view_ptr) {
  if (!view_ptr) return;
  UIView* sep = (__bridge_transfer UIView*)view_ptr;
  [sep removeFromSuperview];
}

void na_separator_set_thickness(void* view_ptr, double t) {
  UIView* sep = (__bridge UIView*)view_ptr;
  if (!sep) return;
  for (NSLayoutConstraint* c in sep.constraints) {
    if (c.firstAttribute == NSLayoutAttributeHeight) {
      c.constant = t;
      break;
    }
  }
}
