import std/tables
import nkit/storage

type SecureStorage* = ref object of Storage
  scope*: string

proc newSecureStorage*(scope = "default"): SecureStorage =
  SecureStorage(scope: scope)

proc isAvailable*(): bool =
  false

method set*(s: SecureStorage, key, value: string): bool =
  false

method get*(s: SecureStorage, key: string, defaultValue = ""): string =
  defaultValue

method remove*(s: SecureStorage, key: string): bool =
  false

method clear*(s: SecureStorage): bool =
  false

method contains*(s: SecureStorage, key: string): bool =
  false

method getKeys*(s: SecureStorage): seq[string] =
  @[]

method getSize*(s: SecureStorage): int =
  0

method getAll*(s: SecureStorage): Table[string, string] =
  initTable[string, string]()

proc getScope*(s: SecureStorage): string =
  s.scope
