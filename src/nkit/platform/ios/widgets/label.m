#import "gui_common.h"

void* na_label_create(void) {
  UILabel* label = [[UILabel alloc] init];
  label.textColor = [UIColor labelColor];
  return (__bridge_retained void*)label;
}

void na_label_free(void* view_ptr) {
  if (!view_ptr) return;
  UILabel* label = (__bridge_transfer UILabel*)view_ptr;
  [label removeFromSuperview];
}

void na_label_set_text(void* view_ptr, const char* text) {
  UILabel* label = (__bridge UILabel*)view_ptr;
  if (label) {
    label.text = [NSString stringWithUTF8String:text ?: ""];
  }
}

const char* na_label_get_text(void* view_ptr) {
  UILabel* label = (__bridge UILabel*)view_ptr;
  return na_gui_copy_string(label.text);
}

// Font weights mirror the AppKit shim's mapping:
// 0 light, 1 regular, 2 medium, 3 semibold, 4 bold, 5 heavy/black.

static CGFloat weight_to_scale(int weight) {
  switch (weight) {
    case 0: return UIFontWeightLight;
    case 2: return UIFontWeightMedium;
    case 3: return UIFontWeightSemibold;
    case 4: return UIFontWeightBold;
    case 5: return UIFontWeightBlack;
    default: return UIFontWeightRegular;
  }
}

static NSTextAlignment alignment_from_int(int alignment) {
  switch (alignment) {
    case 1: return NSTextAlignmentCenter;
    case 2: return NSTextAlignmentRight;
    default: return NSTextAlignmentLeft;
  }
}

void na_label_set_font_size(void* view_ptr, double size) {
  UILabel* label = (__bridge UILabel*)view_ptr;
  if (label) {
    label.font = [UIFont systemFontOfSize:size];
  }
}

void na_label_set_font_weight(void* view_ptr, int weight) {
  UILabel* label = (__bridge UILabel*)view_ptr;
  if (label) {
    CGFloat size = label.font.pointSize > 0 ? label.font.pointSize : 13.0;
    label.font = [UIFont systemFontOfSize:size weight:weight_to_scale(weight)];
  }
}

void na_label_set_alignment(void* view_ptr, int alignment) {
  UILabel* label = (__bridge UILabel*)view_ptr;
  if (label) {
    label.textAlignment = alignment_from_int(alignment);
  }
}

void na_label_set_text_color(void* view_ptr, uint8_t r, uint8_t g,
                             uint8_t b, uint8_t a) {
  UILabel* label = (__bridge UILabel*)view_ptr;
  if (label) {
    label.textColor =
        [UIColor colorWithRed:r / 255.0 green:g / 255.0
                          blue:b / 255.0 alpha:a / 255.0];
  }
}

void na_label_set_wraps(void* view_ptr, bool wraps, int max_lines) {
  UILabel* label = (__bridge UILabel*)view_ptr;
  if (!label) {
    return;
  }
  if (wraps) {
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.numberOfLines = max_lines > 0 ? max_lines : 0;
  } else {
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.numberOfLines = 1;
  }
}
