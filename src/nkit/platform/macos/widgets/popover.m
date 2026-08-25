#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

typedef void (*na_popover_close_fn)(int64_t handle, void* ctx);

static NSMutableDictionary<NSNumber*, NSPopover*>* g_popovers = nil;
static NSMutableDictionary<NSNumber*, NSView*>* g_popover_contents = nil;
static na_popover_close_fn g_popover_close_fn = NULL;
static int64_t g_next_popover_handle = 1;

static void ensure_popover_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_popovers = [NSMutableDictionary dictionary];
    g_popover_contents = [NSMutableDictionary dictionary];
  }
}

@interface NAPopoverDelegate : NSObject <NSPopoverDelegate>
@property(nonatomic, assign) int64_t handle;
@end

@implementation NAPopoverDelegate
- (void)popoverDidClose:(NSNotification*)notification {
  if (g_popover_close_fn) {
    g_popover_close_fn(_handle, NULL);
  }
}
@end

int64_t na_popover_create(void) {
  ensure_popover_tables();
  NSPopover* popover = [[NSPopover alloc] init];
  popover.behavior = NSPopoverBehaviorTransient;

  NSViewController* controller = [[NSViewController alloc] init];
  NSView* content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 240, 160)];
  content.wantsLayer = YES;
  controller.view = content;
  popover.contentViewController = controller;

  NAPopoverDelegate* delegate = [[NAPopoverDelegate alloc] init];
  delegate.handle = g_next_popover_handle;
  popover.delegate = delegate;
  objc_setAssociatedObject(popover, "na_delegate", delegate,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);

  int64_t handle = g_next_popover_handle++;
  g_popovers[@(handle)] = popover;
  g_popover_contents[@(handle)] = content;
  return handle;
}

void na_popover_destroy(int64_t handle) {
  ensure_popover_tables();
  NSPopover* popover = g_popovers[@(handle)];
  if (popover && popover.isShown) {
    [popover close];
  }
  [g_popovers removeObjectForKey:@(handle)];
  [g_popover_contents removeObjectForKey:@(handle)];
}

void* na_popover_content_view(int64_t handle) {
  ensure_popover_tables();
  return (__bridge void*)g_popover_contents[@(handle)];
}

void na_popover_set_size(int64_t handle, double width, double height) {
  ensure_popover_tables();
  NSView* content = g_popover_contents[@(handle)];
  if (content) {
    content.frame = NSMakeRect(0, 0, width, height);
  }
}

// edge: 0 = top, 1 = right, 2 = bottom, 3 = left (screen geometry names)
void na_popover_show(int64_t handle, void* anchor_view, int edge) {
  ensure_popover_tables();
  NSPopover* popover = g_popovers[@(handle)];
  NSView* anchor = (__bridge NSView*)anchor_view;
  if (!popover || !anchor) {
    return;
  }
  NSRectEdge rectEdge;
  switch (edge) {
    case 0: rectEdge = NSRectEdgeMaxY; break;
    case 1: rectEdge = NSRectEdgeMaxX; break;
    case 2: rectEdge = NSRectEdgeMinY; break;
    default: rectEdge = NSRectEdgeMinX; break;
  }
  [popover showRelativeToRect:anchor.bounds
                       ofView:anchor
                preferredEdge:rectEdge];
}

void na_popover_close(int64_t handle) {
  ensure_popover_tables();
  NSPopover* popover = g_popovers[@(handle)];
  if (popover) {
    [popover close];
  }
}

bool na_popover_is_shown(int64_t handle) {
  ensure_popover_tables();
  NSPopover* popover = g_popovers[@(handle)];
  return popover ? popover.isShown : false;
}

void na_popover_set_close_callback(na_popover_close_fn fn) {
  g_popover_close_fn = fn;
}
