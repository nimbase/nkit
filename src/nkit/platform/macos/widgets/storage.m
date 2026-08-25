#import <Foundation/Foundation.h>
#include <string.h>

static NSArray<NSString*>* g_key_snapshot = nil;

void* na_prefs_open(const char* utf8_scope) {
  NSString* scope = [NSString stringWithUTF8String:utf8_scope ? utf8_scope : "default"];
  NSString* suite = [NSString stringWithFormat:@"com.nativeapi.preferences.%@", scope];
  NSUserDefaults* defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
  if (!defaults) {
    defaults = [NSUserDefaults standardUserDefaults];
  }
  return (__bridge_retained void*)defaults;
}

void na_prefs_close(void* handle) {
  if (!handle) {
    return;
  }
  CFBridgingRelease(handle);
}

bool na_prefs_set(void* handle, const char* key, const char* value) {
  NSUserDefaults* defaults = (__bridge NSUserDefaults*)handle;
  if (!defaults || !key || !value) {
    return false;
  }
  @autoreleasepool {
    [defaults setObject:[NSString stringWithUTF8String:value]
                 forKey:[NSString stringWithUTF8String:key]];
    return [defaults synchronize] ? true : false;
  }
}

bool na_prefs_get(void* handle, const char* key, char* out, int out_max) {
  NSUserDefaults* defaults = (__bridge NSUserDefaults*)handle;
  if (!defaults || !key || !out || out_max <= 0) {
    return false;
  }
  @autoreleasepool {
    NSString* value = [defaults stringForKey:[NSString stringWithUTF8String:key]];
    if (!value) {
      return false;
    }
    const char* utf8 = value.UTF8String;
    if (!utf8) {
      return false;
    }
    strncpy(out, utf8, (size_t)out_max - 1);
    out[out_max - 1] = '\0';
    return true;
  }
}

bool na_prefs_remove(void* handle, const char* key) {
  NSUserDefaults* defaults = (__bridge NSUserDefaults*)handle;
  if (!defaults || !key) {
    return false;
  }
  @autoreleasepool {
    NSString* nsKey = [NSString stringWithUTF8String:key];
    if ([defaults objectForKey:nsKey] == nil) {
      return false;
    }
    [defaults removeObjectForKey:nsKey];
    return [defaults synchronize] ? true : false;
  }
}

bool na_prefs_clear(void* handle) {
  NSUserDefaults* defaults = (__bridge NSUserDefaults*)handle;
  if (!defaults) {
    return false;
  }
  @autoreleasepool {
    NSDictionary* dict = defaults.dictionaryRepresentation;
    for (NSString* key in dict) {
      [defaults removeObjectForKey:key];
    }
    return [defaults synchronize] ? true : false;
  }
}

bool na_prefs_contains(void* handle, const char* key) {
  NSUserDefaults* defaults = (__bridge NSUserDefaults*)handle;
  if (!defaults || !key) {
    return false;
  }
  @autoreleasepool {
    return [defaults objectForKey:[NSString stringWithUTF8String:key]] != nil;
  }
}

int na_prefs_size(void* handle) {
  NSUserDefaults* defaults = (__bridge NSUserDefaults*)handle;
  if (!defaults) {
    return 0;
  }
  @autoreleasepool {
    return (int)defaults.dictionaryRepresentation.count;
  }
}

void na_prefs_refresh_keys(void* handle) {
  NSUserDefaults* defaults = (__bridge NSUserDefaults*)handle;
  if (!defaults) {
    g_key_snapshot = nil;
    return;
  }
  @autoreleasepool {
    g_key_snapshot = [defaults.dictionaryRepresentation.allKeys copy];
  }
}

int na_prefs_snapshot_count(void) {
  return g_key_snapshot ? (int)g_key_snapshot.count : 0;
}

bool na_prefs_snapshot_key(int index, char* out, int out_max) {
  if (!g_key_snapshot || index < 0 || index >= (int)g_key_snapshot.count) {
    return false;
  }
  NSString* key = [g_key_snapshot objectAtIndex:index];
  const char* utf8 = key.UTF8String;
  if (!utf8) {
    return false;
  }
  strncpy(out, utf8, (size_t)out_max - 1);
  out[out_max - 1] = '\0';
  return true;
}
