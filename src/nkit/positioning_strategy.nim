import foundation/geometry

type PositioningStrategyType* = enum
  pstAbsolute
  pstCursorPosition
  pstRelative

var cursorPositionProvider: proc(): Point {.closure.}

proc setCursorPositionProvider*(provider: proc(): Point {.closure.}) =
  cursorPositionProvider = provider

type PositioningStrategy* = object
  case kind*: PositioningStrategyType
  of pstAbsolute:
    absolutePosition*: Point
  of pstCursorPosition:
    discard
  of pstRelative:
    relativeRect*: Rectangle
    relativeOffset*: Point
    rectResolver*: proc(): Rectangle {.closure.}

proc absoluteStrategy*(position: Point): PositioningStrategy =
  PositioningStrategy(kind: pstAbsolute, absolutePosition: position)

proc cursorPositionStrategy*(): PositioningStrategy =
  PositioningStrategy(kind: pstCursorPosition)

proc relativeStrategy*(rect: Rectangle, offset: Point = Point()): PositioningStrategy =
  PositioningStrategy(
    kind: pstRelative,
    relativeRect: rect,
    relativeOffset: offset)

proc relativeStrategy*(resolver: proc(): Rectangle {.closure.}, offset: Point = Point()): PositioningStrategy =
  PositioningStrategy(
    kind: pstRelative,
    relativeOffset: offset,
    rectResolver: resolver)

func getAbsolutePosition*(s: PositioningStrategy): Point =
  s.absolutePosition

proc getRelativeRectangle*(s: PositioningStrategy): Rectangle =
  if s.rectResolver != nil:
    s.rectResolver()
  else:
    s.relativeRect

func getRelativeOffset*(s: PositioningStrategy): Point =
  s.relativeOffset

proc resolvePoint*(s: PositioningStrategy): Point =
  case s.kind
  of pstAbsolute:
    s.absolutePosition
  of pstCursorPosition:
    if cursorPositionProvider != nil:
      cursorPositionProvider()
    else:
      raise newException(Defect, "no cursor position provider registered")
  of pstRelative:
    let r = s.getRelativeRectangle()
    Point(x: r.x + s.relativeOffset.x, y: r.y + s.relativeOffset.y)
