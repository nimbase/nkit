import ../foundation/geometry

export geometry

type
  LayoutKind* = enum
    likLeaf
    likRow
    likColumn
    likSizedBox
    likPadding
    likMargin
    likExpanded
    likAlign

  MainAxisAlignment* = enum
    maStart
    maCenter
    maEnd
    maSpaceBetween
    maSpaceAround
    maSpaceEvenly

  CrossAxisAlignment* = enum
    caStart
    caCenter
    caEnd
    caStretch

  Alignment* {.pure.} = enum
    ## Flutter-style nine-point alignment inside the space granted by the parent.
    alTopLeft
    alTopCenter
    alTopRight
    alCenterLeft
    alCenter
    alCenterRight
    alBottomLeft
    alBottomCenter
    alBottomRight

  Insets* = object
    left*: float64
    top*: float64
    right*: float64
    bottom*: float64

  LayoutNode* = ref object of RootObj
    kind*: LayoutKind
    children*: seq[LayoutNode]
    mainAlign*: MainAxisAlignment
    crossAlign*: CrossAxisAlignment
    alignmentX*: float64
    alignmentY*: float64
    spacing*: float64
    fixedWidth*: float64
    fixedHeight*: float64
    insets*: Insets
    flex*: float64
    cached*: Size
    frame*: Rectangle

proc insetsAll*(all: float64): Insets {.inline.} =
  Insets(left: all, top: all, right: all, bottom: all)

proc insetsHV*(h: float64, v: float64): Insets {.inline.} =
  Insets(left: h, top: v, right: h, bottom: v)

proc insetsLTRB*(left: float64, top: float64, right: float64, bottom: float64): Insets {.
    inline.} =
  Insets(left: left, top: top, right: right, bottom: bottom)

# EdgeInsets-style constructors (Flutter parity)

proc all*(v: float64): Insets {.inline.} =
  insetsAll(v)

proc symmetric*(h = 0.0, v = 0.0): Insets {.inline.} =
  insetsHV(h, v)

proc only*(left = 0.0, top = 0.0, right = 0.0, bottom = 0.0): Insets {.inline.} =
  insetsLTRB(left, top, right, bottom)

proc zero*(): Insets {.inline.} =
  Insets(left: 0.0, top: 0.0, right: 0.0, bottom: 0.0)

proc insH*(i: Insets): float64 {.inline.} =
  i.left + i.right

proc insV*(i: Insets): float64 {.inline.} =
  i.top + i.bottom

proc initNode*[T: LayoutNode](n: T, kind: LayoutKind): T =
  n.kind = kind
  n.mainAlign = maStart
  n.crossAlign = caStart
  n.alignmentX = 0.0
  n.alignmentY = 0.0
  result = n

method measureSelf*(n: LayoutNode, maxWidth: float64, maxHeight: float64): Size {.
    base.} =
  size(0.0, 0.0)

method placeSelf*(n: LayoutNode, rect: Rectangle, parentSize: Size) {.base.} =
  discard

func isFlex*(n: LayoutNode): bool {.inline.} =
  n.flex > 0.0

proc newRow*(children: varargs[LayoutNode]): LayoutNode =
  result = initNode(LayoutNode(), likRow)
  for c in children:
    result.children.add(c)

proc newColumn*(children: varargs[LayoutNode]): LayoutNode =
  result = initNode(LayoutNode(), likColumn)
  for c in children:
    result.children.add(c)

proc spacing*[T: LayoutNode](n: T, value: float64): T =
  n.spacing = value
  n

proc mainAlign*[T: LayoutNode](n: T, value: MainAxisAlignment): T =
  n.mainAlign = value
  n

proc crossAlign*[T: LayoutNode](n: T, value: CrossAxisAlignment): T =
  n.crossAlign = value
  n

proc newExpanded*(child: LayoutNode, flex = 1.0): LayoutNode =
  result = initNode(LayoutNode(), likExpanded)
  result.flex = flex
  if not child.isNil:
    result.children.add(child)

proc alignmentVector*(a: Alignment): tuple[x, y: float64] {.inline.} =
  case a
  of alTopLeft: (-1.0, -1.0)
  of alTopCenter: (0.0, -1.0)
  of alTopRight: (1.0, -1.0)
  of alCenterLeft: (-1.0, 0.0)
  of alCenter: (0.0, 0.0)
  of alCenterRight: (1.0, 0.0)
  of alBottomLeft: (-1.0, 1.0)
  of alBottomCenter: (0.0, 1.0)
  of alBottomRight: (1.0, 1.0)

proc newAligned*(child: LayoutNode, x = 0.0, y = 0.0): LayoutNode =
  ## Positions child inside the granted rect using normalized offsets in
  ## [-1, +1]; (0, 0) is the center.
  result = initNode(LayoutNode(), likAlign)
  result.alignmentX = x
  result.alignmentY = y
  if not child.isNil:
    result.children.add(child)

