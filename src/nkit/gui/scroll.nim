import ../foundation/color
import ../foundation/event_emitter
import ./view

when defined(ios):
  import ../platform/ios/uifunctions
elif defined(macosx):
  import ../platform/macos/nsfunctions
elif defined(linux):
  import ../platform/linux/gfunctions

export view

type Scroll* = ref object of View

proc newScroll*(): Scroll =
  when defined(macosx) or defined(ios) or defined(linux):
    let nativePtr = naScrollCreate()
  else:
    let nativePtr: pointer = nil
  result = Scroll()
  discard wrapView(result, nativePtr)

proc destroy*(sc: Scroll) =
  when defined(macosx) or defined(ios) or defined(linux):
    naScrollFree(sc.native)
    sc.native = nil
  shutdownEmitter[GuiEvent](sc)

proc setDocument*(sc: Scroll, doc: View) =
  when defined(macosx) or defined(ios) or defined(linux):
    naScrollSetDocument(sc.native, doc.native)

proc fitWidth*(sc: Scroll, leftInset = 0.0, rightInset = 0.0) =
  ## Pins the document view's width to the scroll viewport (vertical scrolling only).
  when defined(macosx) or defined(ios) or defined(linux):
    naScrollFitWidth(sc.native, leftInset, rightInset)

proc setHasVerticalBar*(sc: Scroll, has: bool) =
  when defined(macosx) or defined(ios) or defined(linux):
    naScrollSetHasVerticalBar(sc.native, has)

proc setHasHorizontalBar*(sc: Scroll, has: bool) =
  when defined(macosx) or defined(ios) or defined(linux):
    naScrollSetHasHorizontalBar(sc.native, has)

proc setBorder*(sc: Scroll, bordered: bool) =
  when defined(macosx) or defined(ios) or defined(linux):
    naScrollSetBorder(sc.native, bordered)

proc setBackground*(sc: Scroll, c: Color) =
  when defined(macosx) or defined(ios) or defined(linux):
    naScrollSetBackground(sc.native, c.r, c.g, c.b, c.a)
