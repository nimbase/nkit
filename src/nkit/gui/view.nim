import ../foundation/id_allocator
import ../foundation/object_registry
import ../foundation/event
import ../foundation/event_emitter
import ../foundation/geometry
import ../foundation/color
import ../window

when defined(ios):
  import ../platform/ios/uifunctions
elif defined(macosx):
  import ../platform/macos/nsfunctions
elif defined(linux):
  import ../platform/linux/gfunctions

type
  GuiEvent* = ref object of Event

  View* = ref object of EventEmitter[GuiEvent]
    id*: Id
    nativeKey*: uint32
    native*: pointer

var liveViews = newObjectRegistry[View]()

proc liveViewCount*(): int =
  liveViews.len

proc wrapView*[T: View](v: T, nativePtr: pointer, forceId: Id = idInvalid): T =
  initEmitter(v)
  let vid = if forceId == idInvalid: allocate(typeTagGuiWidget) else: forceId
  v.id = vid
  v.nativeKey = vid.uint32
  v.native = nativePtr
  liveViews.add(vid.uint32, View(v))
  result = v

proc findView*(key: uint32): View =
  liveViews.get(key)

proc newPlainView*(): View =
  ## Creates a generic container view.
  wrapView(View(), naViewCreate())

proc freeNative*(v: View) =
  ## Releases the underlying native view without shutting down emitters.
  when defined(macosx) or defined(ios) or defined(linux):
    if not v.native.isNil:
      naViewDestroy(v.native)
      v.native = nil
  discard liveViews.remove(v.nativeKey)

proc destroy*(v: View) =
  when defined(macosx) or defined(ios) or defined(linux):
    if not v.native.isNil:
      naViewDestroy(v.native)
      v.native = nil
  discard liveViews.remove(v.nativeKey)
  shutdownEmitter[GuiEvent](v)

# Common properties (AppKit coordinates for frames: bottom-left origin)

proc setHidden*(v: View, hidden: bool) =
  when defined(macosx) or defined(ios) or defined(linux):
    naViewSetHidden(v.native, hidden)

proc isHidden*(v: View): bool =
  when defined(macosx) or defined(ios) or defined(linux):
    naViewIsHidden(v.native)
  else:
    false

proc setTooltip*(v: View, tooltip: string) =
  when defined(macosx) or defined(ios) or defined(linux):
    naViewSetTooltip(v.native, tooltip.cstring)

proc getTooltip*(v: View): string =
  when defined(macosx) or defined(ios) or defined(linux):
    $naViewGetTooltip(v.native)
  else:
    ""

proc setTag*(v: View, tag: int) =
  when defined(macosx) or defined(ios) or defined(linux):
    naViewSetTag(v.native, tag.cint)

proc getTag*(v: View): int =
  when defined(macosx) or defined(ios) or defined(linux):
    int(naViewGetTag(v.native))
  else:
    0

proc setFrameRect*(v: View, frame: Rectangle) =
  when defined(macosx) or defined(ios) or defined(linux):
    naViewSetFrame(v.native, frame.x, frame.y, frame.width, frame.height)

proc getFrameRect*(v: View): Rectangle =
  when defined(macosx) or defined(ios) or defined(linux):
    var x, y, w, h: float64
    naViewGetFrame(v.native, addr x, addr y, addr w, addr h)
    rectangle(x, y, w, h)
  else:
    rectangle(0, 0, 0, 0)

# Hierarchy

proc addSubview*(parent: View, child: View) =
  when defined(macosx) or defined(ios) or defined(linux):
    naViewAddSubview(parent.native, child.native)

proc removeFromParent*(v: View) =
  when defined(macosx) or defined(ios) or defined(linux):
    naViewRemoveFromParent(v.native)

proc removeAllChildren*(parent: View) =
  when defined(macosx) or defined(ios) or defined(linux):
    naViewRemoveAll(parent.native)

proc subviewCount*(parent: View): int =
  when defined(macosx) or defined(ios) or defined(linux):
    int(naViewSubviewCount(parent.native))
  else:
    0

# Layout

proc layoutNow*(v: View) =
  when defined(macosx) or defined(ios) or defined(linux):
    naViewLayout(v.native)

proc fillParent*(child: View, left = 0.0, top = 0.0, right = 0.0, bottom = 0.0) =
  when defined(macosx) or defined(ios) or defined(linux):
    naViewConstrainFillSuperview(child.native, left, top, right, bottom)

proc constrainSize*(v: View, width, height: float64) =
  when defined(macosx) or defined(ios) or defined(linux):
    naViewConstrainSize(v.native, width, height)

proc measure*(v: View, maxWidth = 0.0, maxHeight = 0.0): Size =
  ## Intrinsic content size (fittingSize), falling back to the current frame.
  when defined(macosx) or defined(ios) or defined(linux):
    var w, h: float64
    naViewMeasure(v.native, maxWidth, maxHeight, addr w, addr h)
    size(w, h)
  else:
    size(0.0, 0.0)

proc setContentHugging*(v: View, orientation: int, priority: float64) =
  ## 0 = horizontal, 1 = vertical. Low priority (e.g. 10) lets a view stretch
  ## inside stacks; high (e.g. 750) keeps it hugging its content.
  when defined(macosx) or defined(ios) or defined(linux):
    naViewSetContentHugging(v.native, cint(orientation), priority)

# Styling primitives

proc setWantsLayer*(v: View, wants: bool) =
  when defined(macosx) or defined(ios) or defined(linux):
    naViewSetWantsLayer(v.native, wants)

proc setCornerRadius*(v: View, radius: float64) =
  when defined(macosx) or defined(ios) or defined(linux):
    naViewSetCornerRadius(v.native, radius)

proc setBackgroundColor*(v: View, c: Color) =
  when defined(macosx) or defined(ios) or defined(linux):
    naViewSetBackgroundColor(v.native, c.r, c.g, c.b, c.a)

proc clearBackgroundColor*(v: View) =
  when defined(macosx) or defined(ios) or defined(linux):
    naViewClearBackgroundColor(v.native)

proc setBorder*(v: View, c: Color, width: float64) =
  when defined(macosx) or defined(ios) or defined(linux):
    naViewSetBorder(v.native, c.r, c.g, c.b, c.a, width)

# Alpha (animations)

proc setAlpha*(v: View, alpha: float64) =
  when defined(macosx) or defined(ios) or defined(linux):
    naViewSetAlpha(v.native, alpha)

proc getAlpha*(v: View): float64 =
  when defined(macosx) or defined(ios) or defined(linux):
    naViewGetAlpha(v.native)
  else:
    1.0

# Window integration

proc setContent*(w: Window, v: View) =
  when defined(macosx) or defined(ios) or defined(linux):
    naWindowSetRootView(w.nativeKey, v.native)
