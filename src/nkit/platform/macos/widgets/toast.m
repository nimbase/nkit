#import <Cocoa/Cocoa.h>
#import "gui_common.h"
#import <QuartzCore/QuartzCore.h>

typedef void (*na_toast_dismiss_fn)(uint32_t toast_id, void* ctx);

static na_toast_dismiss_fn g_toast_dismiss_fn = NULL;
static void* g_toast_dismiss_ctx = NULL;
static NSMutableDictionary<NSNumber*, NSPanel*>* g_toast_panels = nil;

static void toast_timer_fired(NSTimer* timer);

@interface NSTimerTarget : NSObject
+ (instancetype)sharedTarget;
- (void)timerFired:(NSTimer*)timer;
@end

@implementation NSTimerTarget
+ (instancetype)sharedTarget {
  static NSTimerTarget* target = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    target = [[NSTimerTarget alloc] init];
  });
  return target;
}
- (void)timerFired:(NSTimer*)timer {
  toast_timer_fired(timer);
}
@end

static void ensure_toast_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_toast_panels = [NSMutableDictionary dictionary];
  }
}

void na_toast_set_dismiss_callback(na_toast_dismiss_fn fn, void* ctx) {
  g_toast_dismiss_fn = fn;
  g_toast_dismiss_ctx = ctx;
}

static void close_and_report(uint32_t toast_id) {
  NSPanel* panel = g_toast_panels[@(toast_id)];
  if (!panel) {
    return;
  }
  [panel orderOut:nil];
  [g_toast_panels removeObjectForKey:@(toast_id)];
  if (g_toast_dismiss_fn) {
    g_toast_dismiss_fn(toast_id, g_toast_dismiss_ctx);
  }
}

static void toast_timer_fired(NSTimer* timer) {
  NSNumber* idNumber = timer.userInfo;
  if (idNumber) {
    close_and_report(idNumber.unsignedIntValue);
  }
}

uint32_t na_toast_show(const char* title, const char* message, double duration_ms,
                       double offset_y, double width) {
  ensure_toast_tables();
  static uint32_t next_toast_id = 0;
  next_toast_id += 1;
  uint32_t toast_id = next_toast_id;

  NSScreen* screen = NSScreen.mainScreen;
  NSRect screenFrame = screen.visibleFrame;

  CGFloat panelWidth = width > 40 ? width : 300;
  CGFloat panelHeight = message && strlen(message) > 0 ? 76 : 56;

  NSPanel* panel =
      [[NSPanel alloc] initWithContentRect:NSMakeRect(screenFrame.origin.x + screenFrame.size.width - panelWidth - 20,
                                                      screenFrame.origin.y + offset_y + 20,
                                                      panelWidth, panelHeight)
                                 styleMask:NSWindowStyleMaskBorderless
                                   backing:NSBackingStoreBuffered
                                     defer:NO];
  panel.level = NSFloatingWindowLevel;
  panel.opaque = NO;
  panel.backgroundColor = [NSColor clearColor];
  panel.hasShadow = YES;
  panel.releasedWhenClosed = NO;
  panel.hidesOnDeactivate = NO;
  panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                             NSWindowCollectionBehaviorFullScreenAuxiliary;

  NSVisualEffectView* card = [[NSVisualEffectView alloc] initWithFrame:panel.contentView.bounds];
  card.material = NSVisualEffectMaterialHUDWindow;
  card.blendingMode = NSVisualEffectBlendingModeBehindWindow;
  card.state = NSVisualEffectStateActive;
  card.wantsLayer = YES;
  card.layer.cornerRadius = 12.0;
  card.layer.masksToBounds = YES;
  panel.contentView = card;

  NSStackView* stack = [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, panelWidth, panelHeight)];
  stack.orientation = NSUserInterfaceLayoutOrientationVertical;
  stack.spacing = 2.0;
  stack.edgeInsets = NSEdgeInsetsMake(12, 14, 12, 14);
  stack.translatesAutoresizingMaskIntoConstraints = NO;
  [card addSubview:stack];
  [NSLayoutConstraint activateConstraints:@[
    [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
    [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
    [stack.topAnchor constraintEqualToAnchor:card.topAnchor],
    [stack.bottomAnchor constraintLessThanOrEqualToAnchor:card.bottomAnchor],
  ]];

  NSTextField* titleLabel = [NSTextField labelWithString:
      title ? [NSString stringWithUTF8String:title] : @""];
  titleLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
  titleLabel.textColor = [NSColor labelColor];
  [stack addArrangedSubview:titleLabel];

  if (message && strlen(message) > 0) {
    NSTextField* messageLabel = [NSTextField labelWithString:
        [NSString stringWithUTF8String:message]];
    messageLabel.font = [NSFont systemFontOfSize:12];
    messageLabel.textColor = [NSColor secondaryLabelColor];
    messageLabel.maximumNumberOfLines = 3;
    messageLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [stack addArrangedSubview:messageLabel];
  }

  g_toast_panels[@(toast_id)] = panel;

  [panel makeKeyAndOrderFront:nil];
  panel.alphaValue = 0.0;
  NSRect finalFrame = panel.frame;
  NSRect startFrame = NSOffsetRect(finalFrame, panelWidth + 30, 0);
  [panel setFrame:startFrame display:YES];
  [NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
    context.duration = 0.25;
    context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    panel.animator.alphaValue = 1.0;
    [[panel animator] setFrame:finalFrame display:YES];
  } completionHandler:nil];

  NSTimeInterval interval = duration_ms / 1000.0;
  if (interval < 0.5) {
    interval = 4.0;
  }
  [NSTimer scheduledTimerWithTimeInterval:interval
                                   target:[NSTimerTarget sharedTarget]
                                 selector:@selector(timerFired:)
                                 userInfo:@(toast_id)
                                  repeats:NO];

  return toast_id;
}

void na_toast_close(uint32_t toast_id) {
  close_and_report(toast_id);
}

int na_toast_active_count(void) {
  ensure_toast_tables();
  return (int)g_toast_panels.count;
}
