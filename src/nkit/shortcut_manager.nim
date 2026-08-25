import std/[tables, strutils]
import nkit/foundation/event_emitter
import nkit/shortcut
import nkit/platform/macos/dispatcher_macos

when defined(macosx) or defined(ios):
  import nkit/platform/macos/nsfunctions

const modifierTokens = [
  "ctrl", "control", "alt", "option", "shift", "cmd", "command",
  "super", "meta", "cmdorctrl", "commandorcontrol"
]

func allDigits(s: string): bool {.inline.} =
  if s.len == 0:
    return false
  for c in s:
    if c notin {'0'..'9'}:
      return false
  true

const namedKeyTokens = [
  "space", "tab", "enter", "return", "escape", "esc", "backspace",
  "forwarddelete", "delete", "insert", "help",
  "home", "end", "pageup", "pagedown", "up", "down", "left", "right",
  "plus", "minus", "equal", "comma", "period", "slash", "backslash",
  "semicolon", "quote", "leftbracket", "rightbracket", "grave", "backquote",
  "numdec", "numadd", "numsub", "nummult", "numdiv", "numenter"
]

func isNamedKeyToken(token: string): bool =
  if token.len == 2 and token[0] == 'f' and token[1] in {'1'..'9'}:
    return true
  if token.len == 3 and token[0] == 'f':
    let numPart = token[1 ..< token.len]
    if numPart.allDigits:
      let n = parseInt(numPart)
      if n >= 10 and n <= 24:
        return true
  if token.len == 4 and token.startsWith("num") and token[3] in {'0'..'9'}:
    return true
  for named in namedKeyTokens:
    if token == named:
      return true
  false

proc isValidAccelerator*(accelerator: string): bool =
  if accelerator.len == 0:
    return false
  var parts: seq[string]
  var current = ""
  for ch in accelerator:
    case ch
    of '+':
      if current.len > 0:
        parts.add(current)
        current = ""
    of ' ', '\t':
      discard
    else:
      current.add(ch)
  if current.len > 0:
    parts.add(current)
  if parts.len == 0:
    return false
  var hasKey = false
  for raw in parts:
    let token = raw.toLowerAscii()
    var isModifier = false
    for m in modifierTokens:
      if token == m:
        isModifier = true
        break
    if isModifier:
      continue
    if hasKey:
      return false
    let isSingleChar = token.len == 1 and (
      token[0].isAlphaAscii or token[0].isDigit or
      token[0] in {',', '.', '/', '\\', ';', '\'', '[', ']', '`', '=', '-'})
    if not isSingleChar and not isNamedKeyToken(token):
      return false
    hasKey = true
  hasKey

type Shortcut* = ref object
  id*: ShortcutId
  accelerator*: string
  description*: string
  scope*: ShortcutScope
  enabledValue*: bool
  callback*: proc() {.closure.}

proc getId*(s: Shortcut): ShortcutId =
  s.id

proc getAccelerator*(s: Shortcut): string =
  s.accelerator

proc getDescription*(s: Shortcut): string =
  s.description

proc setDescription*(s: Shortcut, description: string) =
  s.description = description

proc getScope*(s: Shortcut): ShortcutScope =
  s.scope

proc setEnabled*(s: Shortcut, enabled: bool) =
  s.enabledValue = enabled

proc isEnabled*(s: Shortcut): bool =
  s.enabledValue

proc invoke*(s: Shortcut) =
  if not s.callback.isNil:
    s.callback()

type ShortcutManager* = ref object of EventEmitter[ShortcutEvent]
  enabledValue*: bool
  nextId*: uint32
  byId*: Table[uint32, Shortcut]
  byAccelerator*: Table[string, Shortcut]

proc newShortcutManager*(): ShortcutManager =
  result = ShortcutManager(
    enabledValue: true,
    nextId: 1)
  initEmitter(result)

proc isSupported*(sm: ShortcutManager): bool =
  when defined(macosx) or defined(ios):
    true
  else:
    false

proc isAvailable*(sm: ShortcutManager, accelerator: string): bool =
  accelerator notin sm.byAccelerator

proc platformRegister(sc: Shortcut): bool =
  when defined(macosx) or defined(ios):
    naHotkeyRegister(uint32(sc.id), sc.accelerator.cstring)
  else:
    false

