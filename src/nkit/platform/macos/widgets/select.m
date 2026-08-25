#import <Cocoa/Cocoa.h>
#import "gui_common.h"

typedef void (*na_select_event_fn)(uint32_t widget_id, int64_t index, void* ctx);

static na_select_event_fn g_select_fn = NULL;
static void* g_select_ctx = NULL;

static NSMutableDictionary<NSNumber*, NAGenericTarget*>* g_select_targets = nil;

static void ensure_select_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_select_targets = [NSMutableDictionary dictionary];
  }
}

static void select_action_thunk(uint32_t widget_id, void* ctx) {
  NSPopUpButton* button = (__bridge NSPopUpButton*)ctx;
  if (g_select_fn && button) {
    g_select_fn(widget_id, (int64_t)[button indexOfSelectedItem], g_select_ctx);
  }
}

void na_select_set_event_callback(na_select_event_fn fn, void* ctx) {
  g_select_fn = fn;
  g_select_ctx = ctx;
}

void* na_select_create(uint32_t widget_id) {
  ensure_select_tables();
  NSPopUpButton* button = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 140, 26)
                                                    pullsDown:NO];
  NAGenericTarget* target = na_target_new(widget_id, select_action_thunk, (__bridge void*)button);
  g_select_targets[@(widget_id)] = target;
  na_target_attach(button, target);
  na_gui_register_view(button);
  return (__bridge void*)button;
}

void na_select_free(uint32_t widget_id, void* ptr) {
  ensure_select_tables();
  NSPopUpButton* button = (__bridge NSPopUpButton*)ptr;
  if (button) {
    [button removeFromSuperview];
    na_gui_unregister_view(button);
  }
  [g_select_targets removeObjectForKey:@(widget_id)];
}

void na_select_add_item(void* ptr, const char* title) {
  NSPopUpButton* button = (__bridge NSPopUpButton*)ptr;
  if (button && title) {
    [button addItemWithTitle:[NSString stringWithUTF8String:title]];
  }
}

void na_select_clear(void* ptr) {
  NSPopUpButton* button = (__bridge NSPopUpButton*)ptr;
  if (button) {
    [button removeAllItems];
  }
}

int na_select_count(void* ptr) {
  NSPopUpButton* button = (__bridge NSPopUpButton*)ptr;
  return button ? (int)button.itemArray.count : 0;
}

int64_t na_select_selected(void* ptr) {
  NSPopUpButton* button = (__bridge NSPopUpButton*)ptr;
  return button ? (int64_t)button.indexOfSelectedItem : -1;
}

void na_select_choose(void* ptr, int64_t index) {
  NSPopUpButton* button = (__bridge NSPopUpButton*)ptr;
  if (button && index >= 0 && index < (int64_t)button.itemArray.count) {
    [button selectItemAtIndex:index];
  }
}

const char* na_select_selected_title(void* ptr) {
  NSPopUpButton* button = (__bridge NSPopUpButton*)ptr;
  return button ? na_gui_copy_string(button.titleOfSelectedItem) : na_gui_copy_string(nil);
}
