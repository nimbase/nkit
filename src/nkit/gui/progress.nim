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
  ProgressStyle* = enum
    psBar
    psSpinner

  Progress* = ref object of View

proc newProgress*(style: ProgressStyle = psBar, value = 0.0): Progress =
  when defined(macosx) or defined(ios) or defined(linux):
    let nativePtr = naProgressCreate(cint(ord(style)))
  else:
    let nativePtr: pointer = nil
  result = Progress()
  discard wrapView(result, nativePtr)
  when defined(macosx) or defined(ios) or defined(linux):
    if style == psBar and value != 0.0:
      naProgressSetValue(result.native, value)

proc destroy*(p: Progress) =
  when defined(macosx) or defined(ios) or defined(linux):
    naProgressFree(p.native)
    p.native = nil
  shutdownEmitter[GuiEvent](p)

proc setValue*(p: Progress, value: float64) =
  when defined(macosx) or defined(ios) or defined(linux):
    naProgressSetValue(p.native, value)

proc getValue*(p: Progress): float64 =
  when defined(macosx) or defined(ios) or defined(linux):
    naProgressGetValue(p.native)
  else:
    0.0

proc setIndeterminate*(p: Progress, indeterminate: bool) =
  when defined(macosx) or defined(ios) or defined(linux):
    naProgressSetIndeterminate(p.native, indeterminate)

proc isIndeterminate*(p: Progress): bool =
  when defined(macosx) or defined(ios) or defined(linux):
    naProgressIsIndeterminate(p.native)
  else:
    false
