#import <Foundation/Foundation.h>
#include <sys/sysctl.h>
#include <string.h>

static char g_info_buffer[512];

static const char* info_from_string(NSString* value) {
  g_info_buffer[0] = '\0';
  if (!value) {
    return g_info_buffer;
  }
  const char* utf8 = value.UTF8String;
  if (utf8) {
    strncpy(g_info_buffer, utf8, sizeof(g_info_buffer) - 1);
    g_info_buffer[sizeof(g_info_buffer) - 1] = '\0';
  }
  return g_info_buffer;
}

static NSString* plist_string(NSString* key) {
  id value = [[NSBundle mainBundle] objectForInfoDictionaryKey:key];
  return [value isKindOfClass:[NSString class]] ? (NSString*)value : nil;
}

const char* na_app_info_name(void) {
  @autoreleasepool {
    NSString* name = plist_string(@"CFBundleDisplayName");
    if (!name) {
      name = plist_string(@"CFBundleName");
    }
    if (!name) {
      name = [[NSProcessInfo processInfo] processName];
    }
    return info_from_string(name);
  }
}

const char* na_app_info_identifier(void) {
  @autoreleasepool {
    return info_from_string([[NSBundle mainBundle] bundleIdentifier]);
  }
}

const char* na_app_info_version(void) {
  @autoreleasepool {
    return info_from_string(plist_string(@"CFBundleShortVersionString"));
  }
}

const char* na_app_info_build_number(void) {
  @autoreleasepool {
    return info_from_string(plist_string(@"CFBundleVersion"));
  }
}

const char* na_device_info_name(void) {
  @autoreleasepool {
    NSString* name = [[NSHost currentHost] localizedName];
    if (!name) {
      name = [[NSProcessInfo processInfo] hostName];
    }
    return info_from_string(name);
  }
}

const char* na_device_info_model(void) {
  size_t size = 0;
  if (sysctlbyname("hw.model", NULL, &size, NULL, 0) != 0 || size == 0 ||
      size > sizeof(g_info_buffer)) {
    g_info_buffer[0] = '\0';
    return g_info_buffer;
  }
  if (sysctlbyname("hw.model", g_info_buffer, &size, NULL, 0) != 0) {
    g_info_buffer[0] = '\0';
    return g_info_buffer;
  }
  g_info_buffer[sizeof(g_info_buffer) - 1] = '\0';
  for (ssize_t i = (ssize_t)size - 1; i >= 0; i--) {
    if (g_info_buffer[i] == '\0') {
      g_info_buffer[i] = '\0';
    } else {
      break;
    }
  }
  return g_info_buffer;
}

const char* na_device_info_os_version(void) {
  @autoreleasepool {
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo]
        operatingSystemVersion];
    NSString* text = [NSString stringWithFormat:@"%ld.%ld.%ld",
                             (long)version.majorVersion,
                             (long)version.minorVersion,
                             (long)version.patchVersion];
    return info_from_string(text);
  }
}
