#import <Cocoa/Cocoa.h>
#import "gui_common.h"

void* na_separator_create(int orientation) {
  NSBox* box = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, 100, 1)];
  box.boxType = NSBoxCustom;
  box.borderColor = [NSColor clearColor];
  box.fillColor = [NSColor separatorColor];
  box.borderWidth = 0;
  if (orientation == 1) {
    box.frame = NSMakeRect(0, 0, 1, 100);
  }
  na_gui_register_view(box);
  return (__bridge void*)box;
}

void na_separator_free(void* ptr) {
  NSBox* box = (__bridge NSBox*)ptr;
  if (box) {
    [box removeFromSuperview];
    na_gui_unregister_view(box);
  }
}

void na_separator_set_thickness(void* ptr, double thickness) {
  NSBox* box = (__bridge NSBox*)ptr;
  if (!box) {
    return;
  }
  NSRect frame = box.frame;
  BOOL vertical = frame.size.height > frame.size.width;
  if (vertical) {
    frame.size.width = thickness;
  } else {
    frame.size.height = thickness;
  }
  box.frame = frame;
}
