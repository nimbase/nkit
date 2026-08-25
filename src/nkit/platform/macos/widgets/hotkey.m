#import <Carbon/Carbon.h>
#include <string.h>
#include <ctype.h>

#define NA_HOTKEY_SIGNATURE 'ntap'

typedef void (*na_hotkey_fn)(unsigned int shortcut_id, void* ctx);

struct HotKeyEntry {
  unsigned int id;
  EventHotKeyRef ref;
};

static struct HotKeyEntry g_hotkeys[256];
static int g_hotkey_count = 0;
static EventHandlerRef g_handler = NULL;
static na_hotkey_fn g_hotkey_fn = NULL;
static void* g_hotkey_ctx = NULL;

typedef struct {
  const char* token;
  UInt32 code;
} KeyMapping;

static const KeyMapping kKeyCodes[] = {
  {"a", kVK_ANSI_A}, {"b", kVK_ANSI_B}, {"c", kVK_ANSI_C}, {"d", kVK_ANSI_D},
  {"e", kVK_ANSI_E}, {"f", kVK_ANSI_F}, {"g", kVK_ANSI_G}, {"h", kVK_ANSI_H},
  {"i", kVK_ANSI_I}, {"j", kVK_ANSI_J}, {"k", kVK_ANSI_K}, {"l", kVK_ANSI_L},
  {"m", kVK_ANSI_M}, {"n", kVK_ANSI_N}, {"o", kVK_ANSI_O}, {"p", kVK_ANSI_P},
  {"q", kVK_ANSI_Q}, {"r", kVK_ANSI_R}, {"s", kVK_ANSI_S}, {"t", kVK_ANSI_T},
  {"u", kVK_ANSI_U}, {"v", kVK_ANSI_V}, {"w", kVK_ANSI_W}, {"x", kVK_ANSI_X},
  {"y", kVK_ANSI_Y}, {"z", kVK_ANSI_Z},
  {"0", kVK_ANSI_0}, {"1", kVK_ANSI_1}, {"2", kVK_ANSI_2}, {"3", kVK_ANSI_3},
  {"4", kVK_ANSI_4}, {"5", kVK_ANSI_5}, {"6", kVK_ANSI_6}, {"7", kVK_ANSI_7},
  {"8", kVK_ANSI_8}, {"9", kVK_ANSI_9},
  {"f1", kVK_F1}, {"f2", kVK_F2}, {"f3", kVK_F3}, {"f4", kVK_F4},
  {"f5", kVK_F5}, {"f6", kVK_F6}, {"f7", kVK_F7}, {"f8", kVK_F8},
  {"f9", kVK_F9}, {"f10", kVK_F10}, {"f11", kVK_F11}, {"f12", kVK_F12},
  {"f13", kVK_F13}, {"f14", kVK_F14}, {"f15", kVK_F15}, {"f16", kVK_F16},
  {"f17", kVK_F17}, {"f18", kVK_F18}, {"f19", kVK_F19}, {"f20", kVK_F20},
  {"space", kVK_Space},
  {"tab", kVK_Tab},
  {"enter", kVK_Return}, {"return", kVK_Return},
  {"escape", kVK_Escape}, {"esc", kVK_Escape},
  {"backspace", kVK_Delete},
  {"delete", kVK_ForwardDelete}, {"forwarddelete", kVK_ForwardDelete},
  {"insert", kVK_Help}, {"help", kVK_Help},
  {"home", kVK_Home}, {"end", kVK_End},
  {"pageup", kVK_PageUp}, {"pagedown", kVK_PageDown},
  {"up", kVK_UpArrow}, {"down", kVK_DownArrow},
  {"left", kVK_LeftArrow}, {"right", kVK_RightArrow},
  {"plus", kVK_ANSI_Equal}, {"equal", kVK_ANSI_Equal}, {"=", kVK_ANSI_Equal},
  {"minus", kVK_ANSI_Minus}, {"-", kVK_ANSI_Minus},
  {"comma", kVK_ANSI_Comma}, {",", kVK_ANSI_Comma},
  {"period", kVK_ANSI_Period}, {".", kVK_ANSI_Period},
  {"slash", kVK_ANSI_Slash}, {"/", kVK_ANSI_Slash},
  {"backslash", kVK_ANSI_Backslash}, {"\\", kVK_ANSI_Backslash},
  {"semicolon", kVK_ANSI_Semicolon}, {";", kVK_ANSI_Semicolon},
  {"quote", kVK_ANSI_Quote}, {"'", kVK_ANSI_Quote},
  {"leftbracket", kVK_ANSI_LeftBracket}, {"[", kVK_ANSI_LeftBracket},
  {"rightbracket", kVK_ANSI_RightBracket}, {"]", kVK_ANSI_RightBracket},
  {"grave", kVK_ANSI_Grave}, {"backquote", kVK_ANSI_Grave}, {"`", kVK_ANSI_Grave},
  {"num0", kVK_ANSI_Keypad0}, {"num1", kVK_ANSI_Keypad1}, {"num2", kVK_ANSI_Keypad2},
  {"num3", kVK_ANSI_Keypad3}, {"num4", kVK_ANSI_Keypad4}, {"num5", kVK_ANSI_Keypad5},
  {"num6", kVK_ANSI_Keypad6}, {"num7", kVK_ANSI_Keypad7}, {"num8", kVK_ANSI_Keypad8},
  {"num9", kVK_ANSI_Keypad9},
  {"numdec", kVK_ANSI_KeypadDecimal},
  {"numadd", kVK_ANSI_KeypadPlus},
  {"numsub", kVK_ANSI_KeypadMinus},
  {"nummult", kVK_ANSI_KeypadMultiply},
  {"numdiv", kVK_ANSI_KeypadDivide},
  {"numenter", kVK_ANSI_KeypadEnter},
  {NULL, 0}
};

