#import "gui_common.h"

typedef void (*na_toast_dismiss_fn)(uint32_t toast_id, void* ctx);

static na_toast_dismiss_fn g_toast_dismiss_fn = NULL;
static void* g_toast_dismiss_ctx = NULL;
static NSMutableDictionary<NSNumber*, UIView*>* g_toast_views = nil;

static void ensure_toast_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_toast_views = [NSMutableDictionary dictionary];
  }
}

static void close_and_report(uint32_t toast_id) {
  UIView* view = g_toast_views[@(toast_id)];
  if (!view) return;
  [view removeFromSuperview];
  [g_toast_views removeObjectForKey:@(toast_id)];
  if (g_toast_dismiss_fn) {
    g_toast_dismiss_fn(toast_id, g_toast_dismiss_ctx);
  }
}

void na_toast_set_dismiss_callback(na_toast_dismiss_fn fn, void* ctx) {
  g_toast_dismiss_fn = fn;
  g_toast_dismiss_ctx = ctx;
}

uint32_t na_toast_show(const char* title, const char* message, double duration_ms,
                       double offset_y, double width) {
  ensure_toast_tables();
  static uint32_t next_toast_id = 0;
  next_toast_id += 1;
  uint32_t toast_id = next_toast_id;

  UIWindow* keyWindow = nil;
  for (UIWindow* w in UIApplication.sharedApplication.windows) {
    if (w.isKeyWindow) { keyWindow = w; break; }
  }
  if (!keyWindow) return toast_id;

  CGFloat panelWidth = width > 40 ? width : 300;
  CGFloat panelHeight = (message && strlen(message) > 0) ? 76 : 56;

  UIView* toast = [[UIView alloc] initWithFrame:
      CGRectMake(keyWindow.bounds.size.width - panelWidth - 20,
                 offset_y + 20, panelWidth, panelHeight)];
  toast.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
  toast.layer.cornerRadius = 12.0;
  toast.clipsToBounds = YES;
  toast.translatesAutoresizingMaskIntoConstraints = NO;

  UILabel* titleLabel = [[UILabel alloc] init];
  titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
  titleLabel.textColor = [UIColor whiteColor];
  titleLabel.text = [NSString stringWithUTF8String:title ?: ""];
  [toast addSubview:titleLabel];

  [NSLayoutConstraint activateConstraints:@[
    [titleLabel.leadingAnchor constraintEqualToAnchor:toast.leadingAnchor constant:14],
    [titleLabel.trailingAnchor constraintEqualToAnchor:toast.trailingAnchor constant:-14],
    [titleLabel.topAnchor constraintEqualToAnchor:toast.topAnchor constant:12],
  ]];

  UILabel* messageLabel = nil;
  if (message && strlen(message) > 0) {
    messageLabel = [[UILabel alloc] init];
    messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    messageLabel.font = [UIFont systemFontOfSize:12];
    messageLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
    messageLabel.numberOfLines = 3;
    messageLabel.lineBreakMode = NSLineBreakByWordWrapping;
    messageLabel.text = [NSString stringWithUTF8String:message];
    [toast addSubview:messageLabel];

    [NSLayoutConstraint activateConstraints:@[
      [messageLabel.leadingAnchor constraintEqualToAnchor:toast.leadingAnchor constant:14],
      [messageLabel.trailingAnchor constraintEqualToAnchor:toast.trailingAnchor constant:-14],
      [messageLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:2],
    ]];
  }

  toast.alpha = 0.0;
  toast.transform = CGAffineTransformMakeTranslation(panelWidth + 30, 0);
  [keyWindow addSubview:toast];

  g_toast_views[@(toast_id)] = toast;

  [UIView animateWithDuration:0.25
                        delay:0
                      options:UIViewAnimationOptionCurveEaseOut
                   animations:^{
    toast.alpha = 1.0;
    toast.transform = CGAffineTransformIdentity;
  } completion:nil];

  NSTimeInterval interval = duration_ms / 1000.0;
  if (interval < 0.5) {
    interval = 4.0;
  }

  uint32_t tid = toast_id;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(interval * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
    [UIView animateWithDuration:0.25
                     animations:^{
      toast.alpha = 0.0;
      toast.transform = CGAffineTransformMakeTranslation(panelWidth + 30, 0);
    } completion:^(BOOL finished) {
      (void)finished;
      close_and_report(tid);
    }];
  });

  return toast_id;
}

void na_toast_close(uint32_t toast_id) {
  ensure_toast_tables();
  UIView* view = g_toast_views[@(toast_id)];
  if (!view) return;
  [UIView animateWithDuration:0.2
                   animations:^{
    view.alpha = 0.0;
  } completion:^(BOOL finished) {
    (void)finished;
    close_and_report(toast_id);
  }];
}

int na_toast_active_count(void) {
  ensure_toast_tables();
  return (int)g_toast_views.count;
}
