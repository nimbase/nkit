#import <Cocoa/Cocoa.h>
#import "gui_common.h"

typedef void (*na_datepicker_event_fn)(uint32_t widget_id, double unix_seconds, void* ctx);

static na_datepicker_event_fn g_datepicker_fn = NULL;
static void* g_datepicker_ctx = NULL;

static NSMutableDictionary<NSNumber*, NAGenericTarget*>* g_datepicker_targets = nil;

static void ensure_datepicker_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_datepicker_targets = [NSMutableDictionary dictionary];
  }
}

static void datepicker_action_thunk(uint32_t widget_id, void* ctx) {
  NSDatePicker* picker = (__bridge NSDatePicker*)ctx;
  if (!g_datepicker_fn || !picker) {
    return;
  }
  NSTimeInterval seconds = picker.dateValue.timeIntervalSince1970;
  g_datepicker_fn(widget_id, seconds, g_datepicker_ctx);
}

void na_datepicker_set_event_callback(na_datepicker_event_fn fn, void* ctx) {
  g_datepicker_fn = fn;
  g_datepicker_ctx = ctx;
}

void* na_datepicker_create(uint32_t widget_id, int style) {
  ensure_datepicker_tables();
  NSDatePicker* picker = [[NSDatePicker alloc] initWithFrame:NSMakeRect(0, 0, 160, 28)];
  switch (style) {
    case 1:
      picker.datePickerStyle = NSDatePickerStyleClockAndCalendar;
      break;
    default:
      picker.datePickerStyle = NSDatePickerStyleTextFieldAndStepper;
      break;
  }
  picker.datePickerElements = NSDatePickerElementFlagYearMonthDay;
  picker.dateValue = [NSDate date];
  NAGenericTarget* target = na_target_new(widget_id, datepicker_action_thunk, (__bridge void*)picker);
  g_datepicker_targets[@(widget_id)] = target;
  na_target_attach(picker, target);
  na_gui_register_view(picker);
  return (__bridge void*)picker;
}

void na_datepicker_free(uint32_t widget_id, void* ptr) {
  ensure_datepicker_tables();
  NSDatePicker* picker = (__bridge NSDatePicker*)ptr;
  if (picker) {
    [picker removeFromSuperview];
    na_gui_unregister_view(picker);
  }
  [g_datepicker_targets removeObjectForKey:@(widget_id)];
}

void na_datepicker_set_unix_seconds(void* ptr, double seconds) {
  NSDatePicker* picker = (__bridge NSDatePicker*)ptr;
  if (picker && seconds > 0) {
    picker.dateValue = [NSDate dateWithTimeIntervalSince1970:seconds];
  }
}

double na_datepicker_get_unix_seconds(void* ptr) {
  NSDatePicker* picker = (__bridge NSDatePicker*)ptr;
  return picker ? picker.dateValue.timeIntervalSince1970 : 0.0;
}