static int lookup_key_code(const char* token, UInt32* out_code) {
  for (int i = 0; kKeyCodes[i].token != NULL; i++) {
    if (strcmp(kKeyCodes[i].token, token) == 0) {
      *out_code = kKeyCodes[i].code;
      return 1;
    }
  }
  return 0;
}

static int is_modifier_token(const char* token) {
  return strcmp(token, "ctrl") == 0 || strcmp(token, "control") == 0 ||
         strcmp(token, "alt") == 0 || strcmp(token, "option") == 0 ||
         strcmp(token, "shift") == 0 || strcmp(token, "cmd") == 0 ||
         strcmp(token, "command") == 0 || strcmp(token, "super") == 0 ||
         strcmp(token, "meta") == 0 || strcmp(token, "cmdorctrl") == 0 ||
         strcmp(token, "commandorcontrol") == 0;
}

static OSStatus hotkey_handler(EventHandlerCallRef next_handler,
                               EventRef event,
                               void* user_data) {
  EventHotKeyID hotkey_id;
  OSStatus status = GetEventParameter(event,
                                      kEventParamDirectObject,
                                      typeEventHotKeyID,
                                      NULL,
                                      sizeof(EventHotKeyID),
                                      NULL,
                                      &hotkey_id);
  if (status != noErr) {
    return eventNotHandledErr;
  }
  if (hotkey_id.signature != NA_HOTKEY_SIGNATURE) {
    return eventNotHandledErr;
  }
  if (g_hotkey_fn) {
    g_hotkey_fn(hotkey_id.id, g_hotkey_ctx);
  }
  return noErr;
}

static void ensure_handler(void) {
  if (g_handler) {
    return;
  }
  EventTypeSpec event_type;
  event_type.eventClass = kEventClassKeyboard;
  event_type.eventKind = kEventHotKeyPressed;
  InstallEventHandler(GetApplicationEventTarget(),
                      hotkey_handler,
                      1,
                      &event_type,
                      NULL,
                      &g_handler);
}

bool na_hotkey_register(unsigned int id, const char* accelerator) {
  if (!accelerator) {
    return false;
  }

  UInt32 modifiers = 0;
  UInt32 keycode = 0;
  char buffer[256];
  strncpy(buffer, accelerator, sizeof(buffer) - 1);
  buffer[sizeof(buffer) - 1] = '\0';

  char* tokens[16];
  int token_count = 0;
  char* current = buffer;
  for (char* p = buffer; ; p++) {
    if (*p == '+' || *p == '\0') {
      char saved = *p;
      *p = '\0';
      char* trimmed = current;
      while (*trimmed == ' ' || *trimmed == '\t') trimmed++;
      char* end = trimmed + strlen(trimmed);
      while (end > trimmed && (end[-1] == ' ' || end[-1] == '\t')) end--;
      *end = '\0';
      if (*trimmed) {
        if (token_count >= 16) {
          return false;
        }
        tokens[token_count++] = trimmed;
      }
      current = p + 1;
      if (saved == '\0') {
        break;
      }
    }
  }

  int has_key = 0;
  char key_token[64] = {0};
  for (int i = 0; i < token_count; i++) {
    char* t = tokens[i];
    for (char* c = t; *c; c++) {
      *c = (char)tolower((unsigned char)*c);
    }
    if (is_modifier_token(t)) {
      if (strcmp(t, "ctrl") == 0 || strcmp(t, "control") == 0) {
        modifiers |= controlKey;
      } else if (strcmp(t, "alt") == 0 || strcmp(t, "option") == 0) {
        modifiers |= optionKey;
      } else if (strcmp(t, "shift") == 0) {
        modifiers |= shiftKey;
      } else {
        modifiers |= cmdKey;
      }
    } else if (!has_key) {
      strncpy(key_token, t, sizeof(key_token) - 1);
      key_token[sizeof(key_token) - 1] = '\0';
      has_key = 1;
    } else {
      return false;
    }
  }

  if (!has_key || !lookup_key_code(key_token, &keycode)) {
    return false;
  }

  ensure_handler();

  EventHotKeyID hotkey_id;
  hotkey_id.signature = NA_HOTKEY_SIGNATURE;
  hotkey_id.id = id;

  EventHotKeyRef ref = NULL;
  OSStatus status = RegisterEventHotKey(keycode,
                                        modifiers,
                                        hotkey_id,
                                        GetApplicationEventTarget(),
                                        0,
                                        &ref);
  if (status != noErr || !ref) {
    return false;
  }

  if (g_hotkey_count < 256) {
    g_hotkeys[g_hotkey_count].id = id;
    g_hotkeys[g_hotkey_count].ref = ref;
    g_hotkey_count++;
  }
  return true;
}

bool na_hotkey_unregister(unsigned int id) {
  for (int i = 0; i < g_hotkey_count; i++) {
    if (g_hotkeys[i].id == id) {
      UnregisterEventHotKey(g_hotkeys[i].ref);
      g_hotkeys[i] = g_hotkeys[g_hotkey_count - 1];
      g_hotkey_count--;
      return true;
    }
  }
  return false;
}

void na_hotkey_set_callback(na_hotkey_fn fn, void* ctx) {
  g_hotkey_fn = fn;
  g_hotkey_ctx = ctx;
}
