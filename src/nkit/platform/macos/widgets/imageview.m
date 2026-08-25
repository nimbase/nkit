#import <Cocoa/Cocoa.h>
#import "gui_common.h"

#define NA_IMAGE_VIEW_SCALE_PROPORTIONALLY 0
#define NA_IMAGE_VIEW_SCALE_FIT 1
#define NA_IMAGE_VIEW_SCALE_STRETCH 2

void* na_image_view_create(void) {
  NSImageView* imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 48, 48)];
  imageView.editable = NO;
  imageView.animates = NO;
  na_gui_register_view(imageView);
  return (__bridge void*)imageView;
}

void na_image_view_free(void* ptr) {
  NSImageView* imageView = (__bridge NSImageView*)ptr;
  if (imageView) {
    [imageView removeFromSuperview];
    na_gui_unregister_view(imageView);
  }
}

void na_image_view_set_image_ptr(void* ptr, void* imagePtr) {
  NSImageView* imageView = (__bridge NSImageView*)ptr;
  NSImage* image = (__bridge NSImage*)imagePtr;
  if (imageView) {
    imageView.image = image;
  }
}

void na_image_view_set_symbol(void* ptr, const char* symbolName, double pointSize, int weight) {
  NSImageView* imageView = (__bridge NSImageView*)ptr;
  if (!imageView) {
    return;
  }
  NSString* name = symbolName ? [NSString stringWithUTF8String:symbolName] : nil;
  if (!name.length) {
    imageView.image = nil;
    return;
  }
  NSImage* symbol =
      [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
  if (!symbol) {
    imageView.image = nil;
    return;
  }
  NSFontWeight nsWeight;
  switch (weight) {
    case 0: nsWeight = NSFontWeightThin; break;
    case 1: nsWeight = NSFontWeightLight; break;
    case 2: nsWeight = NSFontWeightRegular; break;
    case 3: nsWeight = NSFontWeightMedium; break;
    case 4: nsWeight = NSFontWeightSemibold; break;
    case 5: nsWeight = NSFontWeightBold; break;
    case 6: nsWeight = NSFontWeightHeavy; break;
    default: nsWeight = NSFontWeightRegular; break;
  }
  NSImageSymbolConfiguration* sizeConfig =
      [NSImageSymbolConfiguration configurationWithPointSize:(CGFloat)pointSize
                                                      weight:nsWeight];
  NSImage* configured = [symbol imageWithSymbolConfiguration:sizeConfig];
  imageView.image = configured ? configured : symbol;
}

void na_image_view_clear(void* ptr) {
  NSImageView* imageView = (__bridge NSImageView*)ptr;
  if (imageView) {
    imageView.image = nil;
  }
}

void na_image_view_set_scaling(void* ptr, int scaling) {
  NSImageView* imageView = (__bridge NSImageView*)ptr;
  if (!imageView) {
    return;
  }
  switch (scaling) {
    case NA_IMAGE_VIEW_SCALE_FIT:
      imageView.imageScaling = NSImageScaleProportionallyUpOrDown;
      break;
    case NA_IMAGE_VIEW_SCALE_STRETCH:
      imageView.imageScaling = NSImageScaleAxesIndependently;
      break;
    case NA_IMAGE_VIEW_SCALE_PROPORTIONALLY:
    default:
      imageView.imageScaling = NSImageScaleProportionallyUpOrDown;
      break;
  }
}
