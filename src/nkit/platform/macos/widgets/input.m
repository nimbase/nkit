#import <Cocoa/Cocoa.h>
#import "gui_common.h"

typedef void (*na_input_event_fn)(uint32_t widget_id, void* ctx);

static na_input_event_fn g_input_fn = NULL;
static void* g_input_ctx = NULL;

void na_input_set_event_callback(na_input_event_fn fn, void* ctx) {
  g_input_fn = fn;
  g_input_ctx = ctx;
}

// --- focus channel (keyboard focus in/out) ---
// Declared before the delegate: controlTextDidBegin/DidEndEditing route
// here as well as to the legacy change/submit channel.

typedef void (*na_input_focus_fn)(uint32_t widget_id, bool focused, void* ctx);

static na_input_focus_fn g_input_focus_fn = NULL;
static void* g_input_focus_ctx = NULL;

void na_input_set_focus_callback(na_input_focus_fn fn, void* ctx) {
  g_input_focus_fn = fn;
  g_input_focus_ctx = ctx;
}

@interface NAInputDelegate : NSObject <NSTextFieldDelegate>
@property(nonatomic, assign) uint32_t widgetId;
@end

@implementation NAInputDelegate
- (void)controlTextDidChange:(NSNotification*)notification {
  if (g_input_fn) {
    g_input_fn(_widgetId, g_input_ctx);
  }
}
- (void)controlTextDidBeginEditing:(NSNotification*)notification {
  (void)notification;
  if (g_input_focus_fn) {
    g_input_focus_fn(_widgetId, true, g_input_focus_ctx);
  }
}
- (void)controlTextDidEndEditing:(NSNotification*)notification {
  if (g_input_fn) {
    g_input_fn(_widgetId, (void*)1);
  }
  if (g_input_focus_fn) {
    g_input_focus_fn(_widgetId, false, g_input_focus_ctx);
  }
}
@end

// --- hover channel (pointer enter/leave via tracking areas) ---

typedef void (*na_input_hover_fn)(uint32_t widget_id, bool entered, void* ctx);

static na_input_hover_fn g_input_hover_fn = NULL;
static void* g_input_hover_ctx = NULL;

void na_input_set_hover_callback(na_input_hover_fn fn, void* ctx) {
  g_input_hover_fn = fn;
  g_input_hover_ctx = ctx;
}

@interface NAInputHoverOwner : NSObject
@property(nonatomic, assign) uint32_t widgetId;
@end

@implementation NAInputHoverOwner
- (void)mouseEntered:(NSEvent*)event {
  (void)event;
  if (g_input_hover_fn) {
    g_input_hover_fn(_widgetId, true, g_input_hover_ctx);
  }
}
- (void)mouseExited:(NSEvent*)event {
  (void)event;
  if (g_input_hover_fn) {
    g_input_hover_fn(_widgetId, false, g_input_hover_ctx);
  }
}
@end

// --- key channel (physical key down/up while a field has focus) ---
// Modifier bits mirror the Linux mapping: 0=Shift, 1=Control, 2=Alt,
// 3=Command. keyval is the first UTF-32 code point of
// charactersIgnoringModifiers (function keys arrive in the 0xF700 range),
// falling back to the hardware keyCode when empty.

typedef void (*na_input_key_fn)(uint32_t widget_id, uint32_t keyval,
                                uint32_t keycode, uint32_t mods, bool pressed,
                                void* ctx);

static na_input_key_fn g_input_key_fn = NULL;
static void* g_input_key_ctx = NULL;

static NSMutableDictionary<NSValue*, NSNumber*>* g_input_field_ids = nil;

static uint32_t nkit_mods_from_flags(NSEventModifierFlags flags) {
  uint32_t r = 0;
  if (flags & NSEventModifierFlagShift) {
    r |= 1u << 0;
  }
  if (flags & NSEventModifierFlagControl) {
    r |= 1u << 1;
  }
  if (flags & NSEventModifierFlagOption) {
    r |= 1u << 2;
  }
  if (flags & NSEventModifierFlagCommand) {
    r |= 1u << 3;
  }
  return r;
}

static void ensure_input_key_monitor(void) {
  static BOOL installed = NO;
  if (installed) {
    return;
  }
  installed = YES;
  [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskKeyDown | NSEventMaskKeyUp)
      handler:^NSEvent*(NSEvent* event) {
        if (g_input_key_fn) {
          NSResponder* fr = [[NSApp keyWindow] firstResponder];
          NSTextField* field = nil;
          if ([fr isKindOfClass:[NSText class]]) {
            id del = [(NSText*)fr delegate];
            if ([del isKindOfClass:[NSTextField class]]) {
              field = (NSTextField*)del;
            }
          } else if ([fr isKindOfClass:[NSTextField class]]) {
            field = (NSTextField*)fr;
          }
          if (field) {
            NSNumber* wid = g_input_field_ids[[NSValue valueWithPointer:(__bridge const void*)field]];
            if (wid) {
              NSString* chars = [event charactersIgnoringModifiers];
              uint32_t keyval = 0;
              if (chars.length == 1) {
                keyval = [chars characterAtIndex:0];
              } else if (chars.length >= 2) {
                unichar hi = [chars characterAtIndex:0];
                if (CFStringIsSurrogateHighCharacter(hi)) {
                  keyval = CFStringGetLongCharacterForSurrogatePair(
                      hi, [chars characterAtIndex:1]);
                } else {
                  keyval = hi;
                }
              } else {
                keyval = (uint32_t)[event keyCode];
              }
              g_input_key_fn([wid unsignedIntValue], keyval,
                             (uint32_t)[event keyCode],
                             nkit_mods_from_flags([event modifierFlags]),
                             [event type] == NSEventTypeKeyDown,
                             g_input_key_ctx);
            }
          }
        }
        return event;
      }];
}

