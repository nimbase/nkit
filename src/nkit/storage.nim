import std/tables

type Storage* = ref object of RootObj

method set*(s: Storage, key, value: string): bool {.base.} =
  false

method get*(s: Storage, key: string, defaultValue = ""): string {.base.} =
  defaultValue

method remove*(s: Storage, key: string): bool {.base.} =
  false

method clear*(s: Storage): bool {.base.} =
  false

method contains*(s: Storage, key: string): bool {.base.} =
  false

method getKeys*(s: Storage): seq[string] {.base.} =
  @[]

method getSize*(s: Storage): int {.base.} =
  0

method getAll*(s: Storage): Table[string, string] {.base.} =
  initTable[string, string]()
