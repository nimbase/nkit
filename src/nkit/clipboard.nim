import ./foundation/geometry
when defined(ios):
  import ./platform/ios/uifunctions
elif defined(macosx):
  import ./platform/macos/nsfunctions
elif defined(linux):
  import ./platform/linux/gfunctions
import ./image

type Clipboard* = ref object

proc sharedClipboard*(): Clipboard =
  Clipboard()

proc setClipboardText*(c: Clipboard, text: string) =
  when defined(macosx) or defined(linux):
    naClipboardSetText(text.cstring)

proc getClipboardText*(c: Clipboard): string =
  when defined(macosx) or defined(linux):
    let value = naClipboardGetText()
    if not value.isNil:
      result = $value
      naClipboardFreeString(value)

proc clearClipboard*(c: Clipboard) =
  when defined(macosx) or defined(linux):
    naClipboardClear()

func clipboardChangeCount*(c: Clipboard): int =
  when defined(macosx) or defined(linux):
    int(naClipboardChangeCount())
  else:
    0

proc setClipboardImage*(c: Clipboard, img: Image) =
  when defined(macosx) or defined(linux):
    if img != nil and img.exists():
      naClipboardSetImageHandle(img.handle)
    else:
      naClipboardClear()

proc getClipboardImage*(c: Clipboard): Image =
  when defined(macosx) or defined(linux):
    var w, h: float64
    let handle = naClipboardGetImageHandle()
    if handle == 0:
      return nil
    naImageGetSize(handle, addr w, addr h)
    Image(handle: handle, source: "clipboard", formatValue: "png",
         sizeValue: size(w, h))
  else:
    nil

proc setClipboardFiles*(c: Clipboard, paths: seq[string]) =
  when defined(macosx) or defined(linux):
    if paths.len == 0:
      naClipboardClear()
      return
    var cstrs: seq[cstring] = @[]
    for p in paths:
      cstrs.add(p.cstring)
    naClipboardSetFilePaths(addr cstrs[0], cint(paths.len))

proc getClipboardFiles*(c: Clipboard): seq[string] =
  when defined(macosx) or defined(linux):
    var count: cint = 0
    let list = naClipboardGetFilePaths(addr count)
    if not list.isNil and count > 0:
      for i in 0 ..< int(count):
        let item = cast[ptr UncheckedArray[cstring]](list)[i]
        result.add($item)
      naClipboardFreeStringList(list, count)
