#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <dispatch/dispatch.h>
#include <stdlib.h>
#include <stdbool.h>

typedef void (*na_app_fn)(void* ctx);
typedef void (*na_app_exit_fn)(int exit_code, void* ctx);
typedef void (*na_task_fn)(void* ctx);

extern void* na_menu_native_ptr(uint32_t menu_id);

static uint32_t g_dock_menu_id = 0;

static struct {
  void* ctx;
  na_app_fn on_started;
  na_app_fn on_activated;
  na_app_fn on_deactivated;
  na_app_fn on_quit_requested;
  na_app_exit_fn on_exiting;
} g_app_callbacks = {NULL, NULL, NULL, NULL, NULL, NULL};

@interface NAAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation NAAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)notification {
  @autoreleasepool {
    if (g_app_callbacks.on_started) {
      g_app_callbacks.on_started(g_app_callbacks.ctx);
    }
  }
}

- (void)applicationDidBecomeActive:(NSNotification*)notification {
  @autoreleasepool {
    if (g_app_callbacks.on_activated) {
      g_app_callbacks.on_activated(g_app_callbacks.ctx);
    }
  }
}

- (void)applicationDidResignActive:(NSNotification*)notification {
  @autoreleasepool {
    if (g_app_callbacks.on_deactivated) {
      g_app_callbacks.on_deactivated(g_app_callbacks.ctx);
    }
  }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication*)sender {
  @autoreleasepool {
    if (g_app_callbacks.on_quit_requested) {
      g_app_callbacks.on_quit_requested(g_app_callbacks.ctx);
    }
  }
  return NSTerminateNow;
}

- (void)applicationWillTerminate:(NSNotification*)notification {
  @autoreleasepool {
    if (g_app_callbacks.on_exiting) {
      g_app_callbacks.on_exiting(0, g_app_callbacks.ctx);
    }
  }
}

- (NSMenu*)applicationDockMenu:(NSApplication*)sender {
  if (g_dock_menu_id == 0) {
    return nil;
  }
  return (__bridge NSMenu*)na_menu_native_ptr(g_dock_menu_id);
}

@end

static NAAppDelegate* g_delegate = nil;

bool na_app_init(void) {
  if (![NSThread isMainThread]) {
    return false;
  }
  NSApplication* app = [NSApplication sharedApplication];
  if (!app) {
    return false;
  }
  [app setActivationPolicy:NSApplicationActivationPolicyRegular];
  if (!g_delegate) {
    g_delegate = [[NAAppDelegate alloc] init];
    [app setDelegate:g_delegate];
  }
  return true;
}

int na_app_run(void) {
  [NSApp run];
  return 0;
}

void na_app_quit(void) {
  [NSApp terminate:nil];
}

void na_app_stop(void) {
  [NSApp stop:nil];
  NSEvent* wake = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
                                     location:NSMakePoint(0, 0)
                                modifierFlags:0
                                    timestamp:0
                                 windowNumber:0
                                      context:nil
                                      subtype:0
                                        data1:0
                                        data2:0];
  [NSApp postEvent:wake atStart:YES];
}

extern void* na_menu_native_ptr(uint32_t menu_id);

void na_app_set_dock_menu(uint32_t menu_id) {
  g_dock_menu_id = menu_id;
}

uint32_t na_app_dock_menu(void) {
  return g_dock_menu_id;
}

bool na_app_set_icon(const char* utf8_path) {
  if (!utf8_path || !utf8_path[0]) {
    return false;
  }
  NSString* path = [NSString stringWithUTF8String:utf8_path];
  NSImage* icon = [[NSImage alloc] initWithContentsOfFile:path];
  if (!icon) {
    return false;
  }
  [NSApp setApplicationIconImage:icon];
  return true;
}

bool na_app_set_dock_icon_visible(bool visible) {
  NSApplicationActivationPolicy policy = visible
      ? NSApplicationActivationPolicyRegular
      : NSApplicationActivationPolicyAccessory;
  [NSApp setActivationPolicy:policy];
  return true;
}

void na_app_set_callbacks(void* ctx,
                          na_app_fn on_started,
                          na_app_fn on_activated,
                          na_app_fn on_deactivated,
                          na_app_fn on_quit_requested,
                          na_app_exit_fn on_exiting) {
  g_app_callbacks.ctx = ctx;
  g_app_callbacks.on_started = on_started;
  g_app_callbacks.on_activated = on_activated;
  g_app_callbacks.on_deactivated = on_deactivated;
  g_app_callbacks.on_quit_requested = on_quit_requested;
  g_app_callbacks.on_exiting = on_exiting;
}

bool na_is_main_thread(void) {
  return [NSThread isMainThread] ? true : false;
}

typedef struct {
  na_task_fn fn;
  void* ctx;
} NATask;

void na_dispatch_main(na_task_fn fn, void* ctx) {
  if (!fn) {
    return;
  }
  NATask* task = (NATask*)malloc(sizeof(NATask));
  task->fn = fn;
  task->ctx = ctx;
  dispatch_async(dispatch_get_main_queue(), ^{
    task->fn(task->ctx);
    free(task);
  });
}

void na_dispatch_main_after(int delay_ms, na_task_fn fn, void* ctx) {
  if (!fn) {
    return;
  }
  NATask* task = (NATask*)malloc(sizeof(NATask));
  task->fn = fn;
  task->ctx = ctx;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)delay_ms * NSEC_PER_MSEC),
                 dispatch_get_main_queue(), ^{
    task->fn(task->ctx);
    free(task);
  });
}

bool na_run_main_loop_for(int timeout_ms) {
  if (![NSThread isMainThread]) {
    return false;
  }
  CFRunLoopRunInMode(kCFRunLoopDefaultMode, timeout_ms / 1000.0, false);
  return true;
}
