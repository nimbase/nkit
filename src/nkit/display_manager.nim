import std/[tables]
import nkit/foundation/event_emitter
import nkit/foundation/geometry
import nkit/positioning_strategy
import nkit/display

when defined(macosx) or defined(ios):
  import nkit/platform/macos/nsfunctions

type NativeDisplayInfo* = object
  key*: uint32
  isPrimary*: bool

type DisplayManager* = ref object of EventEmitter[DisplayEvent]
  displays: Table[uint32, Display]

proc enumerateNativeDisplays(): seq[NativeDisplayInfo] =
  when defined(macosx) or defined(ios):
    let count = int(naScreenCount())
    result = newSeqOfCap[NativeDisplayInfo](count)
    for i in 0 ..< count:
      let key = naScreenDisplayId(cint(i))
      if key != 0:
        result.add(NativeDisplayInfo(key: key, isPrimary: i == 0))
  else:
    result = @[]

proc reconcile*(dm: DisplayManager,
                natives: seq[NativeDisplayInfo],
                added: var seq[Display],
                removed: var seq[Display]): seq[Display] =
  var next = initTable[uint32, Display]()
  result = newSeqOfCap[Display](natives.len)
  for native in natives:
    var display: Display
    if dm.displays.hasKey(native.key):
      display = dm.displays[native.key]
    else:
      display = newDisplay(native.key)
      added.add(display)
    next[native.key] = display
    result.add(display)
  for key, display in dm.displays:
    if not next.hasKey(key):
      removed.add(display)
  dm.displays = move(next)

proc handleDisplaysChanged*(dm: DisplayManager) =
  var added = newSeq[Display]()
  var removed = newSeq[Display]()
  discard dm.reconcile(enumerateNativeDisplays(), added, removed)
  for display in added:
    dm.emit(newDisplayEvent[DisplayAddedEvent](display))
  for display in removed:
    dm.emit(newDisplayEvent[DisplayRemovedEvent](display))

proc getAllDisplays*(dm: DisplayManager): seq[Display] =
  var added = newSeq[Display]()
  var removed = newSeq[Display]()
  dm.reconcile(enumerateNativeDisplays(), added, removed)

proc getPrimaryDisplay*(dm: DisplayManager): Display =
  let natives = enumerateNativeDisplays()
  var added = newSeq[Display]()
  var removed = newSeq[Display]()
  let displays = dm.reconcile(natives, added, removed)
  for i in 0 ..< natives.len:
    if natives[i].isPrimary:
      return displays[i]
  if displays.len > 0:
    return displays[0]

proc getCursorPosition*(_: DisplayManager): Point =
  when defined(macosx) or defined(ios):
    var x, y: float64
    naScreenGetCursorPosition(addr x, addr y)
    Point(x: x, y: y)
  else:
    Point()

when defined(macosx) or defined(ios):
  proc screensChangedTrampoline(ctx: pointer) {.cdecl.} =
    cast[DisplayManager](ctx).handleDisplaysChanged()

var sharedDisplayManagerInstance: DisplayManager

proc sharedDisplayManager*(): DisplayManager =
  if sharedDisplayManagerInstance.isNil:
    let dm = DisplayManager()
    initEmitter(dm)
    when defined(macosx) or defined(ios):
      naScreenSetChangedCallback(screensChangedTrampoline, cast[pointer](dm))
    setCursorPositionProvider(proc(): Point = dm.getCursorPosition())
    discard dm.getAllDisplays()
    sharedDisplayManagerInstance = dm
  result = sharedDisplayManagerInstance
