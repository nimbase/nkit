#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>

#define NA_KB_EVENT_PRESSED 0
#define NA_KB_EVENT_RELEASED 1
#define NA_KB_EVENT_MODIFIERS 2

typedef void (*na_kb_event_fn)(int kind, int keycode, unsigned int modifiers, void* ctx);

static na_kb_event_fn g_kb_fn = NULL;
static void* g_kb_ctx = NULL;
static CFMachPortRef g_event_tap = NULL;
static CFRunLoopSourceRef g_run_loop_source = NULL;

static unsigned int translate_flags(CGEventFlags flags) {
  unsigned int result = 0;
  if (flags & kCGEventFlagMaskShift) result |= 1u;
  if (flags & kCGEventFlagMaskControl) result |= 2u;
  if (flags & kCGEventFlagMaskAlternate) result |= 4u;
  if (flags & kCGEventFlagMaskCommand) result |= 8u;
  if (flags & kCGEventFlagMaskSecondaryFn) result |= 16u;
  if (flags & kCGEventFlagMaskAlphaShift) result |= 32u;
  if (flags & kCGEventFlagMaskNumericPad) result |= 64u;
  return result;
}

static CGEventRef kb_callback(CGEventTapProxy proxy,
                              CGEventType type,
                              CGEventRef event,
                              void* refcon) {
  if (!g_kb_fn) {
    return event;
  }
  long long keyCode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
  if (type == kCGEventKeyDown) {
    g_kb_fn(NA_KB_EVENT_PRESSED, (int)keyCode, 0, g_kb_ctx);
  } else if (type == kCGEventKeyUp) {
    g_kb_fn(NA_KB_EVENT_RELEASED, (int)keyCode, 0, g_kb_ctx);
  } else if (type == kCGEventFlagsChanged) {
    CGEventFlags flags = CGEventGetFlags(event);
    g_kb_fn(NA_KB_EVENT_MODIFIERS, 0, translate_flags(flags), g_kb_ctx);
  }
  return event;
}

bool na_keyboard_start(na_kb_event_fn fn, void* ctx) {
  if (g_event_tap != NULL) {
    return true;
  }
  g_kb_fn = fn;
  g_kb_ctx = ctx;
  CGEventMask mask = (1 << kCGEventKeyDown) | (1 << kCGEventKeyUp) |
                     (1 << kCGEventFlagsChanged);
  g_event_tap = CGEventTapCreate(kCGSessionEventTap,
                                 kCGHeadInsertEventTap,
                                 kCGEventTapOptionDefault,
                                 mask,
                                 kb_callback,
                                 NULL);
  if (g_event_tap == NULL) {
    return false;
  }
  g_run_loop_source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, g_event_tap, 0);
  CFRunLoopAddSource(CFRunLoopGetMain(), g_run_loop_source, kCFRunLoopCommonModes);
  CGEventTapEnable(g_event_tap, true);
  return true;
}

void na_keyboard_stop(void) {
  if (g_event_tap == NULL) {
    return;
  }
  CGEventTapEnable(g_event_tap, false);
  if (g_run_loop_source != NULL) {
    CFRunLoopRemoveSource(CFRunLoopGetMain(), g_run_loop_source, kCFRunLoopCommonModes);
    CFRelease(g_run_loop_source);
    g_run_loop_source = NULL;
  }
  CFRelease(g_event_tap);
  g_event_tap = NULL;
}

bool na_keyboard_is_running(void) {
  return g_event_tap != NULL;
}
