import std/math
import nkit/gui/layout_core
import nkit/gui/view
import nkit/foundation/event
import nkit/foundation/event_emitter
import nkit/foundation/id_allocator
import nkit/window
import nkit/window_manager

export layout_core, view

type
  ViewNode* = ref object of LayoutNode
    view*: View

proc viewOf*(n: LayoutNode): View =
  if n of ViewNode:
    ViewNode(n).view
  else:
    nil

converter toNode*(v: View): ViewNode {.inline.} =
  result = ViewNode(view: v)
  discard initNode(result, likLeaf)

method measureSelf*(n: ViewNode, maxWidth: float64, maxHeight: float64): Size =
  measure(n.view, maxWidth, maxHeight)

method placeSelf*(n: ViewNode, rect: Rectangle, parentSize: Size) =
  ## Snaps the frame to whole points: solver math (centering, y-flip against
  ## fractional intrinsic heights) produces half-point origins that render
  ## text off the pixel grid and blur it.
  when defined(ios):
    # iOS UIKit uses top-left origin; no y-flip needed.
    setFrameRect(n.view,
      rectangle(round(rect.x),
                round(rect.y),
                max(round(rect.width), 1.0),
                max(round(rect.height), 1.0)))
  else:
    setFrameRect(n.view,
      rectangle(round(rect.x),
                round(parentSize.height - rect.y - rect.height),
                max(round(rect.width), 1.0),
                max(round(rect.height), 1.0)))

proc box(kind: LayoutKind): ViewNode =
  result = ViewNode(view: newPlainView())
  discard initNode(result, kind)

proc row*(children: varargs[ViewNode]): ViewNode =
  result = box(likRow)
  for c in children:
    result.children.add(c)

proc column*(children: varargs[ViewNode]): ViewNode =
  result = box(likColumn)
  for c in children:
    result.children.add(c)

proc expanded*(child: ViewNode, flex = 1.0): ViewNode =
  result = box(likExpanded)
  result.flex = flex
  result.children.add(child)

proc spacer*(): ViewNode =
  result = box(likExpanded)
  result.flex = 1.0

proc sizedBox*(width = 0.0, height = 0.0, child: ViewNode = nil): ViewNode =
  result = box(likSizedBox)
  result.fixedWidth = width
  result.fixedHeight = height
  if not child.isNil:
    result.children.add(child)

proc aligned*(child: ViewNode, alignment: Alignment): ViewNode =
  result = box(likAlign)
  let (x, y) = alignmentVector(alignment)
  result.alignmentX = x
  result.alignmentY = y
  result.children.add(child)

proc aligned*(child: ViewNode, x: float64, y: float64): ViewNode =
  ## Fractional alignment, equivalent to Flutter Alignment(x, y).
  result = box(likAlign)
  result.alignmentX = x
  result.alignmentY = y
  result.children.add(child)

proc centered*(child: ViewNode): ViewNode =
  aligned(child, alCenter)

proc padding*(child: ViewNode, all: float64): ViewNode =
  result = box(likPadding)
  result.insets = insetsAll(all)
  result.children.add(child)

proc padding*(child: ViewNode, h: float64, v: float64): ViewNode =
  result = box(likPadding)
  result.insets = insetsHV(h, v)
  result.children.add(child)

proc padding*(child: ViewNode, left: float64, top: float64, right: float64,
              bottom: float64): ViewNode =
  result = box(likPadding)
  result.insets = insetsLTRB(left, top, right, bottom)
  result.children.add(child)

proc padding*(child: ViewNode, edgeInsets: Insets): ViewNode =
  ## EdgeInsets-style: padding(child, all(16)) or padding(child, only(left = 8)).
  result = box(likPadding)
  result.insets = edgeInsets
  result.children.add(child)

proc margin*(child: ViewNode, edgeInsets: Insets): ViewNode =
  ## EdgeInsets-style: margin(child, symmetric(h = 12, v = 6)).
  result = box(likMargin)
  result.insets = edgeInsets
  result.children.add(child)

proc margin*(child: ViewNode, all: float64): ViewNode =
  result = box(likMargin)
  result.insets = insetsAll(all)
  result.children.add(child)

proc margin*(child: ViewNode, h: float64, v: float64): ViewNode =
  result = box(likMargin)
  result.insets = insetsHV(h, v)
  result.children.add(child)

proc margin*(child: ViewNode, left: float64, top: float64, right: float64,
             bottom: float64): ViewNode =
  result = box(likMargin)
  result.insets = insetsLTRB(left, top, right, bottom)
  result.children.add(child)

proc attachViews*(n: LayoutNode) =
  let pv = viewOf(n)
  for c in n.children:
    let cv = viewOf(c)
    if not pv.isNil and not cv.isNil:
      addSubview(pv, cv)
    attachViews(c)

proc applyLayout*(root: LayoutNode, available: Size) =
  attachViews(root)
  ## The root owns the granted rect: without this its view keeps whatever
  ## native init frame it had, and hit-testing dies at that stale box even
  ## though descendants render outside it.
  if root of ViewNode:
    let vn = ViewNode(root)
    vn.placeSelf(rectangle(0.0, 0.0, available.width, available.height),
                 available)
  computeLayout(root, available)

proc layoutIn*(root: ViewNode, parent: View) =
  ## Attaches the root node's view inside parent and lays out using the
  ## parent's current frame.
  addSubview(parent, root.view)
  let f = getFrameRect(parent)
  applyLayout(root, size(f.width, f.height))

proc installLayout*(win: Window, root: ViewNode) =
  ## Makes the node tree the window's content and keeps it laid out on resize.
  when defined(nkitTrace):
    proc llog(msg: string) =
      let f = open("/tmp/nkit_nim.log", fmAppend)
      f.writeLine("installLayout: " & msg)
      f.close()
    llog("setContent start")
  setContent(win, root.view)
  when defined(nkitTrace): llog("setContent done")
  proc apply() =
    let cs = win.getContentSize()
    applyLayout(root, cs)
  apply()
  let wm = sharedWindowManager()
  discard wm.addListener(proc(e: WindowResizedEvent) =
    if e.windowId == win.id:
      apply())

template layout*(body: untyped) =
  ## Mounts the produced tree on the most recently created window:
  ##
  ##   layout do:
  ##     padding(column(row(text("hi"), button("go"))).spacing(8), all(16))
  installLayout(mostRecentWindow(), body)

template layout*(win: Window, body: untyped) =
  ## Explicit-window variant for multi-window apps: `layout win do: ...`
  installLayout(win, body)
