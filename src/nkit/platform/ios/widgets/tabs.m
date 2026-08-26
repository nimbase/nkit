#import "gui_common.h"

typedef void (*na_tabs_event_fn)(uint32_t widget_id, int64_t index, void* ctx);

static na_tabs_event_fn g_tabs_event_fn = NULL;
static void* g_tabs_event_ctx = NULL;

@interface NATabsContainer : UIView
@property(nonatomic, strong) UISegmentedControl* segmented;
@property(nonatomic, strong) UIView* contentArea;
@property(nonatomic, strong) NSMutableArray<UIView*>* pages;
@property(nonatomic, assign) NSInteger selectedIndex;
@property(nonatomic, assign) uint32_t widgetId;
- (void)switchToPage:(NSInteger)index;
@end

@implementation NATabsContainer

- (void)switchToPage:(NSInteger)index {
  if (index < 0 || index >= (NSInteger)_pages.count) return;
  for (UIView* page in _pages) {
    page.hidden = YES;
  }
  _pages[index].hidden = NO;
  _selectedIndex = index;
  if (g_tabs_event_fn) {
    g_tabs_event_fn(_widgetId, (int64_t)index, g_tabs_event_ctx);
  }
}

- (void)valueChanged:(UISegmentedControl*)sender {
  [self switchToPage:sender.selectedSegmentIndex];
}

@end

static NSMutableDictionary<NSNumber*, NATabsContainer*>* g_tabs_containers = nil;

static void ensure_tabs_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_tabs_containers = [NSMutableDictionary dictionary];
  }
}

void na_tabs_set_event_callback(na_tabs_event_fn fn, void* ctx) {
  g_tabs_event_fn = fn;
  g_tabs_event_ctx = ctx;
}

void* na_tabs_create(uint32_t widget_id) {
  ensure_tabs_tables();
  NATabsContainer* container = [[NATabsContainer alloc] init];
  container.translatesAutoresizingMaskIntoConstraints = NO;
  container.pages = [NSMutableArray array];
  container.selectedIndex = -1;
  container.widgetId = widget_id;

  UISegmentedControl* sc = [[UISegmentedControl alloc] initWithItems:@[]];
  sc.translatesAutoresizingMaskIntoConstraints = NO;
  [sc addTarget:container action:@selector(valueChanged:)
      forControlEvents:UIControlEventValueChanged];
  container.segmented = sc;

  UIView* contentArea = [[UIView alloc] init];
  contentArea.translatesAutoresizingMaskIntoConstraints = NO;
  container.contentArea = contentArea;

  [container addSubview:sc];
  [container addSubview:contentArea];

  [NSLayoutConstraint activateConstraints:@[
    [sc.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:8],
    [sc.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-8],
    [sc.topAnchor constraintEqualToAnchor:container.topAnchor constant:8],
    [contentArea.topAnchor constraintEqualToAnchor:sc.bottomAnchor constant:8],
    [contentArea.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
    [contentArea.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
    [contentArea.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
  ]];

  g_tabs_containers[@(widget_id)] = container;
  na_gui_register_view(container);
  return (__bridge_retained void*)container;
}

void na_tabs_free(uint32_t widget_id, void* ptr) {
  ensure_tabs_tables();
  if (!ptr) return;
  NATabsContainer* container = (__bridge_transfer NATabsContainer*)ptr;
  [container removeFromSuperview];
  na_gui_unregister_view(container);
  [g_tabs_containers removeObjectForKey:@(widget_id)];
}

void na_tabs_add_page(void* ptr, const char* label, void* content_ptr) {
  NATabsContainer* container = (__bridge NATabsContainer*)ptr;
  UIView* content = (__bridge UIView*)content_ptr;
  if (!container || !content) return;

  [container.segmented insertSegmentWithTitle:
      [NSString stringWithUTF8String:label ?: ""]
                                     atIndex:container.segmented.numberOfSegments
                                    animated:NO];

  content.translatesAutoresizingMaskIntoConstraints = NO;
  [container.contentArea addSubview:content];
  [NSLayoutConstraint activateConstraints:@[
    [content.leadingAnchor constraintEqualToAnchor:container.contentArea.leadingAnchor],
    [content.trailingAnchor constraintEqualToAnchor:container.contentArea.trailingAnchor],
    [content.topAnchor constraintEqualToAnchor:container.contentArea.topAnchor],
    [content.bottomAnchor constraintEqualToAnchor:container.contentArea.bottomAnchor],
  ]];

  content.hidden = YES;
  [container.pages addObject:content];

  if (container.pages.count == 1) {
    container.segmented.selectedSegmentIndex = 0;
    [container switchToPage:0];
  }
}

void na_tabs_remove_page(void* ptr, int64_t index) {
  NATabsContainer* container = (__bridge NATabsContainer*)ptr;
  if (!container || index < 0 || index >= (int64_t)container.pages.count) return;

  UIView* page = container.pages[(NSInteger)index];
  [page removeFromSuperview];
  [container.pages removeObjectAtIndex:(NSInteger)index];
  [container.segmented removeSegmentAtIndex:(NSInteger)index animated:NO];

  if (container.selectedIndex == index) {
    container.selectedIndex = -1;
    if (container.pages.count > 0) {
      NSInteger newSel = index < (NSInteger)container.pages.count ? index : 0;
      container.segmented.selectedSegmentIndex = newSel;
      [container switchToPage:newSel];
    }
  } else if (container.selectedIndex > index) {
    container.selectedIndex -= 1;
  }
}

void na_tabs_set_selected(void* ptr, int64_t index) {
  NATabsContainer* container = (__bridge NATabsContainer*)ptr;
  if (!container) return;
  if (index >= 0 && index < (int64_t)container.segmented.numberOfSegments) {
    container.segmented.selectedSegmentIndex = (NSInteger)index;
    [container switchToPage:index];
  }
}

int64_t na_tabs_get_selected(void* ptr) {
  NATabsContainer* container = (__bridge NATabsContainer*)ptr;
  return container ? (int64_t)container.selectedIndex : -1;
}

int na_tabs_count(void* ptr) {
  NATabsContainer* container = (__bridge NATabsContainer*)ptr;
  return container ? (int)container.pages.count : 0;
}
