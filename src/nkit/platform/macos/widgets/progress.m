#import <Cocoa/Cocoa.h>
#import "gui_common.h"

#define NA_PROGRESS_STYLE_BAR 0
#define NA_PROGRESS_STYLE_SPINNER 1

void* na_progress_create(int style) {
  NSProgressIndicator* progress = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 160, 20)];
  if (style == NA_PROGRESS_STYLE_SPINNER) {
    progress.minValue = 0.0;
    progress.maxValue = 100.0;
    [progress setIndeterminate:YES];
    [progress sizeToFit];
    [progress startAnimation:nil];
  } else {
    [progress setIndeterminate:NO];
    progress.doubleValue = 0.0;
  }
  na_gui_register_view(progress);
  return (__bridge void*)progress;
}

void na_progress_free(void* ptr) {
  NSProgressIndicator* progress = (__bridge NSProgressIndicator*)ptr;
  if (progress) {
    [progress stopAnimation:nil];
    [progress removeFromSuperview];
    na_gui_unregister_view(progress);
  }
}

void na_progress_set_value(void* ptr, double value) {
  NSProgressIndicator* progress = (__bridge NSProgressIndicator*)ptr;
  if (progress && !progress.isIndeterminate) {
    progress.doubleValue = value;
  }
}

double na_progress_get_value(void* ptr) {
  NSProgressIndicator* progress = (__bridge NSProgressIndicator*)ptr;
  return progress ? progress.doubleValue : 0.0;
}

void na_progress_set_indeterminate(void* ptr, bool indeterminate) {
  NSProgressIndicator* progress = (__bridge NSProgressIndicator*)ptr;
  BOOL currentIndeterminate = progress.indeterminate;
  if (!progress || currentIndeterminate == (indeterminate ? YES : NO)) {
    return;
  }
  [progress setIndeterminate:indeterminate ? YES : NO];
  if (indeterminate) {
    [progress startAnimation:nil];
  }
}

bool na_progress_is_indeterminate(void* ptr) {
  NSProgressIndicator* progress = (__bridge NSProgressIndicator*)ptr;
  return progress && progress.indeterminate == YES;
}