proc newAligned*(child: LayoutNode, alignment: Alignment): LayoutNode =
  let (x, y) = alignmentVector(alignment)
  newAligned(child, x, y)

proc newCenter*(child: LayoutNode): LayoutNode =
  newAligned(child, alCenter)

proc newSizedBox*(width = 0.0, height = 0.0, child: LayoutNode = nil): LayoutNode =
  result = initNode(LayoutNode(), likSizedBox)
  result.fixedWidth = width
  result.fixedHeight = height
  if not child.isNil:
    result.children.add(child)

proc newPadding*(child: LayoutNode, all = 0.0): LayoutNode =
  result = initNode(LayoutNode(), likPadding)
  result.insets = insetsAll(all)
  if not child.isNil:
    result.children.add(child)

proc newPadding*(child: LayoutNode, h: float64, v: float64): LayoutNode =
  result = initNode(LayoutNode(), likPadding)
  result.insets = insetsHV(h, v)
  if not child.isNil:
    result.children.add(child)

proc newPadding*(child: LayoutNode, left: float64, top: float64, right: float64,
                 bottom: float64): LayoutNode =
  result = initNode(LayoutNode(), likPadding)
  result.insets = insetsLTRB(left, top, right, bottom)
  if not child.isNil:
    result.children.add(child)

proc newMargin*(child: LayoutNode, all = 0.0): LayoutNode =
  result = initNode(LayoutNode(), likMargin)
  result.insets = insetsAll(all)
  if not child.isNil:
    result.children.add(child)

proc newMargin*(child: LayoutNode, h: float64, v: float64): LayoutNode =
  result = initNode(LayoutNode(), likMargin)
  result.insets = insetsHV(h, v)
  if not child.isNil:
    result.children.add(child)

proc newMargin*(child: LayoutNode, left: float64, top: float64, right: float64,
                bottom: float64): LayoutNode =
  result = initNode(LayoutNode(), likMargin)
  result.insets = insetsLTRB(left, top, right, bottom)
  if not child.isNil:
    result.children.add(child)

proc measure*(n: LayoutNode, maxWidth: float64, maxHeight: float64): Size =
  case n.kind
  of likLeaf:
    n.cached = n.measureSelf(maxWidth, maxHeight)
    result = n.cached
  of likExpanded:
    if n.children.len > 0:
      let cs = measure(n.children[0], maxWidth, maxHeight)
      n.cached = cs
    else:
      n.cached = size(0.0, 0.0)
    result = n.cached
  of likAlign:
    ## Hugs the child here; positioning happens in placeChildren when the
    ## granted rect is larger than the child.
    if n.children.len > 0:
      n.cached = measure(n.children[0], maxWidth, maxHeight)
    else:
      n.cached = size(0.0, 0.0)
    result = n.cached
  of likSizedBox:
    var cs = size(0.0, 0.0)
    if n.children.len > 0:
      cs = measure(n.children[0], maxWidth, maxHeight)
    let w = if n.fixedWidth > 0.0: n.fixedWidth else: cs.width
    let h = if n.fixedHeight > 0.0: n.fixedHeight else: cs.height
    n.cached = size(w, h)
    result = n.cached
  of likPadding, likMargin:
    let i = n.insets
    var cs = size(0.0, 0.0)
    if n.children.len > 0:
      cs = measure(n.children[0], maxWidth - i.insH(), maxHeight - i.insV())
    n.cached = size(cs.width + i.insH(), cs.height + i.insV())
    result = n.cached
  of likRow:
    var main = 0.0
    var cross = 0.0
    for c in n.children:
      discard measure(c, maxWidth, maxHeight)
      if not c.isFlex():
        main += c.cached.width
      cross = max(cross, c.cached.height)
    if n.children.len > 1:
      main += n.spacing * float64(n.children.len - 1)
    n.cached = size(max(main, 0.0), cross + 0.0)
    result = n.cached
  of likColumn:
    var main = 0.0
    var cross = 0.0
    for c in n.children:
      discard measure(c, maxWidth, maxHeight)
      if not c.isFlex():
        main += c.cached.height
      cross = max(cross, c.cached.width)
    if n.children.len > 1:
      main += n.spacing * float64(n.children.len - 1)
    n.cached = size(cross + 0.0, max(main, 0.0))
    result = n.cached

