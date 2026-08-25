import nkit/foundation/event_emitter
import nkit/gui/view

when defined(macosx) or defined(ios):
  import nkit/platform/macos/nsfunctions

export view

type
  ProgressStyle* = enum
    psBar
    psSpinner

  Progress* = ref object of View

proc newProgress*(style: ProgressStyle = psBar, value = 0.0): Progress =
  when defined(macosx) or defined(ios):
    let nativePtr = naProgressCreate(cint(ord(style)))
  else:
    let nativePtr: pointer = nil
  result = Progress()
  discard wrapView(result, nativePtr)
  when defined(macosx) or defined(ios):
    if style == psBar and value != 0.0:
      naProgressSetValue(result.native, value)

proc destroy*(p: Progress) =
  when defined(macosx) or defined(ios):
    naProgressFree(p.native)
    p.native = nil
  shutdownEmitter[GuiEvent](p)

proc setValue*(p: Progress, value: float64) =
  when defined(macosx) or defined(ios):
    naProgressSetValue(p.native, value)

proc getValue*(p: Progress): float64 =
  when defined(macosx) or defined(ios):
    naProgressGetValue(p.native)
  else:
    0.0

proc setIndeterminate*(p: Progress, indeterminate: bool) =
  when defined(macosx) or defined(ios):
    naProgressSetIndeterminate(p.native, indeterminate)

proc isIndeterminate*(p: Progress): bool =
  when defined(macosx) or defined(ios):
    naProgressIsIndeterminate(p.native)
  else:
    false
