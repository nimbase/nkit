import nkit/foundation/event
import nkit/foundation/geometry
import nkit/foundation/id_allocator

when defined(ios):
  import nkit/platform/ios/uifunctions
elif defined(macosx):
  import nkit/platform/macos/nsfunctions

type
  DisplayId* = Id

  DisplayOrientation* = enum
    doPortrait = 0
    doLandscape = 90
    doPortraitFlipped = 180
    doLandscapeFlipped = 270

type Display* = ref object of RootObj
  id*: DisplayId
  nativeKey*: uint32

proc newDisplay*(nativeKey: uint32): Display =
  result = Display(
    id: allocate(typeTagDisplay).DisplayId,
    nativeKey: nativeKey)

func getId*(d: Display): DisplayId =
  d.id

proc getName*(d: Display): string =
  when defined(macosx) or defined(ios):
    $naScreenGetName(d.nativeKey)
  else:
    ""

proc getPosition*(d: Display): Point =
  when defined(macosx) or defined(ios):
    var x, y, w, h: float64
    naScreenGetFrame(d.nativeKey, addr x, addr y, addr w, addr h)
    Point(x: x, y: y)
  else:
    Point()

proc getSize*(d: Display): Size =
  when defined(macosx) or defined(ios):
    var x, y, w, h: float64
    naScreenGetFrame(d.nativeKey, addr x, addr y, addr w, addr h)
    Size(width: w, height: h)
  else:
    Size()

proc getWorkArea*(d: Display): Rectangle =
  when defined(macosx) or defined(ios):
    var x, y, w, h: float64
    naScreenGetWorkArea(d.nativeKey, addr x, addr y, addr w, addr h)
    Rectangle(x: x, y: y, width: w, height: h)
  else:
    Rectangle()

func getScaleFactor*(d: Display): float64 =
  when defined(macosx) or defined(ios):
    naScreenGetScaleFactor(d.nativeKey)
  else:
    1.0

proc isPrimary*(d: Display): bool =
  when defined(macosx) or defined(ios):
    naScreenIsPrimary(d.nativeKey)
  else:
    false

proc getOrientation*(d: Display): DisplayOrientation =
  let s = d.getSize()
  if s.width > s.height:
    doLandscape
  else:
    doPortrait

func getRefreshRate*(d: Display): int =
  when defined(macosx) or defined(ios):
    int(naScreenGetRefreshRate(d.nativeKey))
  else:
    60

func getBitDepth*(d: Display): int =
  32

# Events

type
  DisplayEvent* = ref object of Event
    display*: Display
  DisplayAddedEvent* = ref object of DisplayEvent
  DisplayRemovedEvent* = ref object of DisplayEvent
  DisplayChangedEvent* = ref object of DisplayEvent

method typeName(e: DisplayEvent): string = "DisplayEvent"
method typeName(e: DisplayAddedEvent): string = "DisplayAddedEvent"
method typeName(e: DisplayRemovedEvent): string = "DisplayRemovedEvent"
method typeName(e: DisplayChangedEvent): string = "DisplayChangedEvent"

proc newDisplayEvent*[T: DisplayEvent](display: Display): T =
  result = T(display: display)
  discard stamp(result)
