import nkit/foundation/geometry

when defined(ios):
  import nkit/platform/ios/uifunctions
elif defined(macosx):
  import nkit/platform/macos/nsfunctions

type Image* = ref object
  handle*: int64
  source*: string
  formatValue*: string
  sizeValue*: Size

proc newImageEmpty(): Image =
  result = Image(handle: 0, source: "", formatValue: "Unknown")

proc fromImageFile*(path: string): Image =
  when defined(macosx) and not defined(ios):
    let handle = naImageFromFile(path.cstring)
    if handle == 0:
      return nil
    var w, h: float64
    naImageGetSize(handle, addr w, addr h)
    return Image(
      handle: handle,
      source: path,
      formatValue: $naImageGetFormat(handle),
      sizeValue: Size(width: w, height: h))
  else:
    discard path
    return nil

proc fromBase64*(data: string): Image =
  when defined(macosx) and not defined(ios):
    let handle = naImageFromBase64(data.cstring)
    if handle == 0:
      return nil
    var w, h: float64
    naImageGetSize(handle, addr w, addr h)
    var sourceBuf: array[256, char]
    naImageGetSource(handle, cast[cstring](addr sourceBuf[0]), cint(sourceBuf.len))
    return Image(
      handle: handle,
      source: $cast[cstring](addr sourceBuf[0]),
      formatValue: $naImageGetFormat(handle),
      sizeValue: Size(width: w, height: h))
  else:
    discard data
    return nil

proc exists*(img: Image): bool =
  when defined(macosx) and not defined(ios):
    naImageExists(img.handle)
  else:
    false

proc getSize*(img: Image): Size =
  img.sizeValue

proc getFormat*(img: Image): string =
  img.formatValue

proc getSource*(img: Image): string =
  img.source

proc toBase64*(img: Image): string =
  when defined(macosx) and not defined(ios):
    $naImageToBase64(img.handle)
  else:
    ""

proc saveToFile*(img: Image, path: string): bool =
  when defined(macosx) and not defined(ios):
    naImageSaveToFile(img.handle, path.cstring)
  else:
    false

proc free*(img: Image) =
  when defined(macosx) and not defined(ios):
    naImageDestroy(img.handle)

proc nativePtr*(img: Image): pointer =
  when defined(macosx) and not defined(ios):
    naImageNativePtr(img.handle)
  else:
    nil
