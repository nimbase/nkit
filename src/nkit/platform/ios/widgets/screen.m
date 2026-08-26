#import <UIKit/UIKit.h>

static char s_name_buffer[2048];

static UIScreen* screen_for_index_or_id(int index_or_id) {
  // Display ids are synthesized as index + 1 on iOS.
  NSArray<UIScreen*>* screens = [UIScreen screens];
  if (screens.count == 0) {
    return [UIScreen mainScreen];
  }
  int index = index_or_id > 0 ? index_or_id - 1 : 0;
  if (index >= (int)screens.count) {
    index = 0;
  }
  return screens[index];
}

int na_screen_count(void) {
  NSInteger count = [UIScreen screens].count;
  return count > 0 ? (int)count : 1;
}

uint32_t na_screen_display_id(int index) {
  if (index < 0 || index >= na_screen_count()) {
    return 0;
  }
  return (uint32_t)(index + 1);
}

bool na_screen_is_primary(uint32_t display_id) {
  return display_id == 1;
}

const char* na_screen_get_name(uint32_t display_id) {
    UIScreen* screen = display_id == 0
      ? [UIScreen mainScreen]
      : screen_for_index_or_id((int)display_id);
  CGRect bounds = screen.bounds;
  snprintf(s_name_buffer, sizeof(s_name_buffer),
           "Screen %dx%d@%dx",
           (int)bounds.size.width, (int)bounds.size.height,
           (int)screen.scale);
  return s_name_buffer;
}

void na_screen_get_frame(uint32_t display_id,
                         double* out_x, double* out_y,
                         double* out_w, double* out_h) {
  UIScreen* screen = display_id == 0
      ? [UIScreen mainScreen]
      : screen_for_index_or_id((int)display_id);
  CGRect bounds = screen.bounds;
  if (out_x) *out_x = bounds.origin.x;
  if (out_y) *out_y = bounds.origin.y;
  if (out_w) *out_w = bounds.size.width;
  if (out_h) *out_h = bounds.size.height;
}

void na_screen_get_work_area(uint32_t display_id,
                             double* out_x, double* out_y,
                             double* out_w, double* out_h) {
  // Safe areas arrive with the layout phase; the full frame is the
  // best available approximation for now.
  na_screen_get_frame(display_id, out_x, out_y, out_w, out_h);
}

double na_screen_get_scale_factor(uint32_t display_id) {
  UIScreen* screen = display_id == 0
      ? [UIScreen mainScreen]
      : screen_for_index_or_id((int)display_id);
  return (double)screen.scale;
}

int na_screen_get_refresh_rate(uint32_t display_id) {
  (void)display_id;
  // UIScreen does not expose refresh rate; report the standard rate.
  return 60;
}
