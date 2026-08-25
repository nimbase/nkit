import nkit/foundation/event_emitter
import nkit/gui/view

when defined(macosx) or defined(ios):
  import nkit/platform/macos/nsfunctions

export view

type
  SeparatorOrientation* = enum
    soHorizontal
    soVertical

  Separator* = ref object of View

proc newSeparator*(orientation: SeparatorOrientation = soHorizontal): Separator =
  when defined(macosx) or defined(ios):
    let nativePtr = naSeparatorCreate(cint(ord(orientation)))
  else:
    let nativePtr: pointer = nil
  result = Separator()
  discard wrapView(result, nativePtr)

proc destroy*(s: Separator) =
  when defined(macosx) or defined(ios):
    naSeparatorFree(s.native)
    s.native = nil
  shutdownEmitter[GuiEvent](s)

proc setThickness*(s: Separator, thickness: float64) =
  when defined(macosx) or defined(ios):
    naSeparatorSetThickness(s.native, thickness)
