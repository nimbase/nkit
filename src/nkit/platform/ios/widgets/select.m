#import "gui_common.h"

typedef void (*na_select_event_fn)(uint32_t widget_id, int64_t index, void* ctx);

static na_select_event_fn g_select_fn = NULL;
static void* g_select_ctx = NULL;

@interface NASelectContainer : UIView
@property(nonatomic, strong) UILabel* label;
@property(nonatomic, strong) UIButton* button;
@property(nonatomic, strong) NSMutableArray<NSString*>* options;
@property(nonatomic, assign) NSInteger selectedIndex;
@property(nonatomic, assign) uint32_t widgetId;
@end

@implementation NASelectContainer

- (void)showPicker {
  UIAlertController* alert = [UIAlertController
      alertControllerWithTitle:nil
                       message:nil
                preferredStyle:UIAlertControllerStyleActionSheet];

  for (NSUInteger i = 0; i < _options.count; i++) {
    NSString* title = _options[i];
    UIAlertAction* action = [UIAlertAction
        actionWithTitle:title
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction* _Nonnull a) {
                  [self selectOption:(NSInteger)i];
                }];
    [alert addAction:action];
  }

  UIAlertAction* cancel = [UIAlertAction
      actionWithTitle:@"Cancel"
                style:UIAlertActionStyleCancel
              handler:nil];
  [alert addAction:cancel];

  alert.popoverPresentationController.sourceView = _button;
  alert.popoverPresentationController.sourceRect = _button.bounds;

  UIResponder* responder = self;
  while (responder) {
    if ([responder isKindOfClass:[UIViewController class]]) {
      [(UIViewController*)responder presentViewController:alert
                                                animated:YES
                                              completion:nil];
      break;
    }
    responder = [responder nextResponder];
  }
}

- (void)selectOption:(NSInteger)index {
  _selectedIndex = index;
  if (index >= 0 && index < (NSInteger)_options.count) {
    _label.text = _options[index];
  } else {
    _label.text = @"";
  }
  if (g_select_fn) {
    g_select_fn(_widgetId, (int64_t)index, g_select_ctx);
  }
}

@end

static NSMutableDictionary<NSNumber*, NASelectContainer*>* g_select_containers = nil;

static void ensure_select_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_select_containers = [NSMutableDictionary dictionary];
  }
}

void na_select_set_event_callback(na_select_event_fn fn, void* ctx) {
  g_select_fn = fn;
  g_select_ctx = ctx;
}

void* na_select_create(uint32_t widget_id) {
  ensure_select_tables();
  NASelectContainer* container = [[NASelectContainer alloc] init];
  container.translatesAutoresizingMaskIntoConstraints = NO;
  container.options = [NSMutableArray array];
  container.selectedIndex = -1;
  container.widgetId = widget_id;

  UILabel* label = [[UILabel alloc] init];
  label.translatesAutoresizingMaskIntoConstraints = NO;
  label.text = @"";
  [container addSubview:label];
  container.label = label;

  UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
  button.translatesAutoresizingMaskIntoConstraints = NO;
  [button setTitle:@"▼" forState:UIControlStateNormal];
  [button addTarget:container
                action:@selector(showPicker)
      forControlEvents:UIControlEventTouchUpInside];
  [container addSubview:button];
  container.button = button;

  [NSLayoutConstraint activateConstraints:@[
    [label.leadingAnchor constraintEqualToAnchor:container.leadingAnchor
                                       constant:4],
    [label.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
    [button.leadingAnchor constraintEqualToAnchor:label.trailingAnchor
                                         constant:8],
    [button.trailingAnchor constraintEqualToAnchor:container.trailingAnchor
                                           constant:-4],
    [button.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
  ]];

  g_select_containers[@(widget_id)] = container;
  na_gui_register_view(container);
  return (__bridge_retained void*)container;
}

void na_select_free(uint32_t widget_id, void* ptr) {
  ensure_select_tables();
  if (!ptr) return;
  NASelectContainer* container = (__bridge_transfer NASelectContainer*)ptr;
  [container removeFromSuperview];
  na_gui_unregister_view(container);
  [g_select_containers removeObjectForKey:@(widget_id)];
}

void na_select_add_item(void* ptr, const char* title) {
  NASelectContainer* container = (__bridge NASelectContainer*)ptr;
  if (!container || !title) return;
  [container.options addObject:[NSString stringWithUTF8String:title]];
}

void na_select_clear(void* ptr) {
  NASelectContainer* container = (__bridge NASelectContainer*)ptr;
  if (!container) return;
  [container.options removeAllObjects];
  container.selectedIndex = -1;
  container.label.text = @"";
}

int na_select_count(void* ptr) {
  NASelectContainer* container = (__bridge NASelectContainer*)ptr;
  return container ? (int)container.options.count : 0;
}

int64_t na_select_selected(void* ptr) {
  NASelectContainer* container = (__bridge NASelectContainer*)ptr;
  return container ? (int64_t)container.selectedIndex : -1;
}

void na_select_choose(void* ptr, int64_t index) {
  NASelectContainer* container = (__bridge NASelectContainer*)ptr;
  if (container) {
    [container selectOption:(NSInteger)index];
  }
}

const char* na_select_selected_title(void* ptr) {
  NASelectContainer* container = (__bridge NASelectContainer*)ptr;
  if (!container || container.selectedIndex < 0 ||
      container.selectedIndex >= (NSInteger)container.options.count)
    return "";
  return na_gui_copy_string(container.options[container.selectedIndex]);
}
