#import <Cocoa/Cocoa.h>
#import "gui_common.h"

typedef void (*na_hover_event_fn)(uint32_t widget_id, void* ctx);

static na_hover_event_fn g_hover_fn = NULL;
static void* g_hover_ctx = NULL;

static NSMutableDictionary<NSNumber*, NAGenericTarget*>* g_hover_targets = nil;

static void ensure_hover_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_hover_targets = [NSMutableDictionary dictionary];
  }
}

static void hover_action_thunk(uint32_t widget_id, void* ctx) {
  if (g_hover_fn) {
    g_hover_fn(widget_id, g_hover_ctx);
  }
}

void na_hover_set_event_callback(na_hover_event_fn fn, void* ctx) {
  g_hover_fn = fn;
  g_hover_ctx = ctx;
}

@interface NAHoverView : NSView
@property(nonatomic, assign) BOOL hoverHighlighted;
@property(nonatomic, assign) BOOL selectedState;
@property(nonatomic, strong) NSTrackingArea* trackingArea;
- (void)refreshBackground;
@end

@implementation NAHoverView

- (void)refreshBackground {
  NSColor* color = nil;
  if (_selectedState || _hoverHighlighted) {
    color = [NSColor controlAccentColor];
    if (_selectedState && !_hoverHighlighted) {
      color = [color colorWithAlphaComponent:0.85];
    } else {
      color = [color colorWithAlphaComponent:0.35];
    }
  }
  self.wantsLayer = YES;
  self.layer.backgroundColor = color.CGColor;
}

- (BOOL)acceptsFirstMouse:(NSEvent*)event {
  return YES;
}

- (BOOL)isFlipped {
  return YES;
}

- (void)updateTrackingAreas {
  [super updateTrackingAreas];
  if (_trackingArea) {
    [self removeTrackingArea:_trackingArea];
  }
  _trackingArea =
      [[NSTrackingArea alloc] initWithRect:self.bounds
                                   options:NSTrackingMouseEnteredAndExited |
                                           NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect
                                     owner:self
                                  userInfo:nil];
  [self addTrackingArea:_trackingArea];
}

- (void)mouseEntered:(NSEvent*)event {
  _hoverHighlighted = YES;
  [self refreshBackground];
}

- (void)mouseExited:(NSEvent*)event {
  _hoverHighlighted = NO;
  [self refreshBackground];
}

@end

void* na_hover_view_create(uint32_t widget_id) {
  ensure_hover_tables();
  NAHoverView* view = [[NAHoverView alloc] initWithFrame:NSMakeRect(0, 0, 200, 32)];
  view.wantsLayer = YES;
  view.layer.cornerRadius = 6.0;
  view.layer.masksToBounds = YES;

  NAGenericTarget* target = na_target_new(widget_id, hover_action_thunk, NULL);
  g_hover_targets[@(widget_id)] = target;

  NSClickGestureRecognizer* recognizer =
      [[NSClickGestureRecognizer alloc] initWithTarget:target action:@selector(fire:)];
  [view addGestureRecognizer:recognizer];

  na_gui_register_view(view);
  return (__bridge void*)view;
}

void na_hover_view_free(uint32_t widget_id, void* ptr) {
  ensure_hover_tables();
  NAHoverView* view = (__bridge NAHoverView*)ptr;
  if (view) {
    [view removeFromSuperview];
    na_gui_unregister_view(view);
  }
  [g_hover_targets removeObjectForKey:@(widget_id)];
}

void na_hover_view_fire(uint32_t widget_id) {
  ensure_hover_tables();
  NAGenericTarget* target = g_hover_targets[@(widget_id)];
  if (target) {
    [target fire:nil];
  }
}

void na_hover_view_set_selected(void* ptr, bool selected) {
  NAHoverView* view = (__bridge NAHoverView*)ptr;
  if (view) {
    view.selectedState = selected ? YES : NO;
    [view refreshBackground];
  }
}

bool na_hover_view_is_selected(void* ptr) {
  NAHoverView* view = (__bridge NAHoverView*)ptr;
  return view && view.selectedState == YES;
}
