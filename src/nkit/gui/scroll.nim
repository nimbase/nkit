import nkit/foundation/color
import nkit/foundation/event_emitter
import nkit/gui/view

when defined(ios):
  import nkit/platform/ios/uifunctions
elif defined(macosx):
  import nkit/platform/macos/nsfunctions

export view

type Scroll* = ref object of View

proc newScroll*(): Scroll =
  when defined(macosx) or defined(ios):
    let nativePtr = naScrollCreate()
  else:
    let nativePtr: pointer = nil
  result = Scroll()
  discard wrapView(result, nativePtr)

proc destroy*(sc: Scroll) =
  when defined(macosx) or defined(ios):
    naScrollFree(sc.native)
    sc.native = nil
  shutdownEmitter[GuiEvent](sc)

proc setDocument*(sc: Scroll, doc: View) =
  when defined(macosx) or defined(ios):
    naScrollSetDocument(sc.native, doc.native)

proc fitWidth*(sc: Scroll, leftInset = 0.0, rightInset = 0.0) =
  ## Pins the document view's width to the scroll viewport (vertical scrolling only).
  when defined(macosx) or defined(ios):
    naScrollFitWidth(sc.native, leftInset, rightInset)

proc setHasVerticalBar*(sc: Scroll, has: bool) =
  when defined(macosx) or defined(ios):
    naScrollSetHasVerticalBar(sc.native, has)

proc setHasHorizontalBar*(sc: Scroll, has: bool) =
  when defined(macosx) or defined(ios):
    naScrollSetHasHorizontalBar(sc.native, has)

proc setBorder*(sc: Scroll, bordered: bool) =
  when defined(macosx) or defined(ios):
    naScrollSetBorder(sc.native, bordered)

proc setBackground*(sc: Scroll, c: Color) =
  when defined(macosx) or defined(ios):
    naScrollSetBackground(sc.native, c.r, c.g, c.b, c.a)
