#import <Cocoa/Cocoa.h>

static NSMutableDictionary<NSNumber*, NSAlert*>* g_alerts = nil;
static NSMutableDictionary<NSNumber*, NSNumber*>* g_alert_open = nil;
static int64_t g_next_dialog_handle = 1;

static void ensure_dialog_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_alerts = [NSMutableDictionary dictionary];
    g_alert_open = [NSMutableDictionary dictionary];
  }
}

int64_t na_dialog_create(const char* utf8_title, const char* utf8_message) {
  ensure_dialog_tables();
  @autoreleasepool {
    NSAlert* alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithUTF8String:utf8_title ? utf8_title : ""];
    alert.informativeText = [NSString stringWithUTF8String:utf8_message ? utf8_message : ""];
    alert.alertStyle = NSAlertStyleInformational;
    int64_t handle = g_next_dialog_handle++;
    g_alerts[@(handle)] = alert;
    g_alert_open[@(handle)] = @NO;
    return handle;
  }
}

void na_dialog_destroy(int64_t handle) {
  ensure_dialog_tables();
  [g_alerts removeObjectForKey:@(handle)];
  [g_alert_open removeObjectForKey:@(handle)];
}

void na_dialog_set_title(int64_t handle, const char* utf8_title) {
  NSAlert* alert = g_alerts[@(handle)];
  if (!alert || !utf8_title) {
    return;
  }
  alert.messageText = [NSString stringWithUTF8String:utf8_title];
}

void na_dialog_set_message(int64_t handle, const char* utf8_message) {
  NSAlert* alert = g_alerts[@(handle)];
  if (!alert || !utf8_message) {
    return;
  }
  alert.informativeText = [NSString stringWithUTF8String:utf8_message];
}

bool na_dialog_is_open(int64_t handle) {
  ensure_dialog_tables();
  NSNumber* open = g_alert_open[@(handle)];
  return open ? open.boolValue : false;
}

void na_dialog_run_modal(int64_t handle) {
  NSAlert* alert = g_alerts[@(handle)];
  if (!alert) {
    return;
  }
  g_alert_open[@(handle)] = @YES;
  @autoreleasepool {
    [alert runModal];
  }
  g_alert_open[@(handle)] = @NO;
}

bool na_dialog_close(int64_t handle) {
  ensure_dialog_tables();
  NSNumber* open = g_alert_open[@(handle)];
  if (!open || !open.boolValue) {
    return false;
  }
  g_alert_open[@(handle)] = @NO;
  return true;
}
