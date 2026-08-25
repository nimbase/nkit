#import <Cocoa/Cocoa.h>
#include <string.h>
#include <stdlib.h>

extern NSImage* na_image_peek(int64_t handle);
extern int64_t na_image_register(NSImage* image, const char* source,
                                 const char* format);

void na_clipboard_set_text(const char* text) {
  NSPasteboard* pb = [NSPasteboard generalPasteboard];
  [pb clearContents];
  if (text) {
    [pb setString:[NSString stringWithUTF8String:text]
          forType:NSPasteboardTypeString];
  }
}

const char* na_clipboard_get_text(void) {
  NSPasteboard* pb = [NSPasteboard generalPasteboard];
  NSString* value = [pb stringForType:NSPasteboardTypeString];
  return value ? strdup(value.UTF8String) : NULL;
}

void na_clipboard_clear(void) {
  [[NSPasteboard generalPasteboard] clearContents];
}

int na_clipboard_change_count(void) {
  return (int)[NSPasteboard generalPasteboard].changeCount;
}

void na_clipboard_set_image_handle(int64_t handle) {
  NSImage* image = na_image_peek(handle);
  if (!image) {
    return;
  }
  @autoreleasepool {
    NSPasteboard* pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    CGImageRef cg = [image CGImageForProposedRect:nil context:nil hints:nil];
    if (!cg) {
      return;
    }
    NSBitmapImageRep* rep = [[NSBitmapImageRep alloc] initWithCGImage:cg];
    NSData* png = [rep representationUsingType:NSBitmapImageFileTypePNG
                                    properties:@{}];
    if (png) {
      [pb setData:png forType:NSPasteboardTypePNG];
    }
  }
}

int64_t na_clipboard_get_image_handle(void) {
  NSPasteboard* pb = [NSPasteboard generalPasteboard];
  if (![pb types] || ![[pb types] containsObject:NSPasteboardTypePNG]) {
    return 0;
  }
  NSData* png = [pb dataForType:NSPasteboardTypePNG];
  if (!png) {
    return 0;
  }
  NSImage* image = [[NSImage alloc] initWithData:png];
  if (!image) {
    return 0;
  }
  return na_image_register(image, "clipboard", "png");
}

void na_clipboard_set_file_paths(const char* const* paths, int count) {
  NSPasteboard* pb = [NSPasteboard generalPasteboard];
  [pb clearContents];
  if (!paths || count <= 0) {
    return;
  }
  NSMutableArray<NSURL*>* urls = [NSMutableArray arrayWithCapacity:count];
  for (int i = 0; i < count; i++) {
    if (paths[i]) {
      NSURL* url = [NSURL fileURLWithPath:
          [NSString stringWithUTF8String:paths[i]]];
      if (url) {
        [urls addObject:url];
      }
    }
  }
  [pb writeObjects:urls];
}

char** na_clipboard_get_file_paths(int* out_count) {
  *out_count = 0;
  NSPasteboard* pb = [NSPasteboard generalPasteboard];
  NSArray* objects =
      [pb readObjectsForClasses:@[ [NSURL class] ] options:nil];
  if (!objects) {
    return NULL;
  }
  NSMutableArray<NSString*>* paths = [NSMutableArray array];
  for (NSURL* url in objects) {
    if (url.isFileURL) {
      [paths addObject:url.path];
    }
  }
  if (paths.count == 0) {
    return NULL;
  }
  char** list = (char**)malloc(sizeof(char*) * (paths.count + 1));
  for (NSUInteger i = 0; i < paths.count; i++) {
    list[i] = strdup(paths[i].UTF8String);
  }
  list[paths.count] = NULL;
  *out_count = (int)paths.count;
  return list;
}

void na_clipboard_free_string(const char* text) {
  free((void*)text);
}

void na_clipboard_free_string_list(char** list, int count) {
  if (!list) {
    return;
  }
  for (int i = 0; i < count; i++) {
    free(list[i]);
  }
  free(list);
}