proc distributeMain*(totalMain: float64, sizes: var seq[float64], flexes: seq[float64],
                     spacing: float64, align: MainAxisAlignment): tuple[leading: float64,
                     between: float64] =
  ## Mutates sizes with final main-axis extents. Returns the leading offset and
  ## the effective gap between children.
  let count = sizes.len
  if count == 0:
    return (0.0, spacing)
  var totalFlex = 0.0
  var fixedTotal = 0.0
  for i in 0 ..< count:
    if flexes[i] > 0.0:
      totalFlex += flexes[i]
    else:
      fixedTotal += sizes[i]
  let gaps = if count > 1: spacing * float64(count - 1) else: 0.0
  let free = totalMain - fixedTotal - gaps

  if totalFlex > 0.0:
    for i in 0 ..< count:
      if flexes[i] > 0.0:
        sizes[i] = max(free * flexes[i] / totalFlex, 0.0)
    return (0.0, spacing)

  let leftover = max(free, 0.0)
  var leading = 0.0
  var between = spacing
  case align
  of maStart:
    discard
  of maCenter:
    leading = leftover / 2.0
  of maEnd:
    leading = leftover
  of maSpaceBetween:
    if count > 1:
      between = spacing + leftover / float64(count - 1)
  of maSpaceAround:
    between = spacing + leftover / float64(count)
    leading = between / 2.0
  of maSpaceEvenly:
    between = spacing + leftover / float64(count + 1)
    leading = between
  result = (leading, between)

proc crossExtent*(crossAlign: CrossAxisAlignment, innerCross: float64,
                  measured: float64): tuple[extent: float64, offset: float64] =
  case crossAlign
  of caStretch:
    (innerCross, 0.0)
  of caCenter:
    (measured, (innerCross - measured) / 2.0)
  of caEnd:
    (measured, innerCross - measured)
  of caStart:
    (measured, 0.0)

proc place*(n: LayoutNode, rect: Rectangle, parentSize: Size)

proc placeChildren*(n: LayoutNode, rect: Rectangle, parentSize: Size) =
  case n.kind
  of likLeaf:
    discard
  of likExpanded:
    if n.children.len > 0:
      place(n.children[0], rectangle(0.0, 0.0, rect.width, rect.height), rect.size())
  of likAlign:
    if n.children.len > 0:
      let c = n.children[0]
      let freeX = max(rect.width - c.cached.width, 0.0)
      let freeY = max(rect.height - c.cached.height, 0.0)
      let cx = freeX * (n.alignmentX + 1.0) / 2.0
      let cy = freeY * (n.alignmentY + 1.0) / 2.0
      place(c, rectangle(cx, cy, min(c.cached.width, rect.width),
                         min(c.cached.height, rect.height)), rect.size())
  of likSizedBox, likPadding, likMargin:
    if n.children.len > 0:
      let i = n.insets
      let inner = rectangle(i.left, i.top,
                            max(rect.width - i.insH(), 0.0),
                            max(rect.height - i.insV(), 0.0))
      place(n.children[0], inner, rect.size())
  of likRow:
    let i = n.insets
    let innerW = max(rect.width - i.insH(), 0.0)
    let innerH = max(rect.height - i.insV(), 0.0)
    let count = n.children.len
    if count == 0:
      return
    var sizes: seq[float64] = @[]
    var flexes: seq[float64] = @[]
    for c in n.children:
      sizes.add(c.cached.width)
      flexes.add(c.flex)
    let (leading, between) = distributeMain(innerW, sizes, flexes, n.spacing, n.mainAlign)
    var cursor = i.left + leading
    for idx in 0 ..< count:
      let c = n.children[idx]
      let ce = crossExtent(n.crossAlign, innerH, c.cached.height)
      let childRect = rectangle(cursor, i.top + ce.offset, sizes[idx], ce.extent)
      place(c, childRect, size(rect.width, rect.height))
      cursor += sizes[idx] + between
  of likColumn:
    let i = n.insets
    let innerW = max(rect.width - i.insH(), 0.0)
    let innerH = max(rect.height - i.insV(), 0.0)
    let count = n.children.len
    if count == 0:
      return
    var sizes: seq[float64] = @[]
    var flexes: seq[float64] = @[]
    for c in n.children:
      sizes.add(c.cached.height)
      flexes.add(c.flex)
    let (leading, between) = distributeMain(innerH, sizes, flexes, n.spacing, n.mainAlign)
    var cursor = i.top + leading
    for idx in 0 ..< count:
      let c = n.children[idx]
      let ce = crossExtent(n.crossAlign, innerW, c.cached.width)
      let childRect = rectangle(i.left + ce.offset, cursor, ce.extent, sizes[idx])
      place(c, childRect, size(rect.width, rect.height))
      cursor += sizes[idx] + between

proc place*(n: LayoutNode, rect: Rectangle, parentSize: Size) =
  n.frame = rect
  n.placeSelf(rect, parentSize)
  placeChildren(n, rect, parentSize)

proc computeLayout*(root: LayoutNode, available: Size) =
  ## Measures the tree and lays it out inside a rect of the given size at
  ## origin 0,0. The root's own placement is left to the host (e.g. the
  ## window content fill), only its children are positioned.
  discard measure(root, available.width, available.height)
  placeChildren(root, rectangle(0.0, 0.0, available.width, available.height),
                size(0.0, 0.0))
