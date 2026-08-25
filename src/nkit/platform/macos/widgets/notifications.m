#import <Cocoa/Cocoa.h>
#import <UserNotifications/UserNotifications.h>
#include <stdlib.h>

typedef void (*na_notif_auth_fn)(int granted, void* ctx);
typedef void (*na_notif_response_fn)(uint32_t notification_id,
                                     const char* action,
                                     void* ctx);

static BOOL g_supported_checked = NO;
static BOOL g_supported = NO;
static na_notif_auth_fn g_auth_fn = NULL;
static na_notif_response_fn g_response_fn = NULL;
static void* g_response_ctx = NULL;

static NSString* kIdPrefix = @"na-";

static BOOL has_bundle_identity(void) {
  return [NSBundle mainBundle].bundleIdentifier != nil;
}

static UNUserNotificationCenter* safe_center(void) {
  if (!has_bundle_identity()) {
    g_supported = NO;
    return nil;
  }
  return [UNUserNotificationCenter currentNotificationCenter];
}

bool na_notifications_supported(void) {
  if (!g_supported_checked) {
    g_supported_checked = YES;
    g_supported = has_bundle_identity();
  }
  return g_supported == YES;
}

// 0 = not determined, 1 = denied, 2 = granted, -1 = unsupported
int na_notifications_auth_status(void) {
  UNUserNotificationCenter* center = safe_center();
  if (!center) {
    return -1;
  }
  __block int status = -1;
  dispatch_group_t group = dispatch_group_create();
  dispatch_group_enter(group);
  [center getNotificationSettingsWithCompletionHandler:
      ^(UNNotificationSettings* settings) {
    switch (settings.authorizationStatus) {
      case UNAuthorizationStatusNotDetermined: status = 0; break;
      case UNAuthorizationStatusDenied: status = 1; break;
      case UNAuthorizationStatusAuthorized:
      case UNAuthorizationStatusProvisional: status = 2; break;
      default: status = 0; break;
    }
    dispatch_group_leave(group);
  }];
  dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
  return status;
}

@interface NANotificationDelegate
    : NSObject <UNUserNotificationCenterDelegate>
@end

@implementation NANotificationDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter*)center
       willPresentNotification:(UNNotification*)notification
         withCompletionHandler:
             (void (^)(UNNotificationPresentationOptions))handler {
  if (@available(macOS 11.0, *)) {
    handler(UNNotificationPresentationOptionBanner |
            UNNotificationPresentationOptionSound);
  } else {
    handler(UNNotificationPresentationOptionAlert |
            UNNotificationPresentationOptionSound);
  }
}

- (void)userNotificationCenter:(UNUserNotificationCenter*)center
    didReceiveNotificationResponse:(UNNotificationResponse*)response
             withCompletionHandler:(void(^)(void))handler {
  NSString* ident = response.notification.request.identifier;
  uint32_t nid = 0;
  if ([ident hasPrefix:kIdPrefix]) {
    nid = (uint32_t)[[ident substringFromIndex:kIdPrefix.length] intValue];
  }
  if (g_response_fn && nid != 0) {
    g_response_fn(nid, response.actionIdentifier.UTF8String, g_response_ctx);
  }
  handler();
}

@end

void na_notifications_set_response_callback(na_notif_response_fn fn,
                                            void* ctx) {
  g_response_fn = fn;
  g_response_ctx = ctx;
  UNUserNotificationCenter* center = safe_center();
  if (center) {
    static NANotificationDelegate* delegate = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      delegate = [[NANotificationDelegate alloc] init];
      center.delegate = delegate;
    });
  }
}

void na_notifications_request_auth(na_notif_auth_fn fn, void* ctx) {
  UNUserNotificationCenter* center = safe_center();
  if (!center) {
    if (fn) {
      fn(0, ctx);
    }
    return;
  }
  [center requestAuthorizationWithOptions:
      (UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
                                completionHandler:^(BOOL granted,
                                                    NSError* error) {
    if (fn) {
      fn(granted ? 1 : 0, ctx);
    }
  }];
}

uint32_t na_notifications_show(const char* title, const char* subtitle,
                               const char* body, bool default_sound) {
  UNUserNotificationCenter* center = safe_center();
  if (!center) {
    return 0;
  }
  static uint32_t next_id = 1;
  uint32_t nid = next_id++;

  UNMutableNotificationContent* content =
      [[UNMutableNotificationContent alloc] init];
  if (title) {
    content.title = [NSString stringWithUTF8String:title];
  }
  if (subtitle) {
    content.subtitle = [NSString stringWithUTF8String:subtitle];
  }
  if (body) {
    content.body = [NSString stringWithUTF8String:body];
  }
  if (default_sound) {
    content.sound = [UNNotificationSound defaultSound];
  }

  UNNotificationRequest* request =
      [UNNotificationRequest requestWithIdentifier:
          [kIdPrefix stringByAppendingFormat:@"%u", nid]
                                       content:content
                                       trigger:nil];
  [center addNotificationRequest:request withCompletionHandler:nil];
  return nid;
}

void na_notifications_cancel(uint32_t id) {
  UNUserNotificationCenter* center = safe_center();
  if (!center) {
    return;
  }
  NSString* ident =
      [kIdPrefix stringByAppendingFormat:@"%u", id];
  [center removePendingNotificationRequestsWithIdentifiers:@[ident]];
  [center removeDeliveredNotificationsWithIdentifiers:@[ident]];
}
