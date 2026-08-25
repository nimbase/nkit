import nkit/foundation/event

type DialogModality* = enum
  dmNone
  dmApplication
  dmWindow

type Dialog* = ref object of RootObj
  modality*: DialogModality

method open*(d: Dialog): bool {.base.} =
  false

method close*(d: Dialog): bool {.base.} =
  false
