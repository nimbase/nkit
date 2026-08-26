import std/[tables]
import nkit/foundation/event_emitter
import nkit/foundation/event
import nkit/foundation/id_allocator
import nkit/window
import nkit/window_manager
import nkit/gui/layout
import nkit/gui/view
when defined(ios):
  import nkit/platform/ios/uifunctions
elif defined(macosx):
  import nkit/platform/macos/nsfunctions

when defined(ios):
  import nkit/platform/ios/dispatcher_ios
elif defined(macosx):
  import nkit/platform/macos/dispatcher_macos

export view, layout, window, window_manager

type SplitView* = ref object of View

proc newVerticalSplitView*(): SplitView =
  ## A split view whose dividers are vertical; panes sit side by side and
  ## resize along their width.
  when defined(macosx) or defined(ios):
    let splitPtr = naSplitViewCreate(true)
  else:
    let splitPtr: pointer = nil
  result = SplitView()
  discard wrapView(result, splitPtr)
  setWantsLayer(result, true)

proc newHorizontalSplitView*(): SplitView =
  ## A split view whose dividers are horizontal; panes stack and resize
  ## along their height.
  when defined(macosx) or defined(ios):
    let splitPtr = naSplitViewCreate(false)
  else:
    let splitPtr: pointer = nil
  result = SplitView()
  discard wrapView(result, splitPtr)
  setWantsLayer(result, true)

proc addPane*(sv: SplitView, pane: View) =
  ## Appends a resizable pane. Panes split available space equally by
  ## default; tune with setHoldingPriority.
  when defined(macosx) or defined(ios):
    naSplitViewAddPane(sv.native, pane.native)

func paneCount*(sv: SplitView): int =
  when defined(macosx) or defined(ios):
    int(naSplitViewPaneCount(sv.native))
  else:
    0

proc setDividerThickness*(sv: SplitView, thickness: float64) =
  when defined(macosx) or defined(ios):
    naSplitViewSetDividerThickness(sv.native, thickness)

proc setPosition*(sv: SplitView, dividerIndex: int, position: float64): bool =
  ## Moves the divider after `dividerIndex`. Returns false for out-of-range.
  when defined(macosx) or defined(ios):
    naSplitViewSetPosition(sv.native, cint(dividerIndex), position)
  else:
    false

proc getPosition*(sv: SplitView, dividerIndex: int): float64 =
  when defined(macosx) or defined(ios):
    naSplitViewGetPosition(sv.native, cint(dividerIndex))
  else:
    0.0

proc setHoldingPriority*(sv: SplitView, paneIndex: int,
                         priority: float64) =
  ## Higher-priority panes keep their size while lower ones resize.
  when defined(macosx) or defined(ios):
    naSplitViewSetHoldingPriority(sv.native, cint(paneIndex), priority)

proc setPaneConstraints*(sv: SplitView, paneIndex: int,
                         minWidth = 0.0, maxWidth = 0.0,
                         minHeight = 0.0, maxHeight = 0.0) =
  ## Bounds a pane along the divider axis: width for vertical splits,
  ## height for horizontal ones. A bound of 0 means unconstrained.
  ## Repeated calls replace the pane's previous bounds.
  when defined(macosx) or defined(ios):
    naSplitViewConstrainPane(sv.native, cint(paneIndex),
                             minWidth, maxWidth, minHeight, maxHeight)

proc destroy*(sv: SplitView) =
  freeNative(sv)
  shutdownEmitter[GuiEvent](sv)

# --- pane frame watching -------------------------------------------------
# NSSplitView positions panes itself (initial layout, divider drags); the
# solver tree inside each pane must re-apply whenever the pane's frame
# changes, not just when the window resizes.

type PaneRelayout = object
  root: ViewNode
  lastW: float64
  lastH: float64

var paneLayouts = initTable[uint32, PaneRelayout]()

