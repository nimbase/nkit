#import <Cocoa/Cocoa.h>

typedef void (*na_theme_changed_fn)(void* ctx);

static na_theme_changed_fn g_theme_changed_fn = NULL;
static void* g_theme_changed_ctx = NULL;

static void theme_distributed_callback(CFNotificationCenterRef center, void* observer,
                                       CFStringRef name, const void* object,
                                       CFDictionaryRef userInfo) {
  if (g_theme_changed_fn) {
    g_theme_changed_fn(g_theme_changed_ctx);
  }
}

void na_theme_set_changed_callback(na_theme_changed_fn fn, void* ctx) {
  static BOOL observer_installed = NO;
  g_theme_changed_fn = fn;
  g_theme_changed_ctx = ctx;
  if (!observer_installed) {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDistributedCenter(), NULL,
                                    theme_distributed_callback,
                                    CFSTR("AppleInterfaceThemeChangedNotification"), NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    observer_installed = YES;
  }
}

bool na_theme_is_dark(void) {
  if (!NSApp) {
    return false;
  }
  NSAppearanceName name = [NSApp effectiveAppearance].name;
  return [name containsString:@"Dark"] ? true : false;
}

static NSColor* to_srgb(NSColor* color) {
  NSColorSpace* srgb = [NSColorSpace sRGBColorSpace];
  NSColor* converted = [color colorUsingColorSpace:srgb];
  return converted ? converted : color;
}

static void write_color(NSColor* raw, uint8_t* outR, uint8_t* outG, uint8_t* outB,
                        uint8_t* outA) {
  NSColor* c = to_srgb(raw);
  CGFloat r = 0, g = 0, b = 0, a = 0;
  [(NSColor*)c getRed:&r green:&g blue:&b alpha:&a];
  if (outR) *outR = (uint8_t)lround(r * 255.0);
  if (outG) *outG = (uint8_t)lround(g * 255.0);
  if (outB) *outB = (uint8_t)lround(b * 255.0);
  if (outA) *outA = (uint8_t)lround(a * 255.0);
}

#define NA_THEME_COLOR_GETTER(fnName, nsColorExpr)                          \
  void fnName(uint8_t* outR, uint8_t* outG, uint8_t* outB, uint8_t* outA) { \
    write_color(nsColorExpr, outR, outG, outB, outA);                       \
  }

NA_THEME_COLOR_GETTER(na_theme_accent_color, [NSColor controlAccentColor])
NA_THEME_COLOR_GETTER(na_theme_label_color, [NSColor labelColor])
NA_THEME_COLOR_GETTER(na_theme_secondary_label_color, [NSColor secondaryLabelColor])
NA_THEME_COLOR_GETTER(na_theme_tertiary_label_color, [NSColor tertiaryLabelColor])
NA_THEME_COLOR_GETTER(na_theme_quaternary_label_color, [NSColor quaternaryLabelColor])
NA_THEME_COLOR_GETTER(na_theme_placeholder_text_color, [NSColor placeholderTextColor])
NA_THEME_COLOR_GETTER(na_theme_control_text_color, [NSColor controlTextColor])
NA_THEME_COLOR_GETTER(na_theme_window_background_color, [NSColor windowBackgroundColor])
NA_THEME_COLOR_GETTER(na_theme_control_background_color, [NSColor controlBackgroundColor])
NA_THEME_COLOR_GETTER(na_theme_text_background_color, [NSColor textBackgroundColor])
NA_THEME_COLOR_GETTER(na_theme_separator_color, [NSColor separatorColor])
NA_THEME_COLOR_GETTER(na_theme_selected_content_color, [NSColor selectedContentBackgroundColor])
NA_THEME_COLOR_GETTER(na_theme_system_red, [NSColor systemRedColor])
NA_THEME_COLOR_GETTER(na_theme_system_green, [NSColor systemGreenColor])
NA_THEME_COLOR_GETTER(na_theme_system_blue, [NSColor systemBlueColor])
NA_THEME_COLOR_GETTER(na_theme_system_orange, [NSColor systemOrangeColor])
NA_THEME_COLOR_GETTER(na_theme_system_yellow, [NSColor systemYellowColor])
NA_THEME_COLOR_GETTER(na_theme_system_purple, [NSColor systemPurpleColor])
NA_THEME_COLOR_GETTER(na_theme_system_pink, [NSColor systemPinkColor])
NA_THEME_COLOR_GETTER(na_theme_system_teal, [NSColor systemTealColor])
NA_THEME_COLOR_GETTER(na_theme_system_indigo, [NSColor systemIndigoColor])
NA_THEME_COLOR_GETTER(na_theme_system_mint, [NSColor systemMintColor])
NA_THEME_COLOR_GETTER(na_theme_system_cyan, [NSColor systemCyanColor])
NA_THEME_COLOR_GETTER(na_theme_system_brown, [NSColor systemBrownColor])
NA_THEME_COLOR_GETTER(na_theme_system_gray, [NSColor systemGrayColor])
