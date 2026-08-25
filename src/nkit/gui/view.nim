import nkit/foundation/id_allocator
import nkit/foundation/object_registry
import nkit/foundation/event
import nkit/foundation/event_emitter
import nkit/foundation/geometry
import nkit/foundation/color
import nkit/window

when defined(macosx) or defined(ios):
  import nkit/platform/macos/nsfunctions

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
  when defined(macosx) or defined(ios):
    if not v.native.isNil:
      naViewDestroy(v.native)
      v.native = nil
  discard liveViews.remove(v.nativeKey)

proc destroy*(v: View) =
  when defined(macosx) or defined(ios):
    if not v.native.isNil:
      naViewDestroy(v.native)
      v.native = nil
  discard liveViews.remove(v.nativeKey)
  shutdownEmitter[GuiEvent](v)

# Common properties (AppKit coordinates for frames: bottom-left origin)

proc setHidden*(v: View, hidden: bool) =
  when defined(macosx) or defined(ios):
    naViewSetHidden(v.native, hidden)

proc isHidden*(v: View): bool =
  when defined(macosx) or defined(ios):
    naViewIsHidden(v.native)
  else:
    false

proc setTooltip*(v: View, tooltip: string) =
  when defined(macosx) or defined(ios):
    naViewSetTooltip(v.native, tooltip.cstring)

proc getTooltip*(v: View): string =
  when defined(macosx) or defined(ios):
    $naViewGetTooltip(v.native)
  else:
    ""

proc setTag*(v: View, tag: int) =
  when defined(macosx) or defined(ios):
    naViewSetTag(v.native, tag.cint)

proc getTag*(v: View): int =
  when defined(macosx) or defined(ios):
    int(naViewGetTag(v.native))
  else:
    0

proc setFrameRect*(v: View, frame: Rectangle) =
  when defined(macosx) or defined(ios):
    naViewSetFrame(v.native, frame.x, frame.y, frame.width, frame.height)

proc getFrameRect*(v: View): Rectangle =
  when defined(macosx) or defined(ios):
    var x, y, w, h: float64
    naViewGetFrame(v.native, addr x, addr y, addr w, addr h)
    rectangle(x, y, w, h)
  else:
    rectangle(0, 0, 0, 0)

# Hierarchy

proc addSubview*(parent: View, child: View) =
  when defined(macosx) or defined(ios):
    naViewAddSubview(parent.native, child.native)

proc removeFromParent*(v: View) =
  when defined(macosx) or defined(ios):
    naViewRemoveFromParent(v.native)

proc removeAllChildren*(parent: View) =
  when defined(macosx) or defined(ios):
    naViewRemoveAll(parent.native)

proc subviewCount*(parent: View): int =
  when defined(macosx) or defined(ios):
    int(naViewSubviewCount(parent.native))
  else:
    0

# Layout

proc layoutNow*(v: View) =
  when defined(macosx) or defined(ios):
    naViewLayout(v.native)

proc fillParent*(child: View, left = 0.0, top = 0.0, right = 0.0, bottom = 0.0) =
  when defined(macosx) or defined(ios):
    naViewConstrainFillSuperview(child.native, left, top, right, bottom)

proc constrainSize*(v: View, width, height: float64) =
  when defined(macosx) or defined(ios):
    naViewConstrainSize(v.native, width, height)

proc measure*(v: View, maxWidth = 0.0, maxHeight = 0.0): Size =
  ## Intrinsic content size (fittingSize), falling back to the current frame.
  when defined(macosx) or defined(ios):
    var w, h: float64
    naViewMeasure(v.native, maxWidth, maxHeight, addr w, addr h)
    size(w, h)
  else:
    size(0.0, 0.0)

proc setContentHugging*(v: View, orientation: int, priority: float64) =
  ## 0 = horizontal, 1 = vertical. Low priority (e.g. 10) lets a view stretch
  ## inside stacks; high (e.g. 750) keeps it hugging its content.
  when defined(macosx) or defined(ios):
    naViewSetContentHugging(v.native, cint(orientation), priority)

# Styling primitives

proc setWantsLayer*(v: View, wants: bool) =
  when defined(macosx) or defined(ios):
    naViewSetWantsLayer(v.native, wants)

proc setCornerRadius*(v: View, radius: float64) =
  when defined(macosx) or defined(ios):
    naViewSetCornerRadius(v.native, radius)

proc setBackgroundColor*(v: View, c: Color) =
  when defined(macosx) or defined(ios):
    naViewSetBackgroundColor(v.native, c.r, c.g, c.b, c.a)

proc clearBackgroundColor*(v: View) =
  when defined(macosx) or defined(ios):
    naViewClearBackgroundColor(v.native)

proc setBorder*(v: View, c: Color, width: float64) =
  when defined(macosx) or defined(ios):
    naViewSetBorder(v.native, c.r, c.g, c.b, c.a, width)

# Alpha (animations)

proc setAlpha*(v: View, alpha: float64) =
  when defined(macosx) or defined(ios):
    naViewSetAlpha(v.native, alpha)

proc getAlpha*(v: View): float64 =
  when defined(macosx) or defined(ios):
    naViewGetAlpha(v.native)
  else:
    1.0

# Window integration

proc setContent*(w: Window, v: View) =
  when defined(macosx) or defined(ios):
    naWindowSetRootView(w.nativeKey, v.native)
