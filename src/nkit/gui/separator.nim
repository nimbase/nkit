import ../foundation/event_emitter
import ./view

when defined(ios):
  import ../platform/ios/uifunctions
elif defined(macosx):
  import ../platform/macos/nsfunctions
elif defined(linux):
  import ../platform/linux/gfunctions

export view

type
  SeparatorOrientation* = enum
    soHorizontal
    soVertical

  Separator* = ref object of View

proc newSeparator*(orientation: SeparatorOrientation = soHorizontal): Separator =
  when defined(macosx) or defined(ios) or defined(linux):
    let nativePtr = naSeparatorCreate(cint(ord(orientation)))
  else:
    let nativePtr: pointer = nil
  result = Separator()
  discard wrapView(result, nativePtr)

proc destroy*(s: Separator) =
  when defined(macosx) or defined(ios) or defined(linux):
    naSeparatorFree(s.native)
    s.native = nil
  shutdownEmitter[GuiEvent](s)

proc setThickness*(s: Separator, thickness: float64) =
  when defined(macosx) or defined(ios) or defined(linux):
    naSeparatorSetThickness(s.native, thickness)
