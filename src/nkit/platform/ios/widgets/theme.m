#import <UIKit/UIKit.h>

static void write_rgba(UIColor* color,
                       uint8_t* out_r, uint8_t* out_g,
                       uint8_t* out_b, uint8_t* out_a) {
  if (!color) {
    color = [UIColor clearColor];
  }
  // Resolve dynamic colors (light/dark) against the current traits.
  UITraitCollection* traits =
      [UIScreen mainScreen].traitCollection;
  UIColor* resolved = [color resolvedColorWithTraitCollection:traits];
  CGFloat r = 0, g = 0, b = 0, a = 1;
  if (![resolved getRed:&r green:&g blue:&b alpha:&a]) {
    CGFloat white = 1;
    [resolved getWhite:&white alpha:&a];
    r = g = b = white;
  }
  if (out_r) *out_r = (uint8_t)(r * 255.0 + 0.5);
  if (out_g) *out_g = (uint8_t)(g * 255.0 + 0.5);
  if (out_b) *out_b = (uint8_t)(b * 255.0 + 0.5);
  if (out_a) *out_a = (uint8_t)(a * 255.0 + 0.5);
}

bool na_theme_is_dark(void) {
  UITraitCollection* traits =
      [UIScreen mainScreen].traitCollection;
  return traits.userInterfaceStyle == UIUserInterfaceStyleDark;
}

#define THEME_GETTER(cname, expr)                                          \
  void cname(uint8_t* out_r, uint8_t* out_g, uint8_t* out_b,               \
             uint8_t* out_a) {                                             \
    write_rgba(expr, out_r, out_g, out_b, out_a);                          \
  }

THEME_GETTER(na_theme_accent_color, [UIColor systemBlueColor])
THEME_GETTER(na_theme_label_color, [UIColor labelColor])
THEME_GETTER(na_theme_secondary_label_color, [UIColor secondaryLabelColor])
THEME_GETTER(na_theme_tertiary_label_color, [UIColor tertiaryLabelColor])
THEME_GETTER(na_theme_quaternary_label_color, [UIColor quaternaryLabelColor])
THEME_GETTER(na_theme_placeholder_text_color, [UIColor placeholderTextColor])
THEME_GETTER(na_theme_control_text_color, [UIColor labelColor])
THEME_GETTER(na_theme_window_background_color, [UIColor systemBackgroundColor])
THEME_GETTER(na_theme_control_background_color,
             [UIColor secondarySystemBackgroundColor])
THEME_GETTER(na_theme_text_background_color, [UIColor systemBackgroundColor])
THEME_GETTER(na_theme_separator_color, [UIColor separatorColor])
THEME_GETTER(na_theme_selected_content_color,
             [UIColor tertiarySystemFillColor])

THEME_GETTER(na_theme_system_red, [UIColor systemRedColor])
THEME_GETTER(na_theme_system_green, [UIColor systemGreenColor])
THEME_GETTER(na_theme_system_blue, [UIColor systemBlueColor])
THEME_GETTER(na_theme_system_orange, [UIColor systemOrangeColor])
THEME_GETTER(na_theme_system_yellow, [UIColor systemYellowColor])
THEME_GETTER(na_theme_system_purple, [UIColor systemPurpleColor])
THEME_GETTER(na_theme_system_pink, [UIColor systemPinkColor])
THEME_GETTER(na_theme_system_teal, [UIColor systemTealColor])
THEME_GETTER(na_theme_system_indigo, [UIColor systemIndigoColor])
THEME_GETTER(na_theme_system_mint, [UIColor systemMintColor])
THEME_GETTER(na_theme_system_cyan, [UIColor systemCyanColor])
THEME_GETTER(na_theme_system_brown, [UIColor systemBrownColor])
THEME_GETTER(na_theme_system_gray, [UIColor systemGrayColor])

// Change callback is a no-op on iOS; appearance changes are handled
// by the system trait collection.
void na_theme_set_changed_callback(void (*fn)(void*), void* ctx) {
  (void)fn; (void)ctx;
}
