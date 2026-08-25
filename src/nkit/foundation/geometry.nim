type
  Point* = object
    x*: float64
    y*: float64

  Size* = object
    width*: float64
    height*: float64

  Rectangle* = object
    x*: float64
    y*: float64
    width*: float64
    height*: float64

func point*(x, y: float64): Point {.inline.} =
  Point(x: x, y: y)

func size*(width, height: float64): Size {.inline.} =
  Size(width: width, height: height)

func rectangle*(x, y, width, height: float64): Rectangle {.inline.} =
  Rectangle(x: x, y: y, width: width, height: height)

func size*(r: Rectangle): Size {.inline.} =
  Size(width: r.width, height: r.height)
