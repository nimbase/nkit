type Color* = object
  r*: uint8
  g*: uint8
  b*: uint8
  a*: uint8

func color*(r, g, b: uint8, a: uint8 = 255): Color {.inline.} =
  Color(r: r, g: g, b: b, a: a)

func toRgba*(c: Color): uint32 {.inline.} =
  (uint32(c.r) shl 24) or (uint32(c.g) shl 16) or (uint32(c.b) shl 8) or uint32(c.a)

func toArgb*(c: Color): uint32 {.inline.} =
  (uint32(c.a) shl 24) or (uint32(c.r) shl 16) or (uint32(c.g) shl 8) or uint32(c.b)

proc parseHexDigit(c: char): uint8 =
  case c
  of '0'..'9': uint8(ord(c) - ord('0'))
  of 'a'..'f': uint8(ord(c) - ord('a') + 10)
  of 'A'..'F': uint8(ord(c) - ord('A') + 10)
  else: raise newException(ValueError, "invalid hex digit: " & c)

func expandHexDigit(v: uint8): uint8 {.inline.} =
  (v shl 4) or v

func parseHexByteAt(s: string, i: int): uint8 {.inline.} =
  (parseHexDigit(s[i]) shl 4) or parseHexDigit(s[i + 1])

proc colorFromHex*(hex: string): Color =
  var s = hex
  if s.len > 0 and s[0] == '#':
    s = s[1 .. ^1]
  case s.len
  of 3:
    Color(
      r: expandHexDigit(parseHexDigit(s[0])),
      g: expandHexDigit(parseHexDigit(s[1])),
      b: expandHexDigit(parseHexDigit(s[2])),
      a: 255)
  of 4:
    Color(
      r: expandHexDigit(parseHexDigit(s[0])),
      g: expandHexDigit(parseHexDigit(s[1])),
      b: expandHexDigit(parseHexDigit(s[2])),
      a: expandHexDigit(parseHexDigit(s[3])))
  of 6:
    Color(r: parseHexByteAt(s, 0), g: parseHexByteAt(s, 2), b: parseHexByteAt(s, 4), a: 255)
  of 8:
    Color(r: parseHexByteAt(s, 0), g: parseHexByteAt(s, 2), b: parseHexByteAt(s, 4), a: parseHexByteAt(s, 6))
  else:
    raise newException(ValueError, "invalid hex color format, expected #RGB, #RGBA, #RRGGBB or #RRGGBBAA")

const
  colorTransparent* = Color(r: 0, g: 0, b: 0, a: 0)
  colorBlack* = Color(r: 0, g: 0, b: 0, a: 255)
  colorWhite* = Color(r: 255, g: 255, b: 255, a: 255)
  colorRed* = Color(r: 255, g: 0, b: 0, a: 255)
  colorGreen* = Color(r: 0, g: 255, b: 0, a: 255)
  colorBlue* = Color(r: 0, g: 0, b: 255, a: 255)
  colorYellow* = Color(r: 255, g: 255, b: 0, a: 255)
  colorCyan* = Color(r: 0, g: 255, b: 255, a: 255)
  colorMagenta* = Color(r: 255, g: 0, b: 255, a: 255)
