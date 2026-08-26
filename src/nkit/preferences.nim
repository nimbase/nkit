import std/tables
import nkit/storage

when defined(ios):
  import nkit/platform/ios/uifunctions
elif defined(macosx):
  import nkit/platform/macos/nsfunctions

const keyBufferSize = 512

type Preferences* = ref object of Storage
  scope*: string
  handle: pointer
  memory: Table[string, string]

proc newPreferences*(scope = "default"): Preferences =
  result = Preferences(scope: scope)
  when defined(macosx) and not defined(ios):
    result.handle = naPrefsOpen(scope.cstring)

proc close*(p: Preferences) =
  when defined(macosx) and not defined(ios):
    if p.handle != nil:
      naPrefsClose(p.handle)
      p.handle = nil

method set*(p: Preferences, key, value: string): bool =
  when defined(macosx) and not defined(ios):
    naPrefsSet(p.handle, key.cstring, value.cstring)
  else:
    p.memory[key] = value
    true

method get*(p: Preferences, key: string, defaultValue = ""): string =
  when defined(macosx) and not defined(ios):
    var buf: array[keyBufferSize, char]
    if naPrefsGet(p.handle, key.cstring, cast[cstring](addr buf[0]), cint(keyBufferSize)):
      $cast[cstring](addr buf[0])
    else:
      defaultValue
  else:
    p.memory.getOrDefault(key, defaultValue)

method remove*(p: Preferences, key: string): bool =
  when defined(macosx) and not defined(ios):
    naPrefsRemove(p.handle, key.cstring)
  else:
    p.memory.del(key)
    true

method clear*(p: Preferences): bool =
  when defined(macosx) and not defined(ios):
    naPrefsClear(p.handle)
  else:
    p.memory.clear()
    true

method contains*(p: Preferences, key: string): bool =
  when defined(macosx) and not defined(ios):
    naPrefsContains(p.handle, key.cstring)
  else:
    key in p.memory

method getKeys*(p: Preferences): seq[string] =
  when defined(macosx) and not defined(ios):
    naPrefsRefreshKeys(p.handle)
    let count = int(naPrefsSnapshotCount())
    result = newSeqOfCap[string](count)
    for i in 0 ..< count:
      var buf: array[keyBufferSize, char]
      if naPrefsSnapshotKey(cint(i), cast[cstring](addr buf[0]), cint(keyBufferSize)):
        result.add($cast[cstring](addr buf[0]))
  else:
    for k in p.memory.keys:
      result.add(k)

method getSize*(p: Preferences): int =
  when defined(macosx) and not defined(ios):
    int(naPrefsSize(p.handle))
  else:
    p.memory.len

method getAll*(p: Preferences): Table[string, string] =
  when defined(macosx) and not defined(ios):
    result = initTable[string, string]()
    for k in p.getKeys():
      let v = p.get(k)
      if v.len > 0:
        result[k] = v
  else:
    result = p.memory

proc getScope*(p: Preferences): string =
  p.scope
