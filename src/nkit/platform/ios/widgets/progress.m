#import "gui_common.h"

void* na_progress_create(int style) {
  UIProgressView* pv = [[UIProgressView alloc]
      initWithProgressViewStyle:(style == 1 ?
          UIProgressViewStyleDefault : UIProgressViewStyleBar)];
  pv.progress = 0.0;
  return (__bridge_retained void*)pv;
}

void na_progress_free(void* ptr) {
  if (!ptr) return;
  UIProgressView* pv = (__bridge_transfer UIProgressView*)ptr;
  [pv removeFromSuperview];
}

void na_progress_set_value(void* ptr, double value) {
  UIProgressView* pv = (__bridge UIProgressView*)ptr;
  if (pv) pv.progress = (float)value;
}

double na_progress_get_value(void* ptr) {
  UIProgressView* pv = (__bridge UIProgressView*)ptr;
  return pv ? (double)pv.progress : 0.0;
}

void na_progress_set_indeterminate(void* ptr, bool indeterminate) {
  (void)ptr; (void)indeterminate;
}

bool na_progress_is_indeterminate(void* ptr) {
  (void)ptr; return false;
}
