## Native multi-column table (NSTableView): sortable headers,
## single/multi selection, double-click activation.
##
## macOS-only by design. Guard call sites with `when defined(macosx)`.
## Nim owns the model (`columns` + `rows`); the native side mirrors it.
## Header clicks arrive as `TableSortEvent` — sort in Nim with `sortBy`
## (or your own comparator + `setRows`), then the indicator follows.

when defined(macosx):
  import std/tables
  import std/algorithm
  import std/sequtils
  import std/strutils
  import ../foundation/id_allocator
  import ../foundation/event
  import ../foundation/event_emitter
  import ./view
  import ../image
  import ../platform/macos/nsfunctions

  export view

  type
    TableCellKind* = enum
      tckText
      tckCheck
      tckImage

    TableColumnDef* = object
      title*: string
      width*: float64
      sortable*: bool
      kind*: TableCellKind

    TableSelectionEvent* = ref object of GuiEvent
      tableId*: Id

    TableSortColumn* = tuple[column: int, ascending: bool]

    TableSortEvent* = ref object of GuiEvent
      tableId*: Id
      column*: int
      ascending*: bool
      chain*: seq[TableSortColumn]

    TableActivateEvent* = ref object of GuiEvent
      tableId*: Id

    TableCheckEvent* = ref object of GuiEvent
      tableId*: Id
      row*: int
      column*: int
      checked*: bool

    TableEditEvent* = ref object of GuiEvent
      tableId*: Id
      row*: int
      column*: int
      text*: string

    TableReorderEvent* = ref object of GuiEvent
      tableId*: Id
      targetRow*: int

    TableFileDropEvent* = ref object of GuiEvent
      tableId*: Id
      targetRow*: int

    TableView* = ref object of View
      columns*: seq[TableColumnDef]
      rows*: seq[seq[string]]
      baseRows*: seq[seq[string]]
      checks*: Table[(int, int), bool]
      images*: Table[(int, int), Image]
      filterQuery*: string
      filterCols*: seq[int]
      filterCase*: bool
      multiValue*: bool

  var liveTables: Table[uint32, TableView]

  method typeName(e: TableSelectionEvent): string = "TableSelectionEvent"
  method typeName(e: TableSortEvent): string = "TableSortEvent"
  method typeName(e: TableActivateEvent): string = "TableActivateEvent"
  method typeName(e: TableCheckEvent): string = "TableCheckEvent"
  method typeName(e: TableEditEvent): string = "TableEditEvent"
  method typeName(e: TableReorderEvent): string = "TableReorderEvent"
  method typeName(e: TableFileDropEvent): string = "TableFileDropEvent"

  proc newTableSelectionEvent*(tableId: Id): TableSelectionEvent =
    result = TableSelectionEvent(tableId: tableId)
    discard stamp(result)

  proc newTableSortEvent*(tableId: Id, column: int,
                          ascending: bool): TableSortEvent =
    result = TableSortEvent(tableId: tableId, column: column,
                            ascending: ascending)
    discard stamp(result)

  proc getSortChain*(t: TableView): seq[TableSortColumn] =
    ## Reads the full shift-click sort chain from the headers.
    let cap = max(t.columns.len, 1)
    var cols = newSeq[int64](cap)
    var asc = newSeq[bool](cap)
    let n = int(naTableSortChain(t.native, addr cols[0], addr asc[0],
                                 cint(cap)))
    for i in 0 ..< n:
      result.add((int(cols[i]), asc[i]))

  proc newTableActivateEvent*(tableId: Id): TableActivateEvent =
    result = TableActivateEvent(tableId: tableId)
    discard stamp(result)

  proc newTableCheckEvent*(tableId: Id, row, column: int,
                           checked: bool): TableCheckEvent =
    result = TableCheckEvent(tableId: tableId, row: row, column: column,
                             checked: checked)
    discard stamp(result)

  proc newTableEditEvent*(tableId: Id, row, column: int,
                          text: string): TableEditEvent =
    result = TableEditEvent(tableId: tableId, row: row, column: column,
                            text: text)
    discard stamp(result)

  proc newTableReorderEvent*(tableId: Id, targetRow: int): TableReorderEvent =
    result = TableReorderEvent(tableId: tableId, targetRow: targetRow)
    discard stamp(result)

  proc newTableFileDropEvent*(tableId: Id, targetRow: int): TableFileDropEvent =
    result = TableFileDropEvent(tableId: tableId, targetRow: targetRow)
    discard stamp(result)

  proc tableEventTrampoline(widgetId: uint32, kind: cint, a: int64, b: int64,
                            c: int64, ctx: pointer) {.cdecl.} =
    let t = liveTables.getOrDefault(widgetId)
    if t.isNil:
      return
    case kind
    of 0:
      emitAsync(t, newTableSelectionEvent(t.id))
    of 1:
      let chain = t.getSortChain()
      var ev = newTableSortEvent(t.id, int(a), b != 0)
      ev.chain = chain
      emitAsync(t, ev)
    of 2:
      emitAsync(t, newTableActivateEvent(t.id))
    of 3:
      let checked = naTableIsCellChecked(t.native, a, b)
      t.checks[(int(a), int(b))] = checked
      emitAsync(t, newTableCheckEvent(t.id, int(a), int(b), checked))
    of 4:
      let text = $naTableGetCell(t.native, a, b)
      if int(a) >= 0 and int(a) < t.rows.len and int(b) >= 0:
        while t.rows[int(a)].len <= int(b):
          t.rows[int(a)].add("")
        t.rows[int(a)][int(b)] = text
      emitAsync(t, newTableEditEvent(t.id, int(a), int(b), text))
    of 5:
      emitAsync(t, newTableReorderEvent(t.id, int(a)))
    of 6:
      emitAsync(t, newTableFileDropEvent(t.id, int(a)))
    else:
      discard

  var tableCallbacksArmed = false

  proc ensureTableCallbacks*() =
    if not tableCallbacksArmed:
      naTableSetEventCallback(tableEventTrampoline, nil)
      tableCallbacksArmed = true

  proc pushRows(t: TableView) =
    var flat: seq[cstring] = @[]
    for row in t.rows:
      for c in 0 ..< t.columns.len:
        flat.add(if c < row.len: row[c].cstring else: "".cstring)
    if flat.len > 0:
      naTableSetRows(t.native, addr flat[0], int64(t.rows.len),
                     int64(t.columns.len))
    else:
      naTableSetRows(t.native, nil, int64(t.rows.len),
                     int64(t.columns.len))
    # set_rows resets native per-cell state; restore it from the mirror.
    for (pos, checked) in t.checks.pairs:
      naTableSetCellChecked(t.native, int64(pos[0]), int64(pos[1]), checked)
    for (pos, img) in t.images.pairs:
      if not img.isNil:
        naTableSetCellImage(t.native, int64(pos[0]), int64(pos[1]),
                            img.handle)

  proc newTableView*(allowMultiple = false): TableView =
    ensureTableCallbacks()
    let vid = allocate(typeTagGuiWidget)
    let nativePtr = naTableCreate(vid.uint32, allowMultiple)
    result = TableView(multiValue: allowMultiple)
    discard wrapView(result, nativePtr, vid)
    liveTables[vid.uint32] = result

  proc destroy*(t: TableView) =
    naTableFree(t.nativeKey, t.native)
    t.native = nil
    liveTables.del(t.nativeKey)
    shutdownEmitter[GuiEvent](t)

  proc addColumn*(t: TableView, title: string, width = 120.0,
                  sortable = true,
                  kind: TableCellKind = tckText): int =
    ## Appends a column. Returns its index.
    let idx = int(naTableAddColumn(t.native, title.cstring, width, sortable,
                                  cint(ord(kind))))
    if idx >= 0:
      t.columns.add(TableColumnDef(title: title, width: width,
                                   sortable: sortable, kind: kind))
    idx

  proc clearColumns*(t: TableView) =
    naTableClearColumns(t.native)
    t.columns.setLen(0)
    t.rows.setLen(0)
    t.checks.clear()
    t.images.clear()

  proc columnCount*(t: TableView): int =
    t.columns.len

  proc setColumnWidth*(t: TableView, col: int, width: float64) =
    if col >= 0 and col < t.columns.len and width > 0:
      t.columns[col].width = width
      naTableSetColumnWidth(t.native, int64(col), width)

  proc setRows*(t: TableView, rows: seq[seq[string]]) =
    ## Replaces the model (short rows pad with "", long rows truncate)
    ## and refreshes the view. Clears any active filter and per-cell
    ## checkbox/image state.
    t.rows = rows
    t.baseRows = rows
    t.filterQuery = ""
    t.checks.clear()
    t.images.clear()
    t.pushRows()

  proc getRows*(t: TableView): seq[seq[string]] =
    t.rows

  proc rowCount*(t: TableView): int =
    t.rows.len

  proc reload*(t: TableView) =
    t.pushRows()

  proc setRowHeight*(t: TableView, height: float64) =
    naTableSetRowHeight(t.native, height)

  proc setRowHeight*(t: TableView, row: int, height: float64) =
    ## Per-row height override. Cleared by `clearRowHeights`.
    if row >= 0 and row < t.rows.len and height > 0:
      var rows = @[int64(row)]
      var heights = @[height]
      naTableSetRowHeights(t.native, addr rows[0], addr heights[0], 1)

  proc setRowHeights*(t: TableView, heights: openArray[tuple[row: int,
      height: float64]]) =
    var rows: seq[int64] = @[]
    var hs: seq[float64] = @[]
    for h in heights:
      if h.row >= 0 and h.row < t.rows.len and h.height > 0:
        rows.add(int64(h.row))
        hs.add(h.height)
    if rows.len > 0:
      naTableSetRowHeights(t.native, addr rows[0], addr hs[0],
                           cint(rows.len))

  proc clearRowHeights*(t: TableView) =
    naTableClearRowHeights(t.native)

  proc getCellText*(t: TableView, row, col: int): string =
    $naTableGetCell(t.native, int64(row), int64(col))

  proc setCellChecked*(t: TableView, row, col: int, checked: bool) =
    ## Sets a checkbox cell. The column should use `tckCheck`.
    t.checks[(row, col)] = checked
    naTableSetCellChecked(t.native, int64(row), int64(col), checked)

  proc isCellChecked*(t: TableView, row, col: int): bool =
    t.checks.getOrDefault((row, col), false)

  proc setCellImage*(t: TableView, row, col: int, img: Image) =
    ## Sets an image cell, keeping `img` alive while displayed.
    ## Pass nil to clear.
    if img.isNil:
      t.images.del((row, col))
      naTableSetCellImage(t.native, int64(row), int64(col), 0)
    else:
      t.images[(row, col)] = img
      naTableSetCellImage(t.native, int64(row), int64(col), img.handle)

  proc setColumnEditable*(t: TableView, col: int, editable: bool) =
    ## Allows in-place text editing; commits arrive as `TableEditEvent`.
    if col >= 0 and col < t.columns.len:
      naTableSetColEditable(t.native, int64(col), editable)

  proc setAllowsMultiple*(t: TableView, allow: bool) =
    t.multiValue = allow
    naTableSetMulti(t.native, allow)

  proc allowsMultiple*(t: TableView): bool =
    t.multiValue

  proc getSelectedRows*(t: TableView): seq[int] =
    let cap = max(t.rows.len, 1)
    var buf = newSeq[int64](cap)
    let n = int(naTableSelectedRows(t.native, addr buf[0], cint(cap)))
    for i in 0 ..< n:
      result.add(int(buf[i]))

  proc selectRows*(t: TableView, indices: openArray[int],
                   extend = false) =
    var buf: seq[int64] = @[]
    for i in indices:
      if i >= 0 and i < t.rows.len:
        buf.add(int64(i))
    if buf.len > 0:
      naTableSelectRows(t.native, addr buf[0], cint(buf.len), extend)

  proc clearSelection*(t: TableView) =
    naTableClearSelection(t.native)

  proc scrollToRow*(t: TableView, row: int) =
    if row >= 0 and row < t.rows.len:
      naTableScrollToRow(t.native, int64(row))

  proc rowMatches(row: seq[string], query: string, cols: seq[int],
                  caseSensitive: bool): bool =
    let q = if caseSensitive: query else: query.toLowerAscii()
    let idxs = if cols.len > 0: cols else: toSeq(0 ..< row.len)
    for c in idxs:
      if c < 0 or c >= row.len:
        continue
      let cell = if caseSensitive: row[c] else: row[c].toLowerAscii()
      if q in cell:
        return true
    false

  proc applyFilter(t: TableView) =
    if t.filterQuery.len == 0:
      t.rows = t.baseRows
    else:
      t.rows = t.baseRows.filterIt(
        rowMatches(it, t.filterQuery, t.filterCols, t.filterCase))
    t.pushRows()

  proc setFilter*(t: TableView, query: string, cols: openArray[int] = [],
                  caseSensitive = false) =
    ## Shows only rows containing `query` in the given columns (all
    ## columns when empty). Per-cell checkbox/image state does not
    ## survive filtering; re-apply it afterwards.
    t.filterQuery = query
    t.filterCols = @cols
    t.filterCase = caseSensitive
    t.checks.clear()
    t.images.clear()
    t.applyFilter()

  proc clearFilter*(t: TableView) =
    ## Restores the unfiltered rows.
    t.filterQuery = ""
    t.checks.clear()
    t.images.clear()
    t.applyFilter()

  proc isFiltered*(t: TableView): bool =
    t.filterQuery.len > 0

  proc getFilter*(t: TableView): string =
    t.filterQuery

  proc sortRowsBy(data: var seq[seq[string]], clean: seq[TableSortColumn]) =
    data.sort(proc(a, b: seq[string]): int =
      for s in clean:
        let av = if s.column < a.len: a[s.column] else: ""
        let bv = if s.column < b.len: b[s.column] else: ""
        let c = if s.ascending: cmp(av, bv) else: cmp(bv, av)
        if c != 0:
          return c
      0)

  proc clearSortIndicator*(t: TableView) =
    naTableSetSortIndicator(t.native, -1, 0)

  proc sortByChain*(t: TableView, spec: openArray[TableSortColumn]) =
    ## Multi-column sort: rows order by each key in turn, and every
    ## header shows its indicator. Unknown/unsortable columns are skipped.
    ## When filtered, both the view and the base rows are sorted.
    var clean: seq[TableSortColumn] = @[]
    for s in spec:
      if s.column >= 0 and s.column < t.columns.len and
          t.columns[s.column].sortable:
        clean.add(s)
    sortRowsBy(t.rows, clean)
    if t.isFiltered():
      sortRowsBy(t.baseRows, clean)
    t.pushRows()
    var cols: seq[int64] = @[]
    var asc: seq[bool] = @[]
    for s in clean:
      cols.add(int64(s.column))
      asc.add(s.ascending)
    if cols.len > 0:
      naTableSetSortIndicators(t.native, addr cols[0], addr asc[0],
                               cint(cols.len))
    else:
      naTableSetSortIndicators(t.native, nil, nil, 0)

  proc sortBy*(t: TableView, col: int, ascending = true) =
    ## Sorts rows by column text in Nim and moves the header indicator.
    ## No-op for unknown or unsortable columns.
    if col < 0 or col >= t.columns.len or not t.columns[col].sortable:
      return
    t.sortByChain(@[(col, ascending)])

  proc onSelection*(t: TableView,
                    handler: proc(e: TableSelectionEvent)): ListenerId =
    addListener[GuiEvent, TableSelectionEvent](t, handler)

  proc onSort*(t: TableView,
               handler: proc(e: TableSortEvent)): ListenerId =
    addListener[GuiEvent, TableSortEvent](t, handler)

  proc onActivate*(t: TableView,
                   handler: proc(e: TableActivateEvent)): ListenerId =
    addListener[GuiEvent, TableActivateEvent](t, handler)

  proc onCheck*(t: TableView,
                handler: proc(e: TableCheckEvent)): ListenerId =
    addListener[GuiEvent, TableCheckEvent](t, handler)

  proc onEdit*(t: TableView,
               handler: proc(e: TableEditEvent)): ListenerId =
    addListener[GuiEvent, TableEditEvent](t, handler)

  proc fireSelect*(t: TableView) =
    ## Full-stack test hook.
    naTableFireSelect(t.nativeKey)

  proc fireSort*(t: TableView, col: int, ascending = true) =
    ## Full-stack test hook.
    naTableFireSort(t.nativeKey, int64(col), ascending)

  proc fireActivate*(t: TableView) =
    ## Full-stack test hook.
    naTableFireActivate(t.nativeKey)

  proc fireCheck*(t: TableView, row, col: int, checked: bool) =
    ## Full-stack test hook. Sets the state first, like a live toggle.
    t.setCellChecked(row, col, checked)
    naTableFireCheck(t.nativeKey, int64(row), int64(col))

  proc fireEdit*(t: TableView, row, col: int, text: string) =
    ## Full-stack test hook. Writes the text first, like a live commit.
    if row >= 0 and row < t.rows.len:
      while t.rows[row].len <= col:
        t.rows[row].add("")
      t.rows[row][col] = text
      t.pushRows()
    naTableFireEdit(t.nativeKey, int64(row), int64(col))

  proc setReorderable*(t: TableView, reorderable: bool) =
    ## Allows dragging rows to reorder. Drops arrive as `TableReorderEvent`;
    ## read `getDropSources`, reorder the model, call `setRows`.
    naTableSetReorderable(t.native, reorderable)

  proc isReorderable*(t: TableView): bool =
    naTableIsReorderable(t.native)

  proc setAcceptsFiles*(t: TableView, accept: bool) =
    ## Allows dropping Finder files. Drops arrive as `TableFileDropEvent`;
    ## read `getDropFiles`.
    naTableSetAcceptsFiles(t.native, accept)

  proc acceptsFiles*(t: TableView): bool =
    naTableAcceptsFiles(t.native)

  proc getDropSources*(t: TableView): seq[int] =
    ## Source rows of the in-flight internal drop. Query in `onReorder`.
    let cap = max(t.rows.len, 1)
    var buf = newSeq[int64](cap)
    let n = int(naTableDropSources(t.native, addr buf[0], cint(cap)))
    for i in 0 ..< n:
      result.add(int(buf[i]))

  proc getDropFiles*(t: TableView): seq[string] =
    ## Paths of the in-flight file drop. Query in `onFileDrop`.
    var buf = newString(65536)
    let n = int(naTableDropFiles(t.native, buf.cstring, 65536))
    if n > 0:
      for p in ($buf).split('\0')[0].splitLines():
        if p.len > 0:
          result.add(p)

  proc onReorder*(t: TableView,
                  handler: proc(e: TableReorderEvent)): ListenerId =
    addListener[GuiEvent, TableReorderEvent](t, handler)

  proc onFileDrop*(t: TableView,
                   handler: proc(e: TableFileDropEvent)): ListenerId =
    addListener[GuiEvent, TableFileDropEvent](t, handler)

  proc fireReorder*(t: TableView, targetRow: int, sources: openArray[int]) =
    ## Full-stack test hook. Plants sources first, like a live drop.
    var buf: seq[int64] = @[]
    for s in sources:
      buf.add(int64(s))
    if buf.len > 0:
      naTableFireReorder(t.nativeKey, t.native, int64(targetRow),
                         addr buf[0], cint(buf.len))
    else:
      naTableFireReorder(t.nativeKey, t.native, int64(targetRow), nil, 0)

  proc fireFileDrop*(t: TableView, targetRow: int,
                     paths: openArray[string]) =
    ## Full-stack test hook. Plants paths first, like a live drop.
    var buf: seq[cstring] = @[]
    for p in paths:
      buf.add(p.cstring)
    if buf.len > 0:
      naTableFireFileDrop(t.nativeKey, t.native, int64(targetRow),
                          addr buf[0], cint(buf.len))
    else:
      naTableFireFileDrop(t.nativeKey, t.native, int64(targetRow), nil, 0)
