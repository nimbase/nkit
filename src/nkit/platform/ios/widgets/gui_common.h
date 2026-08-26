#ifndef NKIT_IOS_GUI_COMMON_H
#define NKIT_IOS_GUI_COMMON_H

#import <UIKit/UIKit.h>

typedef void (*na_gui_action_fn)(uint32_t widget_id, void* ctx);

@interface NAGenericTarget : NSObject
@property(nonatomic, assign) na_gui_action_fn actionFn;
@property(nonatomic, assign) void* actionCtx;
@property(nonatomic, assign) uint32_t widgetId;
- (void)fire:(id)sender;
@end

NAGenericTarget* na_target_new(uint32_t widget_id, na_gui_action_fn fn, void* ctx);

void na_target_attach(UIControl* control, NAGenericTarget* target);

void na_gui_register_view(UIView* view);
void na_gui_unregister_view(UIView* view);

extern char g_gui_text_buffer[2048];

static inline const char* na_gui_copy_string(NSString* value) {
  g_gui_text_buffer[0] = '\0';
  if (!value) {
    return g_gui_text_buffer;
  }
  const char* utf8 = value.UTF8String;
  if (utf8) {
    strncpy(g_gui_text_buffer, utf8, sizeof(g_gui_text_buffer) - 1);
    g_gui_text_buffer[sizeof(g_gui_text_buffer) - 1] = '\0';
  }
  return g_gui_text_buffer;
}

#endif
