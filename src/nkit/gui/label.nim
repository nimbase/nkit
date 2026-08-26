import std/tables
import nkit/foundation/id_allocator
import nkit/foundation/event_emitter
import nkit/gui/view
import nkit/foundation/color

when defined(ios):
  import nkit/platform/ios/uifunctions
elif defined(macosx):
  import nkit/platform/macos/nsfunctions

export view

type
  LabelAlignment* = enum
    laLeft
    laCenter
    laRight

  FontWeight* = enum
    fwThin
    fwLight
    fwRegular
    fwMedium
    fwSemibold
    fwBold
    fwHeavy

  Label* = ref object of View

proc newLabel*(text = ""): Label =
  when defined(nkitTrace):
    proc llog(msg: string) =
      let f = open("/tmp/nkit_nim.log", fmAppend)
      f.writeLine("label: " & msg)
      f.close()
    llog("naLabelCreate start")
  when defined(macosx) or defined(ios):
    let nativePtr = naLabelCreate()
  else:
    let nativePtr: pointer = nil
  when defined(nkitTrace): llog("naLabelCreate done, wrapView")
  result = Label()
  discard wrapView(result, nativePtr)
  when defined(nkitTrace): llog("wrapView done")
  when defined(macosx) or defined(ios):
    if text.len > 0:
      when defined(nkitTrace): llog("naLabelSetText start")
      naLabelSetText(result.native, text.cstring)
      when defined(nkitTrace): llog("naLabelSetText done")

proc destroy*(l: Label) =
  when defined(macosx) or defined(ios):
    naLabelFree(l.native)
    l.native = nil
  shutdownEmitter[GuiEvent](l)

proc setText*(l: Label, text: string) =
  when defined(macosx) or defined(ios):
    naLabelSetText(l.native, text.cstring)

proc getText*(l: Label): string =
  when defined(macosx) or defined(ios):
    $naLabelGetText(l.native)
  else:
    ""

proc setTextColor*(l: Label, c: Color) =
  when defined(macosx) or defined(ios):
    naLabelSetTextColor(l.native, c.r, c.g, c.b, c.a)

proc setFontSize*(l: Label, size: float64) =
  when defined(macosx) or defined(ios):
    naLabelSetFontSize(l.native, size)

proc setFontWeight*(l: Label, weight: FontWeight) =
  when defined(macosx) or defined(ios):
    naLabelSetFontWeight(l.native, cint(ord(weight)))

proc setAlignment*(l: Label, alignment: LabelAlignment) =
  when defined(macosx) or defined(ios):
    naLabelSetAlignment(l.native, cint(ord(alignment)))

proc setWraps*(l: Label, wraps: bool, maxLines = 0) =
  when defined(macosx) or defined(ios):
    naLabelSetWraps(l.native, wraps, cint(maxLines))
