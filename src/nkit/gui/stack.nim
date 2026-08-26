import nkit/foundation/event_emitter
import nkit/gui/view

when defined(ios):
  import nkit/platform/ios/uifunctions
elif defined(macosx):
  import nkit/platform/macos/nsfunctions

export view

type
  StackOrientation* = enum
    stHorizontal
    stVertical

  StackAlignment* = enum
    saLeading
    saCenter
    saTrailing

  Stack* = ref object of View

proc newStack*(orientation: StackOrientation = stVertical, spacing = 8.0): Stack =
  when defined(macosx) or defined(ios):
    let nativePtr = naStackCreate(cint(ord(orientation)))
  else:
    let nativePtr: pointer = nil
  result = Stack()
  discard wrapView(result, nativePtr)
  when defined(macosx) or defined(ios):
    naStackSetSpacing(result.native, spacing)

proc destroy*(st: Stack) =
  when defined(macosx) or defined(ios):
    naStackFree(st.native)
    st.native = nil
  shutdownEmitter[GuiEvent](st)

proc setSpacing*(st: Stack, spacing: float64) =
  when defined(macosx) or defined(ios):
    naStackSetSpacing(st.native, spacing)

proc setPadding*(st: Stack, left, top, right, bottom: float64) =
  when defined(macosx) or defined(ios):
    naStackSetPadding(st.native, left, top, right, bottom)

proc setPadding*(st: Stack, all: float64) {.inline.} =
  setPadding(st, all, all, all, all)

proc setArrangedFill*(st: Stack, fill: bool) =
  ## When enabled, arranged children are pinned to both cross-axis edges so
  ## they stretch to the stack's full width (vertical) or height (horizontal).
  when defined(macosx) or defined(ios):
    naStackSetArrangedFill(st.native, fill)

proc setAlignment*(st: Stack, alignment: StackAlignment) =
  when defined(macosx) or defined(ios):
    naStackSetAlignment(st.native, cint(ord(alignment)))

proc addArranged*(st: Stack, child: View) =
  when defined(macosx) or defined(ios):
    naStackAddArranged(st.native, child.native)

proc insertArranged*(st: Stack, child: View, index: int) =
  when defined(macosx) or defined(ios):
    naStackInsertArranged(st.native, child.native, cint(index))

proc removeArranged*(st: Stack, child: View) =
  when defined(macosx) or defined(ios):
    naStackRemoveArranged(st.native, child.native)

proc arrangedCount*(st: Stack): int =
  when defined(macosx) or defined(ios):
    int(naStackArrangedCount(st.native))
  else:
    0