proc platformUnregister(sc: Shortcut): bool =
  when defined(macosx) or defined(ios):
    naHotkeyUnregister(uint32(sc.id))
  else:
    false

proc get*(sm: ShortcutManager, id: ShortcutId): Shortcut =
  sm.byId.getOrDefault(uint32(id))

proc getByAccelerator*(sm: ShortcutManager, accelerator: string): Shortcut =
  sm.byAccelerator.getOrDefault(accelerator)

proc register*(sm: ShortcutManager, options: ShortcutOptions): Shortcut =
  if not isValidAccelerator(options.accelerator):
    sm.emitAsync(newShortcutRegistrationFailedEvent(
      0.ShortcutId, options.accelerator, "Invalid accelerator format"))
    return nil
  if not sm.isAvailable(options.accelerator):
    sm.emitAsync(newShortcutRegistrationFailedEvent(
      0.ShortcutId, options.accelerator, "Accelerator already registered"))
    return nil

  let id = ShortcutId(sm.nextId)
  sm.nextId += 1

  let sc = Shortcut(
    id: id,
    accelerator: options.accelerator,
    description: options.description,
    scope: options.scope,
    enabledValue: options.enabled,
    callback: options.callback)

  if not platformRegister(sc):
    sm.emitAsync(newShortcutRegistrationFailedEvent(
      id, options.accelerator, "Platform registration failed"))
    return nil

  sm.byId[uint32(id)] = sc
  sm.byAccelerator[options.accelerator] = sc
  sm.emitAsync(newShortcutEvent[ShortcutRegisteredEvent](id, options.accelerator))
  result = sc

proc register*(sm: ShortcutManager,
               accelerator: string,
               callback: proc() {.closure.}): Shortcut =
  var options = defaultShortcutOptions(accelerator)
  options.callback = callback
  sm.register(options)

proc unregister*(sm: ShortcutManager, id: ShortcutId): bool =
  let key = uint32(id)
  if key notin sm.byId:
    return false
  let sc = sm.byId[key]
  discard platformUnregister(sc)
  sm.byAccelerator.del(sc.accelerator)
  sm.byId.del(key)
  sm.emitAsync(newShortcutEvent[ShortcutUnregisteredEvent](id, sc.accelerator))
  true

proc unregisterByAccelerator*(sm: ShortcutManager, accelerator: string): bool =
  if accelerator notin sm.byAccelerator:
    return false
  let id = sm.byAccelerator[accelerator].id
  sm.unregister(id)

proc unregisterAll*(sm: ShortcutManager): int =
  var ids: seq[uint32] = @[]
  for key in sm.byId.keys:
    ids.add(key)
  var count = 0
  for key in ids:
    if sm.unregister(ShortcutId(key)):
      count += 1
  count

proc getAll*(sm: ShortcutManager): seq[Shortcut] =
  for sc in sm.byId.values:
    result.add(sc)

proc getByScope*(sm: ShortcutManager, scope: ShortcutScope): seq[Shortcut] =
  for sc in sm.byId.values:
    if sc.scope == scope:
      result.add(sc)

proc setEnabled*(sm: ShortcutManager, enabled: bool) =
  sm.enabledValue = enabled

proc isEnabled*(sm: ShortcutManager): bool =
  sm.enabledValue

proc emitShortcutActivated*(sm: ShortcutManager, id: ShortcutId, accelerator: string) =
  sm.emitAsync(newShortcutEvent[ShortcutActivatedEvent](id, accelerator))

var sharedShortcutManagerInstance: ShortcutManager

proc sharedShortcutManager*(): ShortcutManager =
  if sharedShortcutManagerInstance.isNil:
    result = newShortcutManager()
    when defined(macosx) or defined(ios):
      proc hotkeyTrampoline(id: cuint, ctx: pointer) {.cdecl.} =
        let sm = sharedShortcutManager()
        let sid = uint32(id).ShortcutId
        let sc = sm.get(sid)
        if sc.isNil:
          return
        if not sm.enabledValue or not sc.enabledValue:
          return
        sm.emitAsync(newShortcutEvent[ShortcutActivatedEvent](sid, sc.accelerator))
        sc.invoke()
      naHotkeySetCallback(hotkeyTrampoline, nil)
    sharedShortcutManagerInstance = result
  else:
    result = sharedShortcutManagerInstance
