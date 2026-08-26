#import "gui_common.h"
#import <objc/runtime.h>

#define NA_STACK_ORIENTATION_HORIZONTAL 0
#define NA_STACK_ORIENTATION_VERTICAL 1

static char naStackFillCrossKey;
static char naChildFilledKey;

static BOOL na_stack_fills_cross_axis(UIStackView* stack) {
  NSNumber* flag = objc_getAssociatedObject(stack, &naStackFillCrossKey);
  return flag != nil && flag.boolValue == YES;
}

static void apply_cross_axis_fill(UIStackView* stack, UIView* child) {
  if (!na_stack_fills_cross_axis(stack)) {
    return;
  }
  if (objc_getAssociatedObject(child, &naChildFilledKey) != nil) {
    return;
  }
  objc_setAssociatedObject(child, &naChildFilledKey, @(YES),
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  [child.leadingAnchor constraintEqualToAnchor:stack.leadingAnchor].active = YES;
  [child.trailingAnchor constraintEqualToAnchor:stack.trailingAnchor].active = YES;
}

void* na_stack_create(int orientation) {
  UILayoutConstraintAxis axis =
      orientation == NA_STACK_ORIENTATION_VERTICAL
          ? UILayoutConstraintAxisVertical
          : UILayoutConstraintAxisHorizontal;
  UIStackView* stack = [[UIStackView alloc] init];
  stack.axis = axis;
  stack.spacing = 8.0;
  stack.alignment = axis == UILayoutConstraintAxisVertical
                        ? UIStackViewAlignmentLeading
                        : UIStackViewAlignmentTop;
  stack.translatesAutoresizingMaskIntoConstraints = NO;
  na_gui_register_view(stack);
  return (__bridge_retained void*)stack;
}

void na_stack_free(void* ptr) {
  if (!ptr) return;
  UIStackView* stack = (__bridge_transfer UIStackView*)ptr;
  [stack removeFromSuperview];
  na_gui_unregister_view(stack);
}

void na_stack_set_spacing(void* ptr, double spacing) {
  UIStackView* stack = (__bridge UIStackView*)ptr;
  if (stack) {
    stack.spacing = spacing;
  }
}

void na_stack_set_padding(void* ptr, double left, double top, double right, double bottom) {
  UIStackView* stack = (__bridge UIStackView*)ptr;
  if (stack) {
    stack.layoutMargins = UIEdgeInsetsMake(top, left, bottom, right);
    stack.layoutMarginsRelativeArrangement = YES;
  }
}

#define NA_STACK_ALIGN_LEADING 0
#define NA_STACK_ALIGN_CENTER 1
#define NA_STACK_ALIGN_TRAILING 2

void na_stack_set_alignment(void* ptr, int alignment) {
  UIStackView* stack = (__bridge UIStackView*)ptr;
  if (!stack) {
    return;
  }
  switch (alignment) {
    case NA_STACK_ALIGN_CENTER:
      stack.alignment = UIStackViewAlignmentCenter;
      break;
    case NA_STACK_ALIGN_TRAILING:
      if (stack.axis == UILayoutConstraintAxisHorizontal) {
        stack.alignment = UIStackViewAlignmentBottom;
      } else {
        stack.alignment = UIStackViewAlignmentTrailing;
      }
      break;
    case NA_STACK_ALIGN_LEADING:
    default:
      if (stack.axis == UILayoutConstraintAxisHorizontal) {
        stack.alignment = UIStackViewAlignmentTop;
      } else {
        stack.alignment = UIStackViewAlignmentLeading;
      }
      break;
  }
}

void na_stack_add_arranged(void* stackPtr, void* childPtr) {
  UIStackView* stack = (__bridge UIStackView*)stackPtr;
  UIView* child = (__bridge UIView*)childPtr;
  if (stack && child) {
    child.translatesAutoresizingMaskIntoConstraints = NO;
    [stack addArrangedSubview:child];
    apply_cross_axis_fill(stack, child);
  }
}

void na_stack_insert_arranged(void* stackPtr, void* childPtr, int index) {
  UIStackView* stack = (__bridge UIStackView*)stackPtr;
  UIView* child = (__bridge UIView*)childPtr;
  if (stack && child) {
    child.translatesAutoresizingMaskIntoConstraints = NO;
    [stack insertArrangedSubview:child atIndex:(NSUInteger)index];
    apply_cross_axis_fill(stack, child);
  }
}

void na_stack_set_arranged_fill(void* stackPtr, bool fill) {
  UIStackView* stack = (__bridge UIStackView*)stackPtr;
  if (!stack) {
    return;
  }
  objc_setAssociatedObject(stack, &naStackFillCrossKey, @(fill),
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  if (fill) {
    for (UIView* child in stack.arrangedSubviews) {
      apply_cross_axis_fill(stack, child);
    }
  }
}

void na_stack_remove_arranged(void* stackPtr, void* childPtr) {
  UIStackView* stack = (__bridge UIStackView*)stackPtr;
  UIView* child = (__bridge UIView*)childPtr;
  if (stack && child) {
    [stack removeArrangedSubview:child];
    [child removeFromSuperview];
  }
}

int na_stack_arranged_count(void* stackPtr) {
  UIStackView* stack = (__bridge UIStackView*)stackPtr;
  return stack ? (int)stack.arrangedSubviews.count : 0;
}
