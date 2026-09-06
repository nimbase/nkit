import std/tables
import ../foundation/id_allocator
import ../foundation/event_emitter
import ./view
import ../foundation/color

when defined(ios):
  import ../platform/ios/uifunctions
elif defined(macosx):
  import ../platform/macos/nsfunctions
elif defined(linux):
  import ../platform/linux/gfunctions

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
  when defined(macosx) or defined(ios) or defined(linux):
    let nativePtr = naLabelCreate()
  else:
    let nativePtr: pointer = nil
  when defined(nkitTrace): llog("naLabelCreate done, wrapView")
  result = Label()
  discard wrapView(result, nativePtr)
  when defined(nkitTrace): llog("wrapView done")
  when defined(macosx) or defined(ios) or defined(linux):
    if text.len > 0:
      when defined(nkitTrace): llog("naLabelSetText start")
      naLabelSetText(result.native, text.cstring)
      when defined(nkitTrace): llog("naLabelSetText done")

proc destroy*(l: Label) =
  when defined(macosx) or defined(ios) or defined(linux):
    naLabelFree(l.native)
    l.native = nil
  shutdownEmitter[GuiEvent](l)

proc setText*(l: Label, text: string) =
  when defined(macosx) or defined(ios) or defined(linux):
    naLabelSetText(l.native, text.cstring)

proc getText*(l: Label): string =
  when defined(macosx) or defined(ios) or defined(linux):
    $naLabelGetText(l.native)
  else:
    ""

proc setTextColor*(l: Label, c: Color) =
  when defined(macosx) or defined(ios) or defined(linux):
    naLabelSetTextColor(l.native, c.r, c.g, c.b, c.a)

proc setFontSize*(l: Label, size: float64) =
  when defined(macosx) or defined(ios) or defined(linux):
    naLabelSetFontSize(l.native, size)

proc setFontWeight*(l: Label, weight: FontWeight) =
  when defined(macosx) or defined(ios) or defined(linux):
    naLabelSetFontWeight(l.native, cint(ord(weight)))

proc setAlignment*(l: Label, alignment: LabelAlignment) =
  when defined(macosx) or defined(ios) or defined(linux):
    naLabelSetAlignment(l.native, cint(ord(alignment)))

proc setWraps*(l: Label, wraps: bool, maxLines = 0) =
  when defined(macosx) or defined(ios) or defined(linux):
    naLabelSetWraps(l.native, wraps, cint(maxLines))
