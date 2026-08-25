#import <Cocoa/Cocoa.h>
#import "gui_common.h"

void* na_label_create(void) {
  NSTextField* label = [NSTextField labelWithString:@""];
  label.frame = NSMakeRect(0, 0, 100, 20);
  label.editable = NO;
  na_gui_register_view(label);
  return (__bridge void*)label;
}

void na_label_free(void* ptr) {
  NSTextField* label = (__bridge NSTextField*)ptr;
  if (label) {
    [label removeFromSuperview];
    na_gui_unregister_view(label);
  }
}

void na_label_set_text(void* ptr, const char* text) {
  NSTextField* label = (__bridge NSTextField*)ptr;
  if (label) {
    label.stringValue = text ? [NSString stringWithUTF8String:text] : @"";
  }
}

const char* na_label_get_text(void* ptr) {
  NSTextField* label = (__bridge NSTextField*)ptr;
  return label ? na_gui_copy_string(label.stringValue) : na_gui_copy_string(nil);
}

void na_label_set_text_color(void* ptr, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
  NSTextField* label = (__bridge NSTextField*)ptr;
  if (label) {
    NSColor* color = [NSColor colorWithSRGBRed:r / 255.0 green:g / 255.0 blue:b / 255.0
                                         alpha:a / 255.0];
    label.textColor = color;
  }
}

void na_label_set_font_size(void* ptr, double size) {
  NSTextField* label = (__bridge NSTextField*)ptr;
  if (label && size > 0) {
    label.font = [NSFont systemFontOfSize:(CGFloat)size];
  }
}

void na_label_set_font_weight(void* ptr, int weight) {
  NSTextField* label = (__bridge NSTextField*)ptr;
  if (label) {
    CGFloat size = label.font ? label.font.pointSize : [NSFont systemFontSize];
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
    NSFontDescriptor* baseDescriptor =
        label.font ? label.font.fontDescriptor : [NSFont systemFontOfSize:size].fontDescriptor;
    NSDictionary* traits = @{NSFontWeightTrait: @(nsWeight)};
    NSFontDescriptor* descriptor = [baseDescriptor fontDescriptorByAddingAttributes:
        @{NSFontTraitsAttribute: traits}];
    label.font = [NSFont fontWithDescriptor:descriptor size:size];
  }
}

#define NA_LABEL_ALIGN_LEFT 0
#define NA_LABEL_ALIGN_CENTER 1
#define NA_LABEL_ALIGN_RIGHT 2

void na_label_set_alignment(void* ptr, int alignment) {
  NSTextField* label = (__bridge NSTextField*)ptr;
  if (!label) {
    return;
  }
  switch (alignment) {
    case NA_LABEL_ALIGN_CENTER:
      label.alignment = NSTextAlignmentCenter;
      break;
    case NA_LABEL_ALIGN_RIGHT:
      label.alignment = NSTextAlignmentRight;
      break;
    case NA_LABEL_ALIGN_LEFT:
    default:
      label.alignment = NSTextAlignmentLeft;
      break;
  }
}

void na_label_set_wraps(void* ptr, bool wraps, int maxLines) {
  NSTextField* label = (__bridge NSTextField*)ptr;
  if (!label) {
    return;
  }
  NSTextFieldCell* cell = (NSTextFieldCell*)label.cell;
  cell.wraps = wraps ? YES : NO;
  if (wraps) {
    if (maxLines > 0) {
      label.maximumNumberOfLines = maxLines;
    }
    label.lineBreakMode = NSLineBreakByWordWrapping;
  } else {
    label.maximumNumberOfLines = 1;
    label.cell.lineBreakMode = NSLineBreakByTruncatingTail;
  }
}
