#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "gui_common.h"

#define NA_STACK_ORIENTATION_HORIZONTAL 0
#define NA_STACK_ORIENTATION_VERTICAL 1

static char naStackFillCrossKey;
static char naChildFilledKey;

static BOOL na_stack_fills_cross_axis(NSStackView* stack) {
  NSNumber* flag = objc_getAssociatedObject(stack, &naStackFillCrossKey);
  return flag != nil && flag.boolValue == YES;
}

static void apply_cross_axis_fill(NSStackView* stack, NSView* child) {
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
  NSUserInterfaceLayoutOrientation nsOrientation =
      orientation == NA_STACK_ORIENTATION_VERTICAL ? NSUserInterfaceLayoutOrientationVertical
                                                    : NSUserInterfaceLayoutOrientationHorizontal;
  NSStackView* stack = [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
  stack.orientation = nsOrientation;
  stack.spacing = 8.0;
  stack.alignment = nsOrientation == NSUserInterfaceLayoutOrientationVertical
                        ? NSLayoutAttributeLeading
                        : NSLayoutAttributeTop;
  stack.translatesAutoresizingMaskIntoConstraints = NO;
  na_gui_register_view(stack);
  return (__bridge void*)stack;
}

void na_stack_free(void* ptr) {
  NSStackView* stack = (__bridge NSStackView*)ptr;
  if (stack) {
    [stack removeFromSuperview];
    na_gui_unregister_view(stack);
  }
}

void na_stack_set_spacing(void* ptr, double spacing) {
  NSStackView* stack = (__bridge NSStackView*)ptr;
  if (stack) {
    stack.spacing = spacing;
  }
}

void na_stack_set_padding(void* ptr, double left, double top, double right, double bottom) {
  NSStackView* stack = (__bridge NSStackView*)ptr;
  if (stack) {
    stack.edgeInsets = NSEdgeInsetsMake(top, left, bottom, right);
  }
}

#define NA_STACK_ALIGN_LEADING 0
#define NA_STACK_ALIGN_CENTER 1
#define NA_STACK_ALIGN_TRAILING 2

void na_stack_set_alignment(void* ptr, int alignment) {
  NSStackView* stack = (__bridge NSStackView*)ptr;
  if (!stack) {
    return;
  }
  switch (alignment) {
    case NA_STACK_ALIGN_CENTER:
      stack.alignment = NSLayoutAttributeCenterX;
      break;
    case NA_STACK_ALIGN_TRAILING:
      if (stack.orientation == NSUserInterfaceLayoutOrientationHorizontal) {
        stack.alignment = NSLayoutAttributeBottom;
      } else {
        stack.alignment = NSLayoutAttributeTrailing;
      }
      break;
    case NA_STACK_ALIGN_LEADING:
    default:
      if (stack.orientation == NSUserInterfaceLayoutOrientationHorizontal) {
        stack.alignment = NSLayoutAttributeTop;
      } else {
        stack.alignment = NSLayoutAttributeLeading;
      }
      break;
  }
}

void na_stack_add_arranged(void* stackPtr, void* childPtr) {
  NSStackView* stack = (__bridge NSStackView*)stackPtr;
  NSView* child = (__bridge NSView*)childPtr;
  if (stack && child) {
    child.translatesAutoresizingMaskIntoConstraints = NO;
    [stack addArrangedSubview:child];
    apply_cross_axis_fill(stack, child);
  }
}

void na_stack_insert_arranged(void* stackPtr, void* childPtr, int index) {
  NSStackView* stack = (__bridge NSStackView*)stackPtr;
  NSView* child = (__bridge NSView*)childPtr;
  if (stack && child) {
    child.translatesAutoresizingMaskIntoConstraints = NO;
    [stack insertArrangedSubview:child atIndex:(NSUInteger)index];
    apply_cross_axis_fill(stack, child);
  }
}

void na_stack_set_arranged_fill(void* stackPtr, bool fill) {
  NSStackView* stack = (__bridge NSStackView*)stackPtr;
  if (!stack) {
    return;
  }
  objc_setAssociatedObject(stack, &naStackFillCrossKey, @(fill),
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  if (fill) {
    for (NSView* child in stack.arrangedSubviews) {
      apply_cross_axis_fill(stack, child);
    }
  }
}

void na_stack_remove_arranged(void* stackPtr, void* childPtr) {
  NSStackView* stack = (__bridge NSStackView*)stackPtr;
  NSView* child = (__bridge NSView*)childPtr;
  if (stack && child) {
    [stack removeArrangedSubview:child];
    [child removeFromSuperview];
  }
}

int na_stack_arranged_count(void* stackPtr) {
  NSStackView* stack = (__bridge NSStackView*)stackPtr;
  return stack ? (int)stack.arrangedSubviews.count : 0;
}
