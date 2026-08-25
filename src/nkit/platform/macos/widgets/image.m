#import <Cocoa/Cocoa.h>
#include <string.h>

static NSMutableDictionary<NSNumber*, NSImage*>* g_images = nil;
static NSMutableDictionary<NSNumber*, NSString*>* g_image_sources = nil;
static NSMutableDictionary<NSNumber*, NSString*>* g_image_formats = nil;
static uint64_t g_next_image_handle = 1;

static void ensure_image_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_images = [NSMutableDictionary dictionary];
    g_image_sources = [NSMutableDictionary dictionary];
    g_image_formats = [NSMutableDictionary dictionary];
  }
}

static void image_set_metadata(int64_t handle,
                               NSImage* image,
                               NSString* source,
                               NSString* format) {
  @autoreleasepool {
    NSSize size = [image size];
    NSNumber* handleNumber = @(handle);
    g_images[handleNumber] = image;
    g_image_sources[handleNumber] = source;
    g_image_formats[handleNumber] = format;
    (void)size;
  }
}

NSImage* na_image_peek(int64_t handle) {
  ensure_image_tables();
  return g_images[@(handle)];
}

int64_t na_image_register(NSImage* image, const char* source, const char* format) {
  ensure_image_tables();
  if (!image) {
    return 0;
  }
  int64_t handle = (int64_t)g_next_image_handle++;
  image_set_metadata(handle, image,
                     source ? [NSString stringWithUTF8String:source] : @"",
                     format ? [NSString stringWithUTF8String:format] : @"png");
  return handle;
}

int64_t na_image_from_file(const char* utf8_path) {
  ensure_image_tables();
  if (!utf8_path) {
    return 0;
  }
  @autoreleasepool {
    NSString* path = [NSString stringWithUTF8String:utf8_path];
    NSImage* image = [[NSImage alloc] initWithContentsOfFile:path];
    if (!image) {
      return 0;
    }
    NSString* extension = path.pathExtension.lowercaseString;
    NSString* format = @"Unknown";
    if ([extension isEqualToString:@"png"]) {
      format = @"PNG";
    } else if ([extension isEqualToString:@"jpg"] || [extension isEqualToString:@"jpeg"]) {
      format = @"JPEG";
    } else if ([extension isEqualToString:@"gif"]) {
      format = @"GIF";
    } else if ([extension isEqualToString:@"tiff"] || [extension isEqualToString:@"tif"]) {
      format = @"TIFF";
    } else if ([extension isEqualToString:@"bmp"]) {
      format = @"BMP";
    } else if ([extension isEqualToString:@"ico"]) {
      format = @"ICO";
    } else if ([extension isEqualToString:@"pdf"]) {
      format = @"PDF";
    }
    int64_t handle = g_next_image_handle++;
    image_set_metadata(handle, image, path, format);
    return handle;
  }
}

int64_t na_image_from_base64(const char* utf8_base64) {
  ensure_image_tables();
  if (!utf8_base64) {
    return 0;
  }
  @autoreleasepool {
    NSString* raw = [NSString stringWithUTF8String:utf8_base64];
    NSRange comma = [raw rangeOfString:@","];
    NSString* clean = (comma.location != NSNotFound)
        ? [raw substringFromIndex:comma.location + comma.length]
        : raw;
    NSData* data = [[NSData alloc] initWithBase64EncodedString:clean options:0];
    if (!data) {
      return 0;
    }
    NSImage* image = [[NSImage alloc] initWithData:data];
    if (!image) {
      return 0;
    }
    int64_t handle = g_next_image_handle++;
    image_set_metadata(handle, image, raw, @"PNG");
    return handle;
  }
}

void na_image_destroy(int64_t handle) {
  ensure_image_tables();
  NSNumber* key = @(handle);
  [g_images removeObjectForKey:key];
  [g_image_sources removeObjectForKey:key];
  [g_image_formats removeObjectForKey:key];
}

bool na_image_exists(int64_t handle) {
  ensure_image_tables();
  return g_images[@(handle)] != nil;
}

void na_image_get_size(int64_t handle, double* out_w, double* out_h) {
  NSImage* image = g_images[@(handle)];
  if (!image) {
    *out_w = 0;
    *out_h = 0;
    return;
  }
  NSSize size = [image size];
  *out_w = size.width;
  *out_h = size.height;
}

void na_image_get_source(int64_t handle, char* out, int out_max) {
  out[0] = '\0';
  NSString* source = g_image_sources[@(handle)];
  if (!source) {
    return;
  }
  const char* utf8 = source.UTF8String;
  if (utf8) {
    strncpy(out, utf8, (size_t)out_max - 1);
    out[out_max - 1] = '\0';
  }
}

const char* na_image_get_format(int64_t handle) {
  static char format_buffer[32];
  format_buffer[0] = '\0';
  NSString* format = g_image_formats[@(handle)];
  if (!format) {
    return format_buffer;
  }
  strncpy(format_buffer, format.UTF8String, sizeof(format_buffer) - 1);
  format_buffer[sizeof(format_buffer) - 1] = '\0';
  return format_buffer;
}

const char* na_image_to_base64(int64_t handle) {
  static char base64_buffer[4 * 1024 * 1024];
  base64_buffer[0] = '\0';
  NSImage* image = g_images[@(handle)];
  if (!image) {
    return base64_buffer;
  }
  @autoreleasepool {
    NSBitmapImageRep* rep =
        [[NSBitmapImageRep alloc] initWithData:[image TIFFRepresentation]];
    if (!rep) {
      return base64_buffer;
    }
    NSData* pngData = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    if (!pngData) {
      return base64_buffer;
    }
    NSString* base64 = [pngData base64EncodedStringWithOptions:0];
    snprintf(base64_buffer, sizeof(base64_buffer), "data:image/png;base64,%s",
             base64.UTF8String);
    return base64_buffer;
  }
}

bool na_image_save_to_file(int64_t handle, const char* utf8_path) {
  NSImage* image = g_images[@(handle)];
  if (!image || !utf8_path) {
    return false;
  }
  @autoreleasepool {
    NSString* path = [NSString stringWithUTF8String:utf8_path];
    NSString* extension = path.pathExtension.lowercaseString;
    NSBitmapImageFileType fileType = NSBitmapImageFileTypePNG;
    NSDictionary* properties = @{};
    if ([extension isEqualToString:@"jpg"] || [extension isEqualToString:@"jpeg"]) {
      fileType = NSBitmapImageFileTypeJPEG;
      properties = @{NSImageCompressionFactor : @0.9};
    } else if ([extension isEqualToString:@"gif"]) {
      fileType = NSBitmapImageFileTypeGIF;
    } else if ([extension isEqualToString:@"tiff"] || [extension isEqualToString:@"tif"]) {
      fileType = NSBitmapImageFileTypeTIFF;
    } else if ([extension isEqualToString:@"bmp"]) {
      fileType = NSBitmapImageFileTypeBMP;
    }
    NSBitmapImageRep* rep =
        [[NSBitmapImageRep alloc] initWithData:[image TIFFRepresentation]];
    if (!rep) {
      return false;
    }
    NSData* data = [rep representationUsingType:fileType properties:properties];
    if (!data) {
      return false;
    }
    return [data writeToFile:path atomically:YES] == YES;
  }
}

void* na_image_native_ptr(int64_t handle) {
  ensure_image_tables();
  return (__bridge void*)g_images[@(handle)];
}
