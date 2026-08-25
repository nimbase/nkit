#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "gui_common.h"

static const char kPaneConstraintsKey;

void* na_split_view_create(bool vertical) {
  NSSplitView* split = [[NSSplitView alloc] initWithFrame:NSMakeRect(0, 0, 300, 200)];
  split.vertical = vertical ? YES : NO;
  split.dividerStyle = NSSplitViewDividerStyleThin;
  split.translatesAutoresizingMaskIntoConstraints = NO;
  na_gui_register_view(split);
  return (__bridge void*)split;
}

void na_split_view_add_pane(void* ptr, void* child_ptr) {
  NSSplitView* split = (__bridge NSSplitView*)ptr;
  NSView* child = (__bridge NSView*)child_ptr;
  if (split && child) {
    child.translatesAutoresizingMaskIntoConstraints = NO;
    [split addArrangedSubview:child];
  }
}

void na_split_view_set_divider_thickness(void* ptr, double thickness) {
  NSSplitView* split = (__bridge NSSplitView*)ptr;
  if (split) {
    [split setValue:@(thickness) forKey:@"_dividerThickness"];
  }
}

// Positions the divider that follows the subview at `index`.
bool na_split_view_set_position(void* ptr, int index, double position) {
  NSSplitView* split = (__bridge NSSplitView*)ptr;
  if (!split || index < 0 ||
      index >= (int)split.arrangedSubviews.count - 1) {
    return false;
  }
  [split setPosition:position ofDividerAtIndex:index];
  return true;
}

double na_split_view_get_position(void* ptr, int index) {
  NSSplitView* split = (__bridge NSSplitView*)ptr;
  if (!split || index < 0 ||
      index >= (int)split.arrangedSubviews.count - 1) {
    return 0.0;
  }
  NSArray<NSView*>* subviews = split.subviews;
  // Divider i sits between subviews[i] and subviews[i+1]; report the max of
  // the leading subview edge.
  NSView* leading = subviews[index];
  if (split.vertical) {
    return NSMaxX(leading.frame);
  }
  return NSMaxY(leading.frame);
}

int na_split_view_pane_count(void* ptr) {
  NSSplitView* split = (__bridge NSSplitView*)ptr;
  return split ? (int)split.arrangedSubviews.count : 0;
}

void na_split_view_set_holding_priority(void* ptr, int index,
                                        double priority) {
  NSSplitView* split = (__bridge NSSplitView*)ptr;
  if (split && index >= 0 && index < (int)split.arrangedSubviews.count) {
    [split setHoldingPriority:(NSLayoutPriority)priority
            forSubviewAtIndex:(NSInteger)index];
  }
}

// Applies size bounds to a pane along the divider axis: width constraints
// for vertical splits, height constraints for horizontal ones. Constraints
// are stored as associated objects on the pane so repeated calls replace
// them. A bound <= 0 is treated as unconstrained.
void na_split_view_constrain_pane(void* ptr, int index,
                                  double min_w, double max_w,
                                  double min_h, double max_h) {
  NSSplitView* split = (__bridge NSSplitView*)ptr;
  if (!split || index < 0 || index >= (int)split.arrangedSubviews.count) {
    return;
  }
  NSView* pane = split.arrangedSubviews[index];
  NSArray* old = objc_getAssociatedObject(pane, &kPaneConstraintsKey);
  for (NSLayoutConstraint* c in old) {
    c.active = NO;
  }
  NSMutableArray* list = [NSMutableArray array];
  void (^add)(NSLayoutDimension*, double, BOOL) =
      ^(NSLayoutDimension* dim, double constant, BOOL isMax) {
    NSLayoutConstraint* c;
    if (isMax) {
      c = [dim constraintLessThanOrEqualToConstant:constant];
    } else {
      c = [dim constraintGreaterThanOrEqualToConstant:constant];
    }
    c.active = YES;
    [list addObject:c];
  };
  if (split.vertical) {
    if (min_w > 0) { add(pane.widthAnchor, min_w, NO); }
    if (max_w > 0) { add(pane.widthAnchor, max_w, YES); }
  } else {
    if (min_h > 0) { add(pane.heightAnchor, min_h, NO); }
    if (max_h > 0) { add(pane.heightAnchor, max_h, YES); }
  }
  objc_setAssociatedObject(pane, &kPaneConstraintsKey, list,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
