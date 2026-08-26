#import <UIKit/UIKit.h>
#import <sys/utsname.h>

static NSString* bundle_string(NSString* key) {
  id value = [NSBundle mainBundle].infoDictionary[key];
  if (![value isKindOfClass:[NSString class]]) {
    return @"";
  }
  return value;
}

const char* na_app_info_name(void) {
  extern char g_gui_text_buffer[2048];
  NSString* name = bundle_string(@"CFBundleName");
  if (name.length == 0) {
    name = bundle_string(@"CFBundleExecutable");
  }
  g_gui_text_buffer[0] = '\0';
  strncpy(g_gui_text_buffer, name.UTF8String ?: "", sizeof(g_gui_text_buffer) - 1);
  return g_gui_text_buffer;
}

const char* na_app_info_identifier(void) {
  extern char g_gui_text_buffer[2048];
  NSString* identifier = [NSBundle mainBundle].bundleIdentifier ?: @"";
  g_gui_text_buffer[0] = '\0';
  strncpy(g_gui_text_buffer, identifier.UTF8String, sizeof(g_gui_text_buffer) - 1);
  return g_gui_text_buffer;
}

const char* na_app_info_version(void) {
  extern char g_gui_text_buffer[2048];
  NSString* version = bundle_string(@"CFBundleShortVersionString");
  g_gui_text_buffer[0] = '\0';
  strncpy(g_gui_text_buffer, version.UTF8String ?: "0.0.0", sizeof(g_gui_text_buffer) - 1);
  return g_gui_text_buffer;
}

const char* na_app_info_build_number(void) {
  extern char g_gui_text_buffer[2048];
  NSString* build = bundle_string(@"CFBundleVersion");
  g_gui_text_buffer[0] = '\0';
  strncpy(g_gui_text_buffer, build.UTF8String ?: "1", sizeof(g_gui_text_buffer) - 1);
  return g_gui_text_buffer;
}

const char* na_device_info_name(void) {
  extern char g_gui_text_buffer[2048];
  NSString* name = [UIDevice currentDevice].name ?: @"";
  g_gui_text_buffer[0] = '\0';
  strncpy(g_gui_text_buffer, name.UTF8String, sizeof(g_gui_text_buffer) - 1);
  return g_gui_text_buffer;
}

const char* na_device_info_model(void) {
  extern char g_gui_text_buffer[2048];
  struct utsname systemInfo;
  uname(&systemInfo);
  const char* machine = systemInfo.machine;
  if (machine == NULL || machine[0] == '\0') {
    machine = [UIDevice currentDevice].model.UTF8String;
  }
  g_gui_text_buffer[0] = '\0';
  strncpy(g_gui_text_buffer, machine ?: "unknown", sizeof(g_gui_text_buffer) - 1);
  return g_gui_text_buffer;
}

const char* na_device_info_os_version(void) {
  extern char g_gui_text_buffer[2048];
  NSString* version = [NSString stringWithFormat:@"iOS %@",
      [UIDevice currentDevice].systemVersion];
  g_gui_text_buffer[0] = '\0';
  strncpy(g_gui_text_buffer, version.UTF8String, sizeof(g_gui_text_buffer) - 1);
  return g_gui_text_buffer;
}