when defined(macosx) or defined(ios):
  proc paneFrameTrampoline(w: cdouble, h: cdouble, ctx: pointer) {.cdecl.} =
    let key = uint32(cast[int](ctx))
    if paneLayouts.hasKey(key):
      var entry = paneLayouts[key]
      if w != entry.lastW or h != entry.lastH:
        entry.lastW = w
        entry.lastH = h
        paneLayouts[key] = entry
        applyLayout(entry.root, size(w, h))

proc watchPaneFrame*(pane: View, root: ViewNode) =
  ## Re-applies the solver tree rooted at `root` whenever the pane view is
  ## resized natively (window layout, divider drag).
  when defined(macosx) or defined(ios):
    let key = pane.nativeKey
    paneLayouts[key] = PaneRelayout(root: root, lastW: -1.0, lastH: -1.0)
    naViewSetFrameCallback(pane.native, paneFrameTrampoline,
                           cast[pointer](int(key)))

proc newPaneLayout*(pane: View, root: ViewNode): View =
  ## Mounts a solver tree inside a plain view and applies an initial layout.
  ## Returns the pane view ready for `split.addPane(...)`.
  addSubview(pane, root.view)
  applyLayout(root, size(getFrameRect(pane).width, getFrameRect(pane).height))
  pane

proc installPaneLayout*(win: Window, pane: View, root: ViewNode) =
  ## Like newPaneLayout but keeps the pane's tree laid out automatically as
  ## the pane's frame changes (window resize, divider drag).
  discard newPaneLayout(pane, root)
  watchPaneFrame(pane, root)
  proc apply() =
    let f = pane.getFrameRect()
    applyLayout(root, size(f.width, f.height))
  let wm = sharedWindowManager()
  discard wm.addListener(proc(e: WindowResizedEvent) =
    if e.windowId == win.id:
      dispatchAfterMain(1) do ():
        apply())

type
  SplitPaneSpec* = object
    ## Per-pane descriptor produced by `splitPane`, consumed by the
    ## vertical/horizontalSplitView overloads.
    root*: ViewNode
    minWidth*: float64
    maxWidth*: float64
    minHeight*: float64
    maxHeight*: float64

proc splitPane*(root: ViewNode, minWidth = 0.0, maxWidth = 0.0,
                minHeight = 0.0, maxHeight = 0.0): SplitPaneSpec =
  ## Describes one split pane with optional size bounds (0 = unconstrained).
  SplitPaneSpec(root: root, minWidth: minWidth, maxWidth: maxWidth,
                minHeight: minHeight, maxHeight: maxHeight)

proc buildSplitView(vertical: bool, panes: seq[SplitPaneSpec]): ViewNode =
  let win = mostRecentWindow()
  let sv =
    if vertical:
      newVerticalSplitView()
    else:
      newHorizontalSplitView()
  for spec in panes:
    let pane = newPlainView()
    installPaneLayout(win, pane, spec.root)
    sv.addPane(pane)
    if spec.minWidth > 0 or spec.maxWidth > 0 or
        spec.minHeight > 0 or spec.maxHeight > 0:
      sv.setPaneConstraints(sv.paneCount() - 1,
                            spec.minWidth, spec.maxWidth,
                            spec.minHeight, spec.maxHeight)
  ViewNode(sv)

proc verticalSplitView*(roots: varargs[ViewNode]): ViewNode =
  ## One-call vertical split view with unconstrained panes.
  var specs: seq[SplitPaneSpec]
  for r in roots:
    specs.add(SplitPaneSpec(root: r))
  buildSplitView(true, specs)

proc verticalSplitView*(panes: varargs[SplitPaneSpec]): ViewNode =
  ## One-call vertical split view with per-pane constraints.
  buildSplitView(true, @panes)

proc horizontalSplitView*(roots: varargs[ViewNode]): ViewNode =
  ## One-call horizontal split view with unconstrained panes.
  var specs: seq[SplitPaneSpec]
  for r in roots:
    specs.add(SplitPaneSpec(root: r))
  buildSplitView(false, specs)

proc horizontalSplitView*(panes: varargs[SplitPaneSpec]): ViewNode =
  ## One-call horizontal split view with per-pane constraints.
  buildSplitView(false, @panes)
