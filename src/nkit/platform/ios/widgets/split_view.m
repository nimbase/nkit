#import "gui_common.h"

// iOS stub: split views use UISplitViewController which requires
// a fundamentally different lifecycle. Stub for now so the module compiles.

void* na_split_view_create(int vertical) {
  UIView* container = [[UIView alloc] init];
  container.translatesAutoresizingMaskIntoConstraints = NO;
  return (__bridge_retained void*)container;
}

void na_split_view_free(void* ptr) {
  if (!ptr) return;
  UIView* v = (__bridge_transfer UIView*)ptr;
  [v removeFromSuperview];
}

void na_split_view_add_pane(void* sv_ptr, void* child_ptr) {
  UIView* sv = (__bridge UIView*)sv_ptr;
  UIView* child = (__bridge UIView*)child_ptr;
  if (sv && child) {
    [sv addSubview:child];
    child.translatesAutoresizingMaskIntoConstraints = NO;
  }
}

void na_split_view_set_divider_thickness(void* sv_ptr, double t) {
  (void)sv_ptr; (void)t;
}

int na_split_view_set_position(void* sv_ptr, int index, double position) {
  (void)sv_ptr; (void)index; (void)position; return 0;
}

double na_split_view_get_position(void* sv_ptr, int index) {
  (void)sv_ptr; (void)index; return 0.0;
}

int na_split_view_pane_count(void* sv_ptr) {
  (void)sv_ptr; return 0;
}

void na_split_view_set_holding_priority(void* sv_ptr, int index, double priority) {
  (void)sv_ptr; (void)index; (void)priority;
}

void na_split_view_constrain_pane(void* sv_ptr, int index,
                                  double minW, double maxW,
                                  double minH, double maxH) {
  (void)sv_ptr; (void)index;
  (void)minW; (void)maxW; (void)minH; (void)maxH;
}
