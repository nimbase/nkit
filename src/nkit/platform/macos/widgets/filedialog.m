#import <Cocoa/Cocoa.h>
#include <stdlib.h>

// ---- Open panel ----

void* na_open_panel_create(const char* title) {
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  if (title) {
    panel.title = [NSString stringWithUTF8String:title];
  }
  panel.canChooseFiles = YES;
  panel.canChooseDirectories = NO;
  panel.allowsMultipleSelection = NO;
  return (__bridge void*)panel;
}

void na_open_panel_set_can_choose_directories(void* ptr, bool value) {
  [(__bridge NSOpenPanel*)ptr setCanChooseDirectories:value ? YES : NO];
}

void na_open_panel_set_allows_multiple(void* ptr, bool value) {
  [(__bridge NSOpenPanel*)ptr setAllowsMultipleSelection:value ? YES : NO];
}

void na_open_panel_set_filters(void* ptr, const char* const* extensions,
                               int count) {
  NSOpenPanel* panel = (__bridge NSOpenPanel*)ptr;
  NSMutableArray<NSString*>* types = [NSMutableArray array];
  for (int i = 0; i < count; i++) {
    if (extensions[i]) {
      [types addObject:[NSString stringWithUTF8String:extensions[i]]];
    }
  }
  if (types.count > 0) {
    panel.allowedFileTypes = types;
  } else {
    panel.allowedFileTypes = nil;
  }
}

void na_open_panel_set_initial_directory(void* ptr, const char* path) {
  NSOpenPanel* panel = (__bridge NSOpenPanel*)ptr;
  if (path) {
    panel.directoryURL =
        [NSURL fileURLWithPath:[NSString stringWithUTF8String:path]];
  }
}

// Returns the number of selected paths; writes them as malloc'd strings.
int na_open_panel_run_modal(void* ptr, char*** out_paths) {
  NSOpenPanel* panel = (__bridge NSOpenPanel*)ptr;
  NSInteger result = [panel runModal];
  if (result != NSModalResponseOK || panel.URLs.count == 0) {
    *out_paths = NULL;
    return 0;
  }
  NSUInteger count = panel.URLs.count;
  char** list = (char**)malloc(sizeof(char*) * count);
  NSUInteger n = 0;
  for (NSURL* url in panel.URLs) {
    list[n++] = strdup(url.path.UTF8String);
  }
  *out_paths = list;
  return (int)n;
}

// ---- Save panel ----

void* na_save_panel_create(const char* title, const char* default_name) {
  NSSavePanel* panel = [NSSavePanel savePanel];
  if (title) {
    panel.title = [NSString stringWithUTF8String:title];
  }
  if (default_name) {
    panel.nameFieldStringValue =
        [NSString stringWithUTF8String:default_name];
  }
  return (__bridge void*)panel;
}

void na_save_panel_set_name_field(void* ptr, const char* name) {
  NSSavePanel* panel = (__bridge NSSavePanel*)ptr;
  if (name) {
    panel.nameFieldStringValue =
        [NSString stringWithUTF8String:name];
  }
}

void na_save_panel_set_filters(void* ptr, const char* const* extensions,
                               int count) {
  NSSavePanel* panel = (__bridge NSSavePanel*)ptr;
  NSMutableArray<NSString*>* types = [NSMutableArray array];
  for (int i = 0; i < count; i++) {
    if (extensions[i]) {
      [types addObject:[NSString stringWithUTF8String:extensions[i]]];
    }
  }
  panel.allowedFileTypes = types.count > 0 ? types : nil;
}

char* na_save_panel_run_modal(void* ptr) {
  NSSavePanel* panel = (__bridge NSSavePanel*)ptr;
  NSInteger result = [panel runModal];
  if (result != NSModalResponseOK || !panel.URL) {
    return NULL;
  }
  return strdup(panel.URL.path.UTF8String);
}
