import std/strutils
import event

type ModifierKey* = distinct uint32

const
  modNone* = 0.ModifierKey
  modShift* = (1'u32 shl 0).ModifierKey
  modCtrl* = (1'u32 shl 1).ModifierKey
  modAlt* = (1'u32 shl 2).ModifierKey
  modMeta* = (1'u32 shl 3).ModifierKey
  modFn* = (1'u32 shl 4).ModifierKey
  modCapsLock* = (1'u32 shl 5).ModifierKey
  modNumLock* = (1'u32 shl 6).ModifierKey
  modScrollLock* = (1'u32 shl 7).ModifierKey

func `or`*(a, b: ModifierKey): ModifierKey {.borrow.}
func `and`*(a, b: ModifierKey): ModifierKey {.borrow.}
func `==`*(a, b: ModifierKey): bool {.borrow.}
func `$`*(a: ModifierKey): string {.borrow.}

func hasMods*(mods, wanted: ModifierKey): bool {.inline.} =
  (mods and wanted) != modNone

type KeyboardAccelerator* = object
  modifiers*: ModifierKey
  key*: string

func keyboardAccelerator*(key: string, modifiers: ModifierKey = modNone): KeyboardAccelerator =
  KeyboardAccelerator(key: key, modifiers: modifiers)

func isEmpty*(acc: KeyboardAccelerator): bool {.inline.} =
  acc.key.len == 0

proc toString*(acc: KeyboardAccelerator): string =
  if acc.isEmpty:
    return ""
  var parts = newSeq[string]()
  let m = acc.modifiers
  if m.hasMods(modCtrl):
    parts.add("Ctrl")
  if m.hasMods(modAlt):
    parts.add("Alt")
  if m.hasMods(modShift):
    parts.add("Shift")
  if m.hasMods(modMeta):
    when defined(macosx) and not defined(ios):
      parts.add("Cmd")
    elif defined(windows):
      parts.add("Win")
    else:
      parts.add("Super")
  parts.add(acc.key)
  result = parts.join("+")

type
  KeyboardEvent* = ref object of Event
    keycode*: int

method typeName(e: KeyboardEvent): string = "KeyboardEvent"

proc newKeyboardEvent*(keycode: int): KeyboardEvent =
  stamp(KeyboardEvent(keycode: keycode))

type KeyPressedEvent* = ref object of KeyboardEvent

method typeName(e: KeyPressedEvent): string = "KeyPressedEvent"

proc newKeyPressedEvent*(keycode: int): KeyPressedEvent =
  stamp(KeyPressedEvent(keycode: keycode))

type KeyReleasedEvent* = ref object of KeyboardEvent

method typeName(e: KeyReleasedEvent): string = "KeyReleasedEvent"

proc newKeyReleasedEvent*(keycode: int): KeyReleasedEvent =
  stamp(KeyReleasedEvent(keycode: keycode))

type ModifierKeysChangedEvent* = ref object of KeyboardEvent
  modifierKeys*: uint32

method typeName(e: ModifierKeysChangedEvent): string = "ModifierKeysChangedEvent"

proc newModifierKeysChangedEvent*(modifierKeys: uint32): ModifierKeysChangedEvent =
  var e = ModifierKeysChangedEvent(keycode: 0, modifierKeys: modifierKeys)
  stamp(e)
