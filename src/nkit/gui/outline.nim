## Native disclosure tree (NSOutlineView): expandable nodes, selection,
## double-click activation.
##
## macOS-only by design. Guard call sites with `when defined(macosx)`.
## Nim owns the model as a flat node list; node keys are uint64 with
## 0 reserved as the "top level" parent marker, so keys must be nonzero.
## The native side mirrors nodes + texts and renders disclosure triangles
## for nodes that have children. To lazy-load, append children in an
## `onExpand` handler and call `reloadKey`.
##
##   outline.setNodes(@[(1, 0, true), (2, 1, false)])
##   outline.setRowTexts(1, @["Inbox", "42"])
##   outline.setRowTexts(2, @["Drafts", "3"])

when defined(macosx):
  import std/tables
  import std/strutils
  import ../foundation/id_allocator
  import ../foundation/event
  import ../foundation/event_emitter
  import ./view
  import ./table
  import ../image
  import ../platform/macos/nsfunctions

  export view

  type
    OutlineEntry* = tuple[key: uint64, parent: uint64, expanded: bool]

    OutlineSelectionEvent* = ref object of GuiEvent
      outlineId*: Id

    OutlineExpandEvent* = ref object of GuiEvent
      outlineId*: Id
      key*: uint64

    OutlineCollapseEvent* = ref object of GuiEvent
      outlineId*: Id
      key*: uint64

    OutlineActivateEvent* = ref object of GuiEvent
      outlineId*: Id

    OutlineCheckEvent* = ref object of GuiEvent
      outlineId*: Id
      key*: uint64
      column*: int
      checked*: bool

    OutlineEditEvent* = ref object of GuiEvent
      outlineId*: Id
      key*: uint64
      column*: int
      text*: string

    OutlineMoveEvent* = ref object of GuiEvent
      outlineId*: Id
      parent*: uint64
      index*: int

    OutlineFileDropEvent* = ref object of GuiEvent
      outlineId*: Id
      parent*: uint64
      index*: int

    OutlineView* = ref object of View
      columns*: seq[string]
      colKinds*: seq[TableCellKind]
      nodes*: seq[OutlineEntry]
      texts*: Table[uint64, seq[string]]
      images*: Table[(uint64, int), Image]
      multiValue*: bool

  var liveOutlines: Table[uint32, OutlineView]

  method typeName(e: OutlineSelectionEvent): string = "OutlineSelectionEvent"
  method typeName(e: OutlineExpandEvent): string = "OutlineExpandEvent"
  method typeName(e: OutlineCollapseEvent): string = "OutlineCollapseEvent"
  method typeName(e: OutlineActivateEvent): string = "OutlineActivateEvent"
  method typeName(e: OutlineCheckEvent): string = "OutlineCheckEvent"
  method typeName(e: OutlineEditEvent): string = "OutlineEditEvent"
  method typeName(e: OutlineMoveEvent): string = "OutlineMoveEvent"
  method typeName(e: OutlineFileDropEvent): string = "OutlineFileDropEvent"

  proc newOutlineSelectionEvent*(outlineId: Id): OutlineSelectionEvent =
    result = OutlineSelectionEvent(outlineId: outlineId)
    discard stamp(result)

  proc newOutlineExpandEvent*(outlineId: Id, key: uint64): OutlineExpandEvent =
    result = OutlineExpandEvent(outlineId: outlineId, key: key)
    discard stamp(result)

  proc newOutlineCollapseEvent*(outlineId: Id,
                                key: uint64): OutlineCollapseEvent =
    result = OutlineCollapseEvent(outlineId: outlineId, key: key)
    discard stamp(result)

  proc newOutlineActivateEvent*(outlineId: Id): OutlineActivateEvent =
    result = OutlineActivateEvent(outlineId: outlineId)
    discard stamp(result)

  proc newOutlineCheckEvent*(outlineId: Id, key: uint64, column: int,
                             checked: bool): OutlineCheckEvent =
    result = OutlineCheckEvent(outlineId: outlineId, key: key, column: column,
                               checked: checked)
    discard stamp(result)

  proc newOutlineEditEvent*(outlineId: Id, key: uint64, column: int,
                            text: string): OutlineEditEvent =
    result = OutlineEditEvent(outlineId: outlineId, key: key, column: column,
                              text: text)
    discard stamp(result)

  proc newOutlineMoveEvent*(outlineId: Id, parent: uint64,
                            index: int): OutlineMoveEvent =
    result = OutlineMoveEvent(outlineId: outlineId, parent: parent,
                              index: index)
    discard stamp(result)

  proc newOutlineFileDropEvent*(outlineId: Id, parent: uint64,
                                index: int): OutlineFileDropEvent =
    result = OutlineFileDropEvent(outlineId: outlineId, parent: parent,
                                  index: index)
    discard stamp(result)

  proc outlineEventTrampoline(widgetId: uint32, kind: cint, key: uint64,
                              col: int64, ctx: pointer) {.cdecl.} =
    let o = liveOutlines.getOrDefault(widgetId)
    if o.isNil:
      return
    case kind
    of 0:
      emitAsync(o, newOutlineSelectionEvent(o.id))
    of 1:
      emitAsync(o, newOutlineExpandEvent(o.id, key))
    of 2:
      emitAsync(o, newOutlineCollapseEvent(o.id, key))
    of 3:
      emitAsync(o, newOutlineActivateEvent(o.id))
    of 4:
      let checked = naOutlineIsCellChecked(o.native, key, col)
      emitAsync(o, newOutlineCheckEvent(o.id, key, int(col), checked))
    of 5:
      let text = $naOutlineGetText(o.native, key, col)
      var texts = o.texts.getOrDefault(key)
      while texts.len <= int(col):
        texts.add("")
      if col >= 0:
        texts[int(col)] = text
        o.texts[key] = texts
      emitAsync(o, newOutlineEditEvent(o.id, key, int(col), text))
    of 6:
      emitAsync(o, newOutlineMoveEvent(o.id, key, int(col)))
    of 7:
      emitAsync(o, newOutlineFileDropEvent(o.id, key, int(col)))
    else:
      discard

  var outlineCallbacksArmed = false

  proc ensureOutlineCallbacks*() =
    if not outlineCallbacksArmed:
      naOutlineSetEventCallback(outlineEventTrampoline, nil)
      outlineCallbacksArmed = true

  proc pushNodes(o: OutlineView) =
    var keys: seq[uint64] = @[]
    var parents: seq[uint64] = @[]
    var expanded: seq[bool] = @[]
    for n in o.nodes:
      keys.add(n.key)
      parents.add(n.parent)
      expanded.add(n.expanded)
    if keys.len > 0:
      naOutlineSetNodes(o.native, addr keys[0], addr parents[0],
                        addr expanded[0], cint(keys.len))
    else:
      naOutlineSetNodes(o.native, nil, nil, nil, 0)

  proc pushTexts(o: OutlineView, key: uint64) =
    let texts = o.texts.getOrDefault(key)
    for c in 0 ..< o.columns.len:
      naOutlineSetText(o.native, key, int64(c),
                       if c < texts.len: texts[c].cstring else: "".cstring)

  proc newOutlineView*(allowMultiple = false): OutlineView =
    ensureOutlineCallbacks()
    let vid = allocate(typeTagGuiWidget)
    let nativePtr = naOutlineCreate(vid.uint32, allowMultiple)
    result = OutlineView(multiValue: allowMultiple)
    discard wrapView(result, nativePtr, vid)
    liveOutlines[vid.uint32] = result

  proc destroy*(o: OutlineView) =
    naOutlineFree(o.nativeKey, o.native)
    o.native = nil
    liveOutlines.del(o.nativeKey)
    shutdownEmitter[GuiEvent](o)

  proc addColumn*(o: OutlineView, title: string,
                  width = 160.0,
                  kind: TableCellKind = tckText): int =
    ## Appends a column. The first column carries the disclosure triangles.
    ## Returns its index.
    let idx = int(naOutlineAddColumn(o.native, title.cstring, width,
                                    cint(ord(kind))))
    if idx >= 0:
      o.columns.add(title)
      o.colKinds.add(kind)
    idx

  proc clearColumns*(o: OutlineView) =
    naOutlineClearColumns(o.native)
    o.columns.setLen(0)
    o.colKinds.setLen(0)
    o.texts.clear()
    o.images.clear()
    for i in 0 ..< o.nodes.len:
      o.nodes[i].expanded = false

  proc columnCount*(o: OutlineView): int =
    o.columns.len

  proc setColumnWidth*(o: OutlineView, col: int, width: float64) =
    if col >= 0 and col < o.columns.len and width > 0:
      naOutlineSetColumnWidth(o.native, int64(col), width)

  proc setNodes*(o: OutlineView, nodes: openArray[OutlineEntry]) =
    ## Replaces the node list (nonzero keys; parent 0 = top level) and
    ## refreshes the view, restoring expanded flags.
    o.nodes = @nodes
    o.pushNodes()
    for n in o.nodes:
      o.pushTexts(n.key)

  proc getNodes*(o: OutlineView): seq[OutlineEntry] =
    o.nodes

  proc nodeCount*(o: OutlineView): int =
    o.nodes.len

  proc setCellText*(o: OutlineView, key: uint64, col: int, text: string) =
    if col < 0 or col >= o.columns.len:
      return
    var texts = o.texts.getOrDefault(key)
    while texts.len <= col:
      texts.add("")
    texts[col] = text
    o.texts[key] = texts
    naOutlineSetText(o.native, key, int64(col), text.cstring)

  proc setRowTexts*(o: OutlineView, key: uint64,
                    texts: openArray[string]) =
    for c in 0 ..< min(texts.len, o.columns.len):
      o.setCellText(key, c, texts[c])

  proc getCellText*(o: OutlineView, key: uint64, col: int): string =
    let texts = o.texts.getOrDefault(key)
    if col >= 0 and col < texts.len:
      texts[col]
    else:
      ""

  proc reload*(o: OutlineView) =
    o.pushNodes()
    for n in o.nodes:
      o.pushTexts(n.key)
    naOutlineReload(o.native)

  proc reloadKey*(o: OutlineView, key: uint64, reloadChildren = true) =
    ## Refreshes one subtree, e.g. after lazy-loading children in an
    ## `onExpand` handler.
    naOutlineReloadKey(o.native, key, reloadChildren)

  proc isExpanded*(o: OutlineView, key: uint64): bool =
    naOutlineIsExpanded(o.native, key)

  proc setExpanded*(o: OutlineView, key: uint64, expanded: bool) =
    for i in 0 ..< o.nodes.len:
      if o.nodes[i].key == key:
        o.nodes[i].expanded = expanded
    naOutlineSetExpanded(o.native, key, expanded)

  proc expandAll*(o: OutlineView) =
    for i in 0 ..< o.nodes.len:
      o.nodes[i].expanded = true
    o.pushNodes()

  proc collapseAll*(o: OutlineView) =
    for i in 0 ..< o.nodes.len:
      o.nodes[i].expanded = false
    o.pushNodes()

  proc setIndent*(o: OutlineView, points: float64) =
    naOutlineSetIndent(o.native, points)

  proc setRowHeight*(o: OutlineView, height: float64) =
    naOutlineSetRowHeight(o.native, height)

  proc setRowHeight*(o: OutlineView, key: uint64, height: float64) =
    ## Per-node height override. Cleared by `clearRowHeights`.
    if height > 0:
      var keys = @[key]
      var hs = @[height]
      naOutlineSetRowHeights(o.native, addr keys[0], addr hs[0], 1)

  proc setRowHeights*(o: OutlineView, heights: openArray[tuple[key: uint64,
      height: float64]]) =
    var keys: seq[uint64] = @[]
    var hs: seq[float64] = @[]
    for h in heights:
      if h.height > 0:
        keys.add(h.key)
        hs.add(h.height)
    if keys.len > 0:
      naOutlineSetRowHeights(o.native, addr keys[0], addr hs[0],
                            cint(keys.len))

  proc clearRowHeights*(o: OutlineView) =
    naOutlineClearRowHeights(o.native)

  proc setCellChecked*(o: OutlineView, key: uint64, col: int,
                       checked: bool) =
    ## Sets a checkbox cell. The column should use `tckCheck`.
    naOutlineSetCellChecked(o.native, key, int64(col), checked)

  proc isCellChecked*(o: OutlineView, key: uint64, col: int): bool =
    naOutlineIsCellChecked(o.native, key, int64(col))

  proc setCellImage*(o: OutlineView, key: uint64, col: int, img: Image) =
    ## Sets an image cell, keeping `img` alive while displayed.
    ## Pass nil to clear.
    if img.isNil:
      o.images.del((key, col))
      naOutlineSetCellImage(o.native, key, int64(col), 0)
    else:
      o.images[(key, col)] = img
      naOutlineSetCellImage(o.native, key, int64(col), img.handle)

  proc setColumnEditable*(o: OutlineView, col: int, editable: bool) =
    ## Allows in-place text editing; commits arrive as `OutlineEditEvent`.
    if col >= 0 and col < o.columns.len:
      naOutlineSetColEditable(o.native, int64(col), editable)

  proc setAllowsMultiple*(o: OutlineView, allow: bool) =
    o.multiValue = allow
    naOutlineSetMulti(o.native, allow)

  proc setPendingMore*(o: OutlineView, key: uint64) =
    ## Marks `key` as having unloaded children so its disclosure triangle
    ## shows. Load them in `onExpand` and finish with `appendChildren`,
    ## which clears the mark and keeps the node open.
    naOutlineSetHasMore(o.native, key, true)

  proc clearPendingMore*(o: OutlineView, key: uint64) =
    naOutlineSetHasMore(o.native, key, false)

  proc hasPendingMore*(o: OutlineView, key: uint64): bool =
    naOutlineHasMore(o.native, key)

  proc appendChildren*(o: OutlineView, parent: uint64,
                       children: openArray[OutlineEntry]) =
    ## Adds lazily loaded children under `parent`, keeps it expanded,
    ## and clears its pending mark. Follow with `setRowTexts` per child.
    for i in 0 ..< o.nodes.len:
      if o.nodes[i].key == parent:
        o.nodes[i].expanded = true
        break
    for c in children:
      o.nodes.add(c)
    o.clearPendingMore(parent)
    o.pushNodes()

  proc allowsMultiple*(o: OutlineView): bool =
    o.multiValue

  proc getSelectedKeys*(o: OutlineView): seq[uint64] =
    let cap = max(o.nodes.len, 1)
    var buf = newSeq[uint64](cap)
    let n = int(naOutlineSelectedKeys(o.native, addr buf[0], cint(cap)))
    for i in 0 ..< n:
      result.add(buf[i])

  proc selectKeys*(o: OutlineView, keys: openArray[uint64],
                   extend = false) =
    var buf: seq[uint64] = @keys
    if buf.len > 0:
      naOutlineSelectKeys(o.native, addr buf[0], cint(buf.len), extend)

  proc clearSelection*(o: OutlineView) =
    naOutlineClearSelection(o.native)

  proc scrollToKey*(o: OutlineView, key: uint64) =
    naOutlineScrollToKey(o.native, key)

  proc onSelection*(o: OutlineView,
                    handler: proc(e: OutlineSelectionEvent)): ListenerId =
    addListener[GuiEvent, OutlineSelectionEvent](o, handler)

  proc onExpand*(o: OutlineView,
                 handler: proc(e: OutlineExpandEvent)): ListenerId =
    addListener[GuiEvent, OutlineExpandEvent](o, handler)

  proc onCollapse*(o: OutlineView,
                   handler: proc(e: OutlineCollapseEvent)): ListenerId =
    addListener[GuiEvent, OutlineCollapseEvent](o, handler)

  proc onActivate*(o: OutlineView,
                   handler: proc(e: OutlineActivateEvent)): ListenerId =
    addListener[GuiEvent, OutlineActivateEvent](o, handler)

  proc onCheck*(o: OutlineView,
                handler: proc(e: OutlineCheckEvent)): ListenerId =
    addListener[GuiEvent, OutlineCheckEvent](o, handler)

  proc onEdit*(o: OutlineView,
               handler: proc(e: OutlineEditEvent)): ListenerId =
    addListener[GuiEvent, OutlineEditEvent](o, handler)

  proc fireSelect*(o: OutlineView) =
    ## Full-stack test hook.
    naOutlineFireSelect(o.nativeKey)

  proc fireExpand*(o: OutlineView, key: uint64) =
    ## Full-stack test hook.
    naOutlineFireExpand(o.nativeKey, key)

  proc fireCollapse*(o: OutlineView, key: uint64) =
    ## Full-stack test hook.
    naOutlineFireCollapse(o.nativeKey, key)

  proc fireActivate*(o: OutlineView) =
    ## Full-stack test hook.
    naOutlineFireActivate(o.nativeKey)

  proc fireCheck*(o: OutlineView, key: uint64, col: int, checked: bool) =
    ## Full-stack test hook. Sets the state first, like a live toggle.
    o.setCellChecked(key, col, checked)
    naOutlineFireCheck(o.nativeKey, key, int64(col))

  proc fireEdit*(o: OutlineView, key: uint64, col: int, text: string) =
    ## Full-stack test hook. Writes the text first, like a live commit.
    o.setCellText(key, col, text)
    naOutlineFireEdit(o.nativeKey, key, int64(col))

  proc setAcceptsMoves*(o: OutlineView, accept: bool) =
    ## Allows dragging nodes to move them. Drops arrive as `OutlineMoveEvent`;
    ## read `getDropKeys`, update parents, call `setNodes`.
    naOutlineSetAcceptsMoves(o.native, accept)

  proc acceptsMoves*(o: OutlineView): bool =
    naOutlineAcceptsMoves(o.native)

  proc setAcceptsFiles*(o: OutlineView, accept: bool) =
    ## Allows dropping Finder files. Drops arrive as `OutlineFileDropEvent`;
    ## read `getDropFiles`.
    naOutlineSetAcceptsFiles(o.native, accept)

  proc acceptsFiles*(o: OutlineView): bool =
    naOutlineAcceptsFiles(o.native)

  proc getDropKeys*(o: OutlineView): seq[uint64] =
    ## Keys of the in-flight internal move. Query in `onMove`.
    let cap = max(o.nodes.len, 1)
    var buf = newSeq[uint64](cap)
    let n = int(naOutlineDropKeys(o.native, addr buf[0], cint(cap)))
    for i in 0 ..< n:
      result.add(buf[i])

  proc getDropFiles*(o: OutlineView): seq[string] =
    ## Paths of the in-flight file drop. Query in `onFileDrop`.
    var buf = newString(65536)
    let n = int(naOutlineDropFiles(o.native, buf.cstring, 65536))
    if n > 0:
      for p in ($buf).split('\0')[0].splitLines():
        if p.len > 0:
          result.add(p)

  proc onMove*(o: OutlineView,
               handler: proc(e: OutlineMoveEvent)): ListenerId =
    addListener[GuiEvent, OutlineMoveEvent](o, handler)

  proc onFileDrop*(o: OutlineView,
                   handler: proc(e: OutlineFileDropEvent)): ListenerId =
    addListener[GuiEvent, OutlineFileDropEvent](o, handler)

  proc fireMove*(o: OutlineView, parent: uint64, index: int,
                 keys: openArray[uint64]) =
    ## Full-stack test hook. Plants keys first, like a live drop.
    var buf: seq[uint64] = @keys
    if buf.len > 0:
      naOutlineFireMove(o.nativeKey, o.native, parent, int64(index),
                       addr buf[0], cint(buf.len))
    else:
      naOutlineFireMove(o.nativeKey, o.native, parent, int64(index), nil, 0)

  proc fireFileDrop*(o: OutlineView, parent: uint64, index: int,
                     paths: openArray[string]) =
    ## Full-stack test hook. Plants paths first, like a live drop.
    var buf: seq[cstring] = @[]
    for p in paths:
      buf.add(p.cstring)
    if buf.len > 0:
      naOutlineFireFileDrop(o.nativeKey, o.native, parent, int64(index),
                            addr buf[0], cint(buf.len))
    else:
      naOutlineFireFileDrop(o.nativeKey, o.native, parent, int64(index),
                            nil, 0)
