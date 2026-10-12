#import <Cocoa/Cocoa.h>
#import "gui_common.h"

typedef void (*na_colorwell_event_fn)(uint32_t widget_id, void* ctx);

static na_colorwell_event_fn g_colorwell_fn = NULL;
static void* g_colorwell_ctx = NULL;

static NSMutableDictionary<NSNumber*, NAGenericTarget*>* g_colorwell_targets =
    nil;

static void ensure_colorwell_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_colorwell_targets = [NSMutableDictionary dictionary];
  }
}

static void colorwell_action_thunk(uint32_t widget_id, void* ctx) {
  if (g_colorwell_fn) {
    g_colorwell_fn(widget_id, g_colorwell_ctx);
  }
}

void na_colorwell_set_event_callback(na_colorwell_event_fn fn, void* ctx) {
  g_colorwell_fn = fn;
  g_colorwell_ctx = ctx;
}

void* na_colorwell_create(uint32_t widget_id) {
  ensure_colorwell_tables();
  NSColorWell* well =
      [[NSColorWell alloc] initWithFrame:NSMakeRect(0, 0, 60, 32)];
  NAGenericTarget* target =
      na_target_new(widget_id, colorwell_action_thunk, NULL);
  g_colorwell_targets[@(widget_id)] = target;
  na_target_attach(well, target);
  na_gui_register_view(well);
  return (__bridge void*)well;
}

void na_colorwell_free(uint32_t widget_id, void* ptr) {
  ensure_colorwell_tables();
  NSColorWell* well = (__bridge NSColorWell*)ptr;
  if (well) {
    [well removeFromSuperview];
    na_gui_unregister_view(well);
  }
  [g_colorwell_targets removeObjectForKey:@(widget_id)];
}

static NSColor* colorwell_srgb(NSColor* c) {
  if (!c) {
    return nil;
  }
  NSColor* converted =
      [c colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
  return converted ?: c;
}

void na_colorwell_set_color(void* ptr, uint8_t r, uint8_t g, uint8_t b,
                            uint8_t a) {
  NSColorWell* well = (__bridge NSColorWell*)ptr;
  if (well) {
    well.color = [NSColor colorWithSRGBRed:r / 255.0
                                     green:g / 255.0
                                      blue:b / 255.0
                                     alpha:a / 255.0];
  }
}

void na_colorwell_get_color(void* ptr, uint8_t* outR, uint8_t* outG,
                            uint8_t* outB, uint8_t* outA) {
  NSColorWell* well = (__bridge NSColorWell*)ptr;
  CGFloat r = 0, g = 0, b = 0, a = 1;
  if (well) {
    [colorwell_srgb(well.color) getRed:&r green:&g blue:&b alpha:&a];
  }
  if (outR) *outR = (uint8_t)(r * 255.0);
  if (outG) *outG = (uint8_t)(g * 255.0);
  if (outB) *outB = (uint8_t)(b * 255.0);
  if (outA) *outA = (uint8_t)(a * 255.0);
}

void na_colorwell_set_enabled(void* ptr, bool enabled) {
  NSColorWell* well = (__bridge NSColorWell*)ptr;
  if (well) {
    well.enabled = enabled ? YES : NO;
  }
}

bool na_colorwell_is_enabled(void* ptr) {
  NSColorWell* well = (__bridge NSColorWell*)ptr;
  return well ? well.enabled == YES : false;
}

void na_colorwell_fire(uint32_t widget_id) {
  ensure_colorwell_tables();
  NAGenericTarget* target = g_colorwell_targets[@(widget_id)];
  if (target) {
    [target fire:nil];
  }
}
