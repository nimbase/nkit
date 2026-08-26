#import "gui_common.h"

typedef void (*na_datepicker_event_fn)(uint32_t widget_id, double unix_seconds, void* ctx);

static na_datepicker_event_fn g_datepicker_fn = NULL;
static void* g_datepicker_ctx = NULL;

@interface NADatepickerTarget : NSObject
@property(nonatomic, assign) uint32_t widgetId;
@end

static NSMutableDictionary<NSNumber*, NADatepickerTarget*>* g_datepicker_targets = nil;

@implementation NADatepickerTarget
- (void)valueChanged:(UIDatePicker*)sender {
  if (g_datepicker_fn) {
    NSTimeInterval seconds = sender.date.timeIntervalSince1970;
    g_datepicker_fn(self.widgetId, seconds, g_datepicker_ctx);
  }
}
@end

static void ensure_datepicker_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_datepicker_targets = [NSMutableDictionary dictionary];
  }
}

void na_datepicker_set_event_callback(na_datepicker_event_fn fn, void* ctx) {
  g_datepicker_fn = fn;
  g_datepicker_ctx = ctx;
}

void* na_datepicker_create(uint32_t widget_id, int style) {
  ensure_datepicker_tables();
  UIDatePicker* picker = [[UIDatePicker alloc] init];
  picker.translatesAutoresizingMaskIntoConstraints = NO;
  picker.datePickerMode = UIDatePickerModeDate;
  picker.date = [NSDate date];

  switch (style) {
    case 1:
      picker.preferredDatePickerStyle = UIDatePickerStyleCompact;
      break;
    case 2:
      picker.preferredDatePickerStyle = UIDatePickerStyleInline;
      break;
    default:
      picker.preferredDatePickerStyle = UIDatePickerStyleWheels;
      break;
  }

  NADatepickerTarget* target = [[NADatepickerTarget alloc] init];
  target.widgetId = widget_id;
  g_datepicker_targets[@(widget_id)] = target;

  [picker addTarget:target
             action:@selector(valueChanged:)
   forControlEvents:UIControlEventValueChanged];

  na_gui_register_view(picker);
  return (__bridge_retained void*)picker;
}

void na_datepicker_free(uint32_t widget_id, void* ptr) {
  ensure_datepicker_tables();
  if (!ptr) return;
  UIDatePicker* picker = (__bridge_transfer UIDatePicker*)ptr;
  [picker removeFromSuperview];
  na_gui_unregister_view(picker);
  [g_datepicker_targets removeObjectForKey:@(widget_id)];
}

void na_datepicker_set_unix_seconds(void* ptr, double seconds) {
  UIDatePicker* picker = (__bridge UIDatePicker*)ptr;
  if (picker && seconds > 0) {
    picker.date = [NSDate dateWithTimeIntervalSince1970:seconds];
  }
}

double na_datepicker_get_unix_seconds(void* ptr) {
  UIDatePicker* picker = (__bridge UIDatePicker*)ptr;
  return picker ? picker.date.timeIntervalSince1970 : 0.0;
}

void na_datepicker_set_mode(void* ptr, int mode) {
  UIDatePicker* picker = (__bridge UIDatePicker*)ptr;
  if (!picker) return;
  switch (mode) {
    case 1:
      picker.datePickerMode = UIDatePickerModeTime;
      break;
    case 2:
      picker.datePickerMode = UIDatePickerModeDateAndTime;
      break;
    case 3:
      picker.datePickerMode = UIDatePickerModeCountDownTimer;
      break;
    default:
      picker.datePickerMode = UIDatePickerModeDate;
      break;
  }
}