void na_input_set_key_callback(na_input_key_fn fn, void* ctx) {
  g_input_key_fn = fn;
  g_input_key_ctx = ctx;
  if (fn) {
    ensure_input_key_monitor();
  }
}

static NSMutableDictionary<NSNumber*, NAInputDelegate*>* g_input_delegates = nil;
static NSMutableDictionary<NSNumber*, NAInputHoverOwner*>* g_input_hover_owners = nil;

static void ensure_input_tables(void) {
  static BOOL initialized = NO;
  if (!initialized) {
    initialized = YES;
    g_input_delegates = [NSMutableDictionary dictionary];
    g_input_hover_owners = [NSMutableDictionary dictionary];
    g_input_field_ids = [NSMutableDictionary dictionary];
  }
}

#define NA_INPUT_STYLE_SINGLE_LINE 0
#define NA_INPUT_STYLE_SECURE 1
#define NA_INPUT_STYLE_SEARCH 2

void* na_input_create(uint32_t widget_id, int style) {
  ensure_input_tables();
  NSTextField* field = nil;
  switch (style) {
    case NA_INPUT_STYLE_SECURE:
      field = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 0, 160, 24)];
      break;
    case NA_INPUT_STYLE_SEARCH:
      field = [[NSSearchField alloc] initWithFrame:NSMakeRect(0, 0, 160, 28)];
      break;
    default:
      field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 160, 24)];
      break;
  }
  field.bezelStyle = NSTextFieldRoundedBezel;
  NAInputDelegate* delegate = [[NAInputDelegate alloc] init];
  delegate.widgetId = widget_id;
  g_input_delegates[@(widget_id)] = delegate;
  field.delegate = delegate;
  NAInputHoverOwner* hoverOwner = [[NAInputHoverOwner alloc] init];
  hoverOwner.widgetId = widget_id;
  g_input_hover_owners[@(widget_id)] = hoverOwner;
  NSTrackingArea* hoverArea = [[NSTrackingArea alloc]
      initWithRect:NSZeroRect
           options:(NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways |
                    NSTrackingInVisibleRect)
             owner:hoverOwner
          userInfo:nil];
  [field addTrackingArea:hoverArea];
  g_input_field_ids[[NSValue valueWithPointer:(__bridge const void*)field]] =
      @(widget_id);
  na_gui_register_view(field);
  return (__bridge void*)field;
}

void na_input_free(uint32_t widget_id, void* ptr) {
  ensure_input_tables();
  NSTextField* field = (__bridge NSTextField*)ptr;
  if (field) {
    NAInputHoverOwner* hoverOwner = g_input_hover_owners[@(widget_id)];
    if (hoverOwner) {
      for (NSTrackingArea* area in [field.trackingAreas copy]) {
        if (area.owner == hoverOwner) {
          [field removeTrackingArea:area];
        }
      }
    }
    [field removeFromSuperview];
    field.delegate = nil;
    na_gui_unregister_view(field);
    g_input_field_ids[[NSValue valueWithPointer:(__bridge const void*)field]] = nil;
  }
  [g_input_delegates removeObjectForKey:@(widget_id)];
  [g_input_hover_owners removeObjectForKey:@(widget_id)];
}

void na_input_set_text(void* ptr, const char* text) {
  NSTextField* field = (__bridge NSTextField*)ptr;
  if (field) {
    field.stringValue = text ? [NSString stringWithUTF8String:text] : @"";
  }
}

const char* na_input_get_text(void* ptr) {
  NSTextField* field = (__bridge NSTextField*)ptr;
  return field ? na_gui_copy_string(field.stringValue) : na_gui_copy_string(nil);
}

void na_input_set_placeholder(void* ptr, const char* placeholder) {
  NSTextField* field = (__bridge NSTextField*)ptr;
  if (field) {
    field.placeholderString =
        placeholder ? [NSString stringWithUTF8String:placeholder] : nil;
  }
}

const char* na_input_get_placeholder(void* ptr) {
  NSTextField* field = (__bridge NSTextField*)ptr;
  return field && field.placeholderString
             ? na_gui_copy_string(field.placeholderString)
             : na_gui_copy_string(nil);
}

void na_input_set_editable(void* ptr, bool editable) {
  NSTextField* field = (__bridge NSTextField*)ptr;
  if (field) {
    field.editable = editable ? YES : NO;
  }
}

bool na_input_is_editable(void* ptr) {
  NSTextField* field = (__bridge NSTextField*)ptr;
  return field && field.editable == YES;
}

void na_input_focus(uint32_t widget_id, void* ptr) {
  NSTextField* field = (__bridge NSTextField*)ptr;
  if (field && field.window) {
    [field.window makeFirstResponder:field];
  }
}

void na_input_fire_change(uint32_t widget_id) {
  if (g_input_fn) {
    g_input_fn(widget_id, NULL);
  }
}

void na_input_fire_submit(uint32_t widget_id) {
  if (g_input_fn) {
    g_input_fn(widget_id, (void*)1);
  }
}
