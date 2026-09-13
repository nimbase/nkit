import ./foundation/geometry

when defined(ios):
  import ./platform/ios/uifunctions
elif defined(macosx):
  import ./platform/macos/nsfunctions
elif defined(linux):
  import ./platform/linux/gfunctions

type Image* = ref object
  handle*: int64
  source*: string
  formatValue*: string
  sizeValue*: Size

proc newImageEmpty(): Image =
  result = Image(handle: 0, source: "", formatValue: "Unknown")

proc fromImageFile*(path: string): Image =
  when defined(macosx) or defined(linux):
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
  when defined(macosx) or defined(linux):
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
  when defined(macosx) or defined(linux):
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
  when defined(macosx) or defined(linux):
    $naImageToBase64(img.handle)
  else:
    ""

proc saveToFile*(img: Image, path: string): bool =
  when defined(macosx) or defined(linux):
    naImageSaveToFile(img.handle, path.cstring)
  else:
    false

proc free*(img: Image) =
  when defined(macosx) or defined(linux):
    naImageDestroy(img.handle)

proc nativePtr*(img: Image): pointer =
  when defined(macosx) or defined(linux):
    naImageNativePtr(img.handle)
  else:
    nil
