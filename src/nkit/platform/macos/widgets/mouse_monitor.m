#import <Cocoa/Cocoa.h>
#include <stdlib.h>

typedef void (*na_mouse_event_fn)(int kind, double x, double y,
                                  int click_count, void* ctx);

static na_mouse_event_fn g_mouse_fn = NULL;
static void* g_mouse_ctx = NULL;
static id g_global_token = nil;
static id g_local_token = nil;

static void dispatch_mouse(int kind, NSEvent* event) {
  if (g_mouse_fn) {
    NSPoint loc = event.locationInWindow;
    // Convert window coords to top-left screen coords.
    CGPoint screenPt = [NSEvent mouseLocation];
    (void)loc;
    g_mouse_fn(kind, screenPt.x,
               [[NSScreen screens] firstObject].frame.size.height - screenPt.y,
               (int)event.clickCount, g_mouse_ctx);
  }
}

bool na_mouse_start_monitor(bool global_only_own_app, na_mouse_event_fn fn,
                            void* ctx) {
  if (g_mouse_fn) {
    return false; // already running
  }
  g_mouse_fn = fn;
  g_mouse_ctx = ctx;

  NSEventMask mask = NSEventMaskMouseMoved | NSEventMaskLeftMouseDown |
                     NSEventMaskLeftMouseUp | NSEventMaskRightMouseDown |
                     NSEventMaskRightMouseUp | NSEventMaskOtherMouseDown |
                     NSEventMaskOtherMouseUp | NSEventMaskScrollWheel;

  if (global_only_own_app) {
    // Global monitor: system-wide, but macOS never delivers own-app events.
    g_global_token = [NSEvent addGlobalMonitorForEventsMatchingMask:mask
                                                            handler:^(NSEvent* event) {
      int kind = -1;
      switch (event.type) {
        case NSEventTypeMouseMoved: kind = 0; break;
        case NSEventTypeLeftMouseDown: kind = 1; break;
        case NSEventTypeLeftMouseUp: kind = 2; break;
        case NSEventTypeRightMouseDown: kind = 3; break;
        case NSEventTypeRightMouseUp: kind = 4; break;
        case NSEventTypeOtherMouseDown: kind = 5; break;
        case NSEventTypeOtherMouseUp: kind = 6; break;
        case NSEventTypeScrollWheel: kind = 7; break;
        default: break;
      }
      if (kind >= 0) {
        dispatch_mouse(kind, event);
      }
    }];
    return g_global_token != nil;
  }

  // Local monitor: receives events destined for our own application.
  g_local_token = [NSEvent addLocalMonitorForEventsMatchingMask:mask
                                                        handler:^NSEvent*(NSEvent* event) {
    int kind = -1;
    switch (event.type) {
      case NSEventTypeMouseMoved: kind = 0; break;
      case NSEventTypeLeftMouseDown: kind = 1; break;
      case NSEventTypeLeftMouseUp: kind = 2; break;
      case NSEventTypeRightMouseDown: kind = 3; break;
      case NSEventTypeRightMouseUp: kind = 4; break;
      case NSEventTypeOtherMouseDown: kind = 5; break;
      case NSEventTypeOtherMouseUp: kind = 6; break;
      case NSEventTypeScrollWheel: kind = 7; break;
      default: break;
    }
    if (kind >= 0) {
      dispatch_mouse(kind, event);
    }
    return event;
  }];
  return g_local_token != nil;
}

void na_mouse_stop_monitors(void) {
  if (g_global_token) {
    [NSEvent removeMonitor:g_global_token];
    g_global_token = nil;
  }
  if (g_local_token) {
    [NSEvent removeMonitor:g_local_token];
    g_local_token = nil;
  }
  g_mouse_fn = NULL;
  g_mouse_ctx = NULL;
}
