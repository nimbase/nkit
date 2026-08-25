import std/[atomics, hashes]

type Id* = distinct uint32

func `==`*(a, b: Id): bool {.borrow.}
func `$`*(id: Id): string {.borrow.}
func hash*(id: Id): Hash {.borrow.}

const
  idInvalid* = 0.Id
  idTypeShift = 24'u32
  idSequenceMask = 0x00FFFFFF'u32
  idMinTypeValue* = 1'u32
  idMaxTypeValue* = 255'u32

const
  typeTagWindow* = 1'u32
  typeTagMenu* = 2'u32
  typeTagMenuItem* = 3'u32
  typeTagTrayIcon* = 4'u32
  typeTagDisplay* = 5'u32
  typeTagShortcut* = 6'u32
  typeTagImage* = 7'u32
  typeTagPreferences* = 8'u32
  typeTagSecureStorage* = 9'u32
  typeTagLaunchAtLogin* = 10'u32
  typeTagMessageDialog* = 11'u32
  typeTagPositioningStrategy* = 12'u32
  typeTagKeyboardMonitor* = 13'u32
  typeTagGuiWidget* = 14'u32

var counters: array[256, Atomic[uint32]]

proc isValidType*(typeValue: uint32): bool {.inline.} =
  typeValue >= idMinTypeValue and typeValue <= idMaxTypeValue

proc allocate*(typeValue: uint32): Id =
  let seqNum = counters[typeValue].fetchAdd(1) + 1
  if (seqNum and idSequenceMask) == 0:
    return idInvalid
  result = ((typeValue shl idTypeShift) or (seqNum and idSequenceMask)).Id

proc getType*(id: Id): uint32 {.inline.} =
  (uint32(id) shr idTypeShift) and 0xFF'u32

proc getSequence*(id: Id): uint32 {.inline.} =
  uint32(id) and idSequenceMask

proc isValid*(id: Id): bool {.inline.} =
  uint32(id) != 0 and isValidType(id.getType())

proc decompose*(id: Id): tuple[typeValue: uint32, sequence: uint32] {.inline.} =
  (id.getType(), id.getSequence())

proc currentCount*(typeValue: uint32): uint32 {.inline.} =
  counters[typeValue].load()

proc resetCounter*(typeValue: uint32) {.inline.} =
  counters[typeValue].store(0)
