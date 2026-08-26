#import "gui_common.h"

#define NA_IMAGE_VIEW_SCALE_PROPORTIONALLY 0
#define NA_IMAGE_VIEW_SCALE_FIT 1
#define NA_IMAGE_VIEW_SCALE_STRETCH 2

void* na_image_view_create(void) {
  UIImageView* imageView = [[UIImageView alloc] init];
  imageView.contentMode = UIViewContentModeScaleAspectFit;
  imageView.clipsToBounds = YES;
  imageView.translatesAutoresizingMaskIntoConstraints = NO;
  na_gui_register_view(imageView);
  return (__bridge_retained void*)imageView;
}

void na_image_view_free(void* ptr) {
  if (!ptr) return;
  UIImageView* imageView = (__bridge_transfer UIImageView*)ptr;
  [imageView removeFromSuperview];
  na_gui_unregister_view(imageView);
}

void na_image_view_set_image_ptr(void* ptr, void* imagePtr) {
  UIImageView* imageView = (__bridge UIImageView*)ptr;
  // On iOS the imagePtr is expected to be a UTF-8 file path (const char*),
  // matching the macOS convention where the caller passes a filename.
  if (imageView && imagePtr) {
    const char* path = (const char*)imagePtr;
    NSString* nsPath = [NSString stringWithUTF8String:path];
    UIImage* image = [UIImage imageWithContentsOfFile:nsPath];
    imageView.image = image;
  }
}

void na_image_view_set_symbol(void* ptr, const char* symbolName, double pointSize, int weight) {
  // SF Symbols are not available on iOS in the same way; no-op.
  (void)ptr; (void)symbolName; (void)pointSize; (void)weight;
}

void na_image_view_clear(void* ptr) {
  UIImageView* imageView = (__bridge UIImageView*)ptr;
  if (imageView) {
    imageView.image = nil;
  }
}

void na_image_view_set_scaling(void* ptr, int scaling) {
  UIImageView* imageView = (__bridge UIImageView*)ptr;
  if (!imageView) {
    return;
  }
  switch (scaling) {
    case NA_IMAGE_VIEW_SCALE_FIT:
      imageView.contentMode = UIViewContentModeScaleAspectFit;
      break;
    case NA_IMAGE_VIEW_SCALE_STRETCH:
      imageView.contentMode = UIViewContentModeScaleToFill;
      break;
    case NA_IMAGE_VIEW_SCALE_PROPORTIONALLY:
    default:
      imageView.contentMode = UIViewContentModeScaleAspectFit;
      break;
  }
}
