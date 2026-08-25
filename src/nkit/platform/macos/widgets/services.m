#import <Cocoa/Cocoa.h>
#import <ServiceManagement/SMAppService.h>
#include <string.h>

static char g_services_buffer[1024];

static NSString* plist_string(NSString* key) {
  id value = [[NSBundle mainBundle] objectForInfoDictionaryKey:key];
  return [value isKindOfClass:[NSString class]] ? (NSString*)value : nil;
}

static const char* info_from_string(NSString* value) {
  g_services_buffer[0] = '\0';
  if (!value) {
    return g_services_buffer;
  }
  const char* utf8 = value.UTF8String;
  if (utf8) {
    strncpy(g_services_buffer, utf8, sizeof(g_services_buffer) - 1);
    g_services_buffer[sizeof(g_services_buffer) - 1] = '\0';
  }
  return g_services_buffer;
}

static void set_error(char* out, int out_max, const char* message) {
  if (!out || out_max <= 0) {
    return;
  }
  strncpy(out, message, (size_t)out_max - 1);
  out[out_max - 1] = '\0';
}

bool na_url_open(const char* utf8_url, char* err_out, int err_max) {
  @autoreleasepool {
    NSString* nsUrl = [NSString stringWithUTF8String:utf8_url ? utf8_url : ""];
    if (!nsUrl) {
      set_error(err_out, err_max, "Failed to build NSURL from UTF-8 input.");
      return false;
    }
    NSURL* target = [NSURL URLWithString:nsUrl];
    if (!target) {
      set_error(err_out, err_max, "Failed to parse URL.");
      return false;
    }
    BOOL opened = [[NSWorkspace sharedWorkspace] openURL:target];
    if (!opened) {
      set_error(err_out, err_max, "NSWorkspace could not open the URL.");
      return false;
    }
    return true;
  }
}

void na_accessibility_enable(void) {
  NSDictionary* options = @{(__bridge NSString*)kAXTrustedCheckOptionPrompt : @YES};
  AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}

bool na_accessibility_is_enabled(void) {
  return AXIsProcessTrustedWithOptions(nil) ? true : false;
}

const char* na_lal_default_id(void) {
  @autoreleasepool {
    NSString* bundleId = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleId.length > 0) {
      return info_from_string(bundleId);
    }
    NSString* processName = [[NSProcessInfo processInfo] processName];
    if (processName.length == 0) {
      processName = @"app";
    }
    return info_from_string(
        [NSString stringWithFormat:@"com.nativeapi.launch_at_login.%@", processName]);
  }
}

const char* na_lal_default_display_name(void) {
  @autoreleasepool {
    NSString* name = plist_string(@"CFBundleName");
    if (name.length == 0) {
      name = [[NSProcessInfo processInfo] processName];
    }
    if (name.length == 0) {
      name = @"Application";
    }
    return info_from_string(name);
  }
}

const char* na_lal_default_program_path(void) {
  @autoreleasepool {
    NSString* arg0 = [[[NSProcessInfo processInfo] arguments] firstObject];
    if (arg0.length > 0) {
      return info_from_string([arg0 stringByStandardizingPath]);
    }
    uint32_t size = 0;
    _NSGetExecutablePath(NULL, &size);
    if (size > 0 && size < sizeof(g_services_buffer)) {
      char buffer[1024];
      if (_NSGetExecutablePath(buffer, &size) == 0) {
        return info_from_string([NSString stringWithUTF8String:buffer]);
      }
    }
    g_services_buffer[0] = '\0';
    return g_services_buffer;
  }
}

bool na_lal_is_supported(void) {
  if (@available(macOS 13.0, *)) {
    return true;
  }
  return false;
}

static SMAppService* lal_service(NSString* identifier) API_AVAILABLE(macos(13.0));

static SMAppService* lal_service(NSString* identifier) {
  if (identifier.length == 0) {
    return [SMAppService mainAppService];
  }
  return [SMAppService loginItemServiceWithIdentifier:identifier];
}

bool na_lal_enable(const char* utf8_id) {
  if (@available(macOS 13.0, *)) {
    @autoreleasepool {
      NSString* identifier = utf8_id ? [NSString stringWithUTF8String:utf8_id] : @"";
      SMAppService* service = lal_service(identifier);
      if (!service) {
        return false;
      }
      if (service.status == SMAppServiceStatusEnabled) {
        return true;
      }
      if (service.status == SMAppServiceStatusRequiresApproval) {
        return false;
      }
      NSError* error = nil;
      return [service registerAndReturnError:&error] == YES;
    }
  }
  return false;
}

bool na_lal_disable(const char* utf8_id) {
  if (@available(macOS 13.0, *)) {
    @autoreleasepool {
      NSString* identifier = utf8_id ? [NSString stringWithUTF8String:utf8_id] : @"";
      SMAppService* service = lal_service(identifier);
      if (!service) {
        return false;
      }
      if (service.status == SMAppServiceStatusNotRegistered) {
        return true;
      }
      NSError* error = nil;
      return [service unregisterAndReturnError:&error] == YES ||
             service.status == SMAppServiceStatusNotRegistered;
    }
  }
  return false;
}

bool na_lal_is_enabled(const char* utf8_id) {
  if (@available(macOS 13.0, *)) {
    @autoreleasepool {
      NSString* identifier = utf8_id ? [NSString stringWithUTF8String:utf8_id] : @"";
      SMAppService* service = lal_service(identifier);
      if (!service) {
        return false;
      }
      return service.status == SMAppServiceStatusEnabled;
    }
  }
  return false;
}
