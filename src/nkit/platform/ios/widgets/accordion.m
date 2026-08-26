#import "gui_common.h"

typedef void (*na_accordion_event_fn)(uint32_t widget_id, bool expanded, void* ctx);

static na_accordion_event_fn g_accordion_event_fn = NULL;
static void* g_accordion_event_ctx = NULL;

@interface NAAccordionContainer : UIView
@property(nonatomic, strong) UIButton* headerButton;
@property(nonatomic, strong) UIView* contentArea;
@property(nonatomic, assign) BOOL expanded;
@property(nonatomic, assign) uint32_t widgetId;
@property(nonatomic, strong) NSLayoutConstraint* contentHeightConstraint;
- (void)toggleExpanded;
@end

@implementation NAAccordionContainer

- (void)toggleExpanded {
  _expanded = !_expanded;
  if (_contentHeightConstraint) {
    _contentHeightConstraint.active = NO;
  }
  if (_expanded) {
    _contentArea.hidden = NO;
    [_contentArea layoutIfNeeded];
    CGSize intrinsic = [_contentArea systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    _contentHeightConstraint = [_contentArea.heightAnchor constraintEqualToConstant:intrinsic.height];
    _contentHeightConstraint.active = YES;
  } else {
    _contentHeightConstraint = [_contentArea.heightAnchor constraintEqualToConstant:0];
    _contentHeightConstraint.active = YES;
  }
  [UIView animateWithDuration:0.25 animations:^{
    [self.superview layoutIfNeeded];
  }];
  if (g_accordion_event_fn) {
    g_accordion_event_fn(_widgetId, _expanded ? true : false, g_accordion_event_ctx);
  }
}

@end

static NSMutableDictionary<NSNumber*, NAAccordionContainer*>* g_accordion_containers = nil;

static void ensure_accordion_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_accordion_containers = [NSMutableDictionary dictionary];
  }
}

void na_accordion_set_event_callback(na_accordion_event_fn fn, void* ctx) {
  g_accordion_event_fn = fn;
  g_accordion_event_ctx = ctx;
}

void* na_accordion_create(uint32_t widget_id) {
  ensure_accordion_tables();
  NAAccordionContainer* container = [[NAAccordionContainer alloc] init];
  container.translatesAutoresizingMaskIntoConstraints = NO;
  container.expanded = NO;
  container.widgetId = widget_id;

  UIButton* header = [UIButton buttonWithType:UIButtonTypeSystem];
  header.translatesAutoresizingMaskIntoConstraints = NO;
  [header setTitle:@"▸" forState:UIControlStateNormal];
  header.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
  [header addTarget:container action:@selector(toggleExpanded)
      forControlEvents:UIControlEventTouchUpInside];
  container.headerButton = header;

  UIView* content = [[UIView alloc] init];
  content.translatesAutoresizingMaskIntoConstraints = NO;
  content.hidden = YES;
  container.contentArea = content;

  [container addSubview:header];
  [container addSubview:content];

  [NSLayoutConstraint activateConstraints:@[
    [header.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:8],
    [header.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-8],
    [header.topAnchor constraintEqualToAnchor:container.topAnchor constant:4],
    [header.heightAnchor constraintGreaterThanOrEqualToConstant:28],
    [content.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:4],
    [content.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
    [content.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
    [content.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
  ]];

  g_accordion_containers[@(widget_id)] = container;
  na_gui_register_view(container);
  return (__bridge_retained void*)container;
}

void na_accordion_free(uint32_t widget_id, void* ptr) {
  ensure_accordion_tables();
  if (!ptr) return;
  NAAccordionContainer* container = (__bridge_transfer NAAccordionContainer*)ptr;
  [container removeFromSuperview];
  na_gui_unregister_view(container);
  [g_accordion_containers removeObjectForKey:@(widget_id)];
}

void na_accordion_set_header(void* ptr, const char* title) {
  NAAccordionContainer* container = (__bridge NAAccordionContainer*)ptr;
  if (!container || !title) return;
  NSString* arrow = container.expanded ? @"▾ " : @"▸ ";
  NSString* full = [arrow stringByAppendingString:
      [NSString stringWithUTF8String:title]];
  [container.headerButton setTitle:full forState:UIControlStateNormal];
}

void na_accordion_set_content(void* ptr, void* content_ptr) {
  NAAccordionContainer* container = (__bridge NAAccordionContainer*)ptr;
  UIView* content = (__bridge UIView*)content_ptr;
  if (!container || !content) return;

  for (UIView* sub in container.contentArea.subviews) {
    [sub removeFromSuperview];
  }
  content.translatesAutoresizingMaskIntoConstraints = NO;
  [container.contentArea addSubview:content];
  [NSLayoutConstraint activateConstraints:@[
    [content.leadingAnchor constraintEqualToAnchor:container.contentArea.leadingAnchor],
    [content.trailingAnchor constraintEqualToAnchor:container.contentArea.trailingAnchor],
    [content.topAnchor constraintEqualToAnchor:container.contentArea.topAnchor],
    [content.bottomAnchor constraintEqualToAnchor:container.contentArea.bottomAnchor],
  ]];
}

void na_accordion_set_expanded(void* ptr, bool expanded) {
  NAAccordionContainer* container = (__bridge NAAccordionContainer*)ptr;
  if (!container) return;
  if (container.expanded == expanded) return;
  [container toggleExpanded];
}

bool na_accordion_is_expanded(void* ptr) {
  NAAccordionContainer* container = (__bridge NAAccordionContainer*)ptr;
  return container ? container.expanded : false;
}
