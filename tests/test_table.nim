import unittest
import std/sequtils

import nkit

when defined(macosx):
  import nkit/gui/table
  import nkit/gui/outline
  import nkit/gui/sugar

  suite "table columns and rows":
    test "add count clear columns":
      let t = newTableView()
      defer:
        destroy(t)
      check t.columnCount() == 0
      check t.addColumn("From", 180.0) == 0
      check t.addColumn("Subject") == 1
      check t.addColumn("Date", 120.0, sortable = false) == 2
      check t.columnCount() == 3
      t.setColumnWidth(0, 200.0)
      check t.columns[0].width == 200.0
      t.clearColumns()
      check t.columnCount() == 0
      check t.rowCount() == 0
      check naTableColumnCount(t.native) == 0

    test "setRows round trip with ragged rows":
      let t = newTableView()
      defer:
        destroy(t)
      discard t.addColumn("A")
      discard t.addColumn("B")
      t.setRows(@[@["a1", "b1"], @["only"], @["a3", "b3", "extra"]])
      check t.rowCount() == 3
      check t.getRows()[1] == @["only"]
      check t.getRows()[2] == @["a3", "b3", "extra"]
      check naTableRowCount(t.native) == 3
      t.reload()
      check naTableRowCount(t.native) == 3

    test "sortBy orders rows and ignores bad columns":
      let t = newTableView()
      defer:
        destroy(t)
      discard t.addColumn("Name")
      discard t.addColumn("Fixed", sortable = false)
      t.setRows(@[@["c"], @["a"], @["b"]])
      t.sortBy(0)
      check t.getRows() == @[@["a"], @["b"], @["c"]]
      t.sortBy(0, ascending = false)
      check t.getRows() == @[@["c"], @["b"], @["a"]]
      t.sortBy(5)
      t.sortBy(1)
      check t.getRows() == @[@["c"], @["b"], @["a"]]
      t.clearSortIndicator()

  suite "table selection":
    test "multi flag round trip":
      let t = newTableView()
      defer:
        destroy(t)
      check not t.allowsMultiple()
      t.setAllowsMultiple(true)
      check t.allowsMultiple()

    test "select and read back rows":
      let t = newTableView(allowMultiple = true)
      defer:
        destroy(t)
      discard t.addColumn("A")
      t.setRows(@[@["r0"], @["r1"], @["r2"], @["r3"]])
      check t.getSelectedRows().len == 0
      t.selectRows([1, 3])
      check t.getSelectedRows() == @[1, 3]
      t.selectRows([0], extend = true)
      check t.getSelectedRows() == @[0, 1, 3]
      t.clearSelection()
      check t.getSelectedRows().len == 0
      t.selectRows([99, -1])
      check t.getSelectedRows().len == 0
      t.scrollToRow(2)
      t.scrollToRow(99)
      t.setRowHeight(24.0)

  suite "table events":
    test "selection activate route":
      let t = newTableView()
      defer:
        destroy(t)
      var selected = 0
      var activated = 0
      discard t.onSelection(proc(e: TableSelectionEvent) =
        check e.tableId == t.id
        inc selected)
      discard t.onActivate(proc(e: TableActivateEvent) =
        inc activated)
      t.fireSelect()
      t.fireActivate()
      discard runMainThreadLoopFor(100)
      check selected == 1
      check activated == 1

    test "sort event carries column and direction":
      let t = newTableView()
      defer:
        destroy(t)
      discard t.addColumn("A")
      discard t.addColumn("B")
      var col = -1
      var asc = false
      discard t.onSort(proc(e: TableSortEvent) =
        col = e.column
        asc = e.ascending)
      t.fireSort(1, ascending = false)
      discard runMainThreadLoopFor(100)
      check col == 1
      check not asc

    test "header click sorts end to end":
      let t = newTableView()
      defer:
        destroy(t)
      discard t.addColumn("Name")
      t.setRows(@[@["c"], @["a"], @["b"]])
      discard t.onSort(proc(e: TableSortEvent) =
        t.sortBy(e.column, e.ascending))
      t.fireSort(0, ascending = true)
      discard runMainThreadLoopFor(100)
      check t.getRows() == @[@["a"], @["b"], @["c"]]

    test "multi-column chain sorts and indicates":
      let t = newTableView()
      defer:
        destroy(t)
      discard t.addColumn("Last")
      discard t.addColumn("First")
      t.setRows(@[@["doe", "jane"], @["adams", "amy"], @["doe", "adam"]])
      t.sortByChain(@[(0, true), (1, true)])
      check t.getRows() == @[@["adams", "amy"], @["doe", "adam"],
                             @["doe", "jane"]]
      check t.getSortChain() == @[(0, true), (1, true)]
      t.sortByChain(@[(0, false)])
      check t.getRows()[0][0] == "doe"
      check t.getSortChain() == @[(0, false)]
      t.sortByChain(@[(9, true)])
      check t.getSortChain().len == 0

    test "sort event carries the full chain":
      let t = newTableView()
      defer:
        destroy(t)
      discard t.addColumn("A")
      discard t.addColumn("B")
      t.setRows(@[@["x", "1"], @["y", "2"]])
      t.sortByChain(@[(1, false), (0, true)])
      var chain: seq[TableSortColumn] = @[]
      discard t.onSort(proc(e: TableSortEvent) =
        chain = e.chain)
      t.fireSort(1, ascending = false)
      discard runMainThreadLoopFor(100)
      check chain == @[(1, false), (0, true)]

  suite "outline model":
    test "columns and nodes round trip":
      let o = newOutlineView()
      defer:
        destroy(o)
      check o.addColumn("Name") == 0
      check o.addColumn("Unread", 80.0) == 1
      check o.columnCount() == 2
      o.setNodes(@[(1'u64, 0'u64, true), (2'u64, 1'u64, false)])
      check o.nodeCount() == 2
      check o.getNodes() == @[(1'u64, 0'u64, true), (2'u64, 1'u64, false)]
      o.setRowTexts(1, @["Inbox", "42"])
      o.setRowTexts(2, @["Drafts"])
      check o.getCellText(1, 0) == "Inbox"
      check o.getCellText(1, 1) == "42"
      check o.getCellText(2, 1) == ""
      check o.getCellText(99, 0) == ""
      o.setCellText(2, 5, "nope")
      check o.getCellText(2, 5) == ""
      o.clearColumns()
      check o.columnCount() == 0
      check naOutlineColumnCount(o.native) == 0

    test "expand state round trips natively":
      let o = newOutlineView()
      defer:
        destroy(o)
      discard o.addColumn("Name")
      o.setNodes(@[(1'u64, 0'u64, true), (2'u64, 1'u64, false),
                   (4'u64, 0'u64, false), (5'u64, 4'u64, false)])
      check o.isExpanded(1)
      check not o.isExpanded(4)
      o.setExpanded(4, true)
      check o.isExpanded(4)
      o.setExpanded(1, false)
      check not o.isExpanded(1)
      o.expandAll()
      check o.isExpanded(1)
      check o.isExpanded(4)
      o.collapseAll()
      check not o.isExpanded(1)
      check not o.isExpanded(4)
      o.setIndent(20.0)
      o.reloadKey(1)
      o.reload()

  suite "outline selection":
    test "select and read back keys":
      let o = newOutlineView(allowMultiple = true)
      defer:
        destroy(o)
      check o.allowsMultiple()
      discard o.addColumn("Name")
      o.setNodes(@[(1'u64, 0'u64, true), (2'u64, 1'u64, false)])
      o.setRowTexts(1, @["Inbox"])
      o.setRowTexts(2, @["Drafts"])
      check o.getSelectedKeys().len == 0
      o.selectKeys([2'u64])
      check o.getSelectedKeys() == @[2'u64]
      o.selectKeys([1'u64], extend = true)
      check o.getSelectedKeys() == @[1'u64, 2'u64]
      o.clearSelection()
      check o.getSelectedKeys().len == 0
      o.scrollToKey(1)
      o.scrollToKey(99)
      o.setAllowsMultiple(false)
      check not o.allowsMultiple()

  suite "outline events":
    test "selection expand collapse activate route":
      let o = newOutlineView()
      defer:
        destroy(o)
      discard o.addColumn("Name")
      o.setNodes(@[(1'u64, 0'u64, false)])
      var selected = 0
      var expanded: uint64 = 0
      var collapsed: uint64 = 0
      var activated = 0
      discard o.onSelection(proc(e: OutlineSelectionEvent) =
        check e.outlineId == o.id
        inc selected)
      discard o.onExpand(proc(e: OutlineExpandEvent) =
        expanded = e.key)
      discard o.onCollapse(proc(e: OutlineCollapseEvent) =
        collapsed = e.key)
      discard o.onActivate(proc(e: OutlineActivateEvent) =
        inc activated)
      o.fireSelect()
      o.fireExpand(1)
      o.fireCollapse(1)
      o.fireActivate()
      discard runMainThreadLoopFor(100)
      check selected == 1
      check expanded == 1
      check collapsed == 1
      check activated == 1

  suite "table rich cells":
    test "checkbox cells round trip":
      let t = newTableView()
      defer:
        destroy(t)
      discard t.addColumn("Done", kind = tckCheck)
      discard t.addColumn("Name")
      t.setRows(@[@["", "task a"], @["", "task b"]])
      check not t.isCellChecked(0, 0)
      t.setCellChecked(0, 0, true)
      check t.isCellChecked(0, 0)
      check naTableIsCellChecked(t.native, 0, 0)
      t.setCellChecked(0, 0, false)
      check not t.isCellChecked(0, 0)

    test "image cells hold and release":
      let t = newTableView()
      defer:
        destroy(t)
      discard t.addColumn("Icon", kind = tckImage)
      t.setRows(@[@[""], @[""]])
      let img = fromBase64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRUlErkJggg==")
      check not img.isNil
      t.setCellImage(0, 0, img)
      t.setCellImage(0, 0, nil)
      t.setCellImage(1, 0, img)

    test "per-row heights":
      let t = newTableView()
      defer:
        destroy(t)
      discard t.addColumn("A")
      t.setRows(@[@["r0"], @["r1"], @["r2"]])
      t.setRowHeight(1, 48.0)
      t.setRowHeights(@[(0, 32.0), (2, 64.0)])
      t.setRowHeights(@[(99, 10.0)])
      t.clearRowHeights()
      t.setRowHeight(20.0)

    test "check events carry state":
      let t = newTableView()
      defer:
        destroy(t)
      discard t.addColumn("Done", kind = tckCheck)
      t.setRows(@[@[""]])
      var row = -1
      var col = -1
      var checked = false
      discard t.onCheck(proc(e: TableCheckEvent) =
        row = e.row
        col = e.column
        checked = e.checked)
      t.fireCheck(0, 0, true)
      discard runMainThreadLoopFor(100)
      check (row, col, checked) == (0, 0, true)
      check t.isCellChecked(0, 0)

    test "edit events carry text and sync the mirror":
      let t = newTableView()
      defer:
        destroy(t)
      discard t.addColumn("Name")
      t.setRows(@[@["old"]])
      t.setColumnEditable(0, true)
      var got = ""
      discard t.onEdit(proc(e: TableEditEvent) =
        check e.row == 0
        check e.column == 0
        got = e.text)
      t.fireEdit(0, 0, "new")
      discard runMainThreadLoopFor(100)
      check got == "new"
      check t.getRows()[0][0] == "new"
      check t.getCellText(0, 0) == "new"

  suite "outline rich cells":
    test "checkbox image heights":
      let o = newOutlineView()
      defer:
        destroy(o)
      discard o.addColumn("Name")
      discard o.addColumn("Done", kind = tckCheck)
      discard o.addColumn("Icon", kind = tckImage)
      o.setNodes(@[(1'u64, 0'u64, true), (2'u64, 1'u64, false)])
      o.setRowTexts(1, @["Inbox", "", ""])
      o.setRowTexts(2, @["Drafts", "", ""])
      check not o.isCellChecked(2, 1)
      o.setCellChecked(2, 1, true)
      check o.isCellChecked(2, 1)
      let img = fromBase64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRUlErkJggg==")
      check not img.isNil
      o.setCellImage(2, 2, img)
      o.setCellImage(2, 2, nil)
      o.setRowHeight(28.0)
      o.setRowHeight(2, 40.0)
      o.setRowHeights(@[(1'u64, 36.0)])
      o.clearRowHeights()
      o.setColumnEditable(0, true)

    test "check and edit events route":
      let o = newOutlineView()
      defer:
        destroy(o)
      discard o.addColumn("Name")
      discard o.addColumn("Done", kind = tckCheck)
      o.setNodes(@[(1'u64, 0'u64, false)])
      o.setRowTexts(1, @["Inbox", ""])
      var checkedKey: uint64 = 0
      var checked = false
      var edited = ""
      discard o.onCheck(proc(e: OutlineCheckEvent) =
        checkedKey = e.key
        checked = e.checked)
      discard o.onEdit(proc(e: OutlineEditEvent) =
        edited = e.text)
      o.fireCheck(1, 1, true)
      o.fireEdit(1, 0, "Renamed")
      discard runMainThreadLoopFor(100)
      check checkedKey == 1
      check checked
      check o.isCellChecked(1, 1)
      check edited == "Renamed"
      check o.getCellText(1, 0) == "Renamed"

  suite "outline lazy loading":
    test "pending mark makes leaves expandable":
      let o = newOutlineView()
      defer:
        destroy(o)
      discard o.addColumn("Name")
      o.setNodes(@[(1'u64, 0'u64, false)])
      o.setExpanded(1, true)
      check not o.isExpanded(1)
      o.setPendingMore(1)
      check o.hasPendingMore(1)
      o.setExpanded(1, true)
      check o.isExpanded(1)
      check o.hasPendingMore(1)

    test "appendChildren keeps parent open and clears mark":
      let o = newOutlineView()
      defer:
        destroy(o)
      discard o.addColumn("Name")
      o.setNodes(@[(1'u64, 0'u64, false)])
      o.setPendingMore(1)
      var gotKey: uint64 = 0
      discard o.onExpand(proc(e: OutlineExpandEvent) =
        if e.key == 1 and o.hasPendingMore(1):
          o.appendChildren(1, @[(2'u64, 1'u64, false)])
          o.setRowTexts(2, @["lazy child"])
        gotKey = e.key)
      o.fireExpand(1)
      discard runMainThreadLoopFor(100)
      check gotKey == 1
      check not o.hasPendingMore(1)
      check o.isExpanded(1)
      check o.nodeCount() == 2
      check o.getCellText(2, 0) == "lazy child"
      o.clearPendingMore(1)

  suite "table drag and drop":
    test "flags round trip":
      let t = newTableView()
      defer:
        destroy(t)
      check not t.isReorderable()
      check not t.acceptsFiles()
      t.setReorderable(true)
      t.setAcceptsFiles(true)
      check t.isReorderable()
      check t.acceptsFiles()
      t.setReorderable(false)
      check not t.isReorderable()

    test "reorder event with sources":
      let t = newTableView()
      defer:
        destroy(t)
      discard t.addColumn("A")
      t.setRows(@[@["a"], @["b"], @["c"], @["d"]])
      t.setReorderable(true)
      var target = -1
      discard t.onReorder(proc(e: TableReorderEvent) =
        target = e.targetRow
        let src = t.getDropSources()
        var rows = t.getRows()
        var moving: seq[seq[string]] = @[]
        for s in src:
          moving.add(rows[s])
        for s in src:
          rows[s] = @[]
        rows = rows.filterIt(it.len > 0)
        let at = min(target, rows.len)
        rows.insert(moving, at)
        t.setRows(rows))
      t.fireReorder(3, [0, 1])
      discard runMainThreadLoopFor(100)
      check target == 3
      check t.getRows() == @[@["c"], @["d"], @["a"], @["b"]]

    test "file drop event with paths":
      let t = newTableView()
      defer:
        destroy(t)
      discard t.addColumn("A")
      t.setRows(@[@["a"]])
      t.setAcceptsFiles(true)
      var target = -1
      var got: seq[string] = @[]
      discard t.onFileDrop(proc(e: TableFileDropEvent) =
        target = e.targetRow
        got = t.getDropFiles())
      t.fireFileDrop(0, ["/tmp/a.txt", "/tmp/b.txt"])
      discard runMainThreadLoopFor(100)
      check target == 0
      check got == @["/tmp/a.txt", "/tmp/b.txt"]

  suite "outline drag and drop":
    test "flags round trip":
      let o = newOutlineView()
      defer:
        destroy(o)
      check not o.acceptsMoves()
      check not o.acceptsFiles()
      o.setAcceptsMoves(true)
      o.setAcceptsFiles(true)
      check o.acceptsMoves()
      check o.acceptsFiles()

    test "move event re-parents nodes":
      let o = newOutlineView()
      defer:
        destroy(o)
      discard o.addColumn("Name")
      o.setNodes(@[(1'u64, 0'u64, true), (2'u64, 1'u64, false),
                   (3'u64, 0'u64, false)])
      for k in [1'u64, 2, 3]:
        o.setRowTexts(k, @["n" & $k])
      o.setAcceptsMoves(true)
      discard o.onMove(proc(e: OutlineMoveEvent) =
        let keys = o.getDropKeys()
        var nodes = o.getNodes()
        for k in keys:
          for i in 0 ..< nodes.len:
            if nodes[i].key == k:
              nodes[i].parent = e.parent
        o.setNodes(nodes))
      o.fireMove(3, 0, [2'u64])
      discard runMainThreadLoopFor(100)
      check o.getDropKeys() == @[2'u64]
      var parentOf2: uint64 = 0
      for n in o.getNodes():
        if n.key == 2:
          parentOf2 = n.parent
      check parentOf2 == 3

    test "file drop event with paths":
      let o = newOutlineView()
      defer:
        destroy(o)
      discard o.addColumn("Name")
      o.setNodes(@[(1'u64, 0'u64, false)])
      o.setAcceptsFiles(true)
      var parent: uint64 = 0
      var idx = -1
      var got: seq[string] = @[]
      discard o.onFileDrop(proc(e: OutlineFileDropEvent) =
        parent = e.parent
        idx = e.index
        got = o.getDropFiles())
      o.fireFileDrop(1, 0, ["/tmp/x.txt"])
      discard runMainThreadLoopFor(100)
      check parent == 1
      check idx == 0
      check got == @["/tmp/x.txt"]

  suite "table filter":
    test "set and clear filter":
      let t = newTableView()
      defer:
        destroy(t)
      discard t.addColumn("From")
      discard t.addColumn("Subject")
      t.setRows(@[@["ada@x", "borrow checker"], @["grace@x", "pipelines"],
                   @["alan@x", "halting problem"]])
      check not t.isFiltered()
      t.setFilter("ada")
      check t.isFiltered()
      check t.getFilter() == "ada"
      check t.rowCount() == 1
      check t.getRows() == @[@["ada@x", "borrow checker"]]
      check naTableRowCount(t.native) == 1
      t.clearFilter()
      check not t.isFiltered()
      check t.rowCount() == 3

    test "filter is case-insensitive and column scoped":
      let t = newTableView()
      defer:
        destroy(t)
      discard t.addColumn("From")
      discard t.addColumn("Subject")
      t.setRows(@[@["ADA@x", "hello"], @["bob@x", "ADA lore"]])
      t.setFilter("ada")
      check t.rowCount() == 2
      t.setFilter("ada", [1])
      check t.rowCount() == 1
      check t.getRows()[0][0] == "bob@x"
      t.setFilter("ada", caseSensitive = true)
      check t.rowCount() == 0
      t.setFilter("ADA", caseSensitive = true)
      check t.rowCount() == 2
      t.setFilter("zzz")
      check t.rowCount() == 0
      check naTableRowCount(t.native) == 0
      t.clearFilter()
      check t.rowCount() == 2

    test "setRows clears the filter":
      let t = newTableView()
      defer:
        destroy(t)
      discard t.addColumn("A")
      t.setRows(@[@["a"], @["b"]])
      t.setFilter("a")
      check t.rowCount() == 1
      t.setRows(@[@["c"], @["d"]])
      check not t.isFiltered()
      check t.rowCount() == 2

  suite "table sugar":
    test "constructors and node wiring":
      let tn = table(["From", "Subject"],
                     @[@["a@x", "hi"], @["b@x", "yo"]], allowMultiple = true)
      let t = TableView(tn.view)
      defer:
        destroy(t)
      check t.columnCount() == 2
      check t.rowCount() == 2
      check t.allowsMultiple()
      var sorts = 0
      discard onTableSort(tn, proc(e: TableSortEvent) = inc sorts)
      discard onTableSelection(tn, proc(e: TableSelectionEvent) = discard)
      discard onTableActivate(tn, proc(e: TableActivateEvent) = discard)
      t.fireSort(0)
      discard runMainThreadLoopFor(100)
      check sorts == 1
      let onode = outline(["Name", "Unread"])
      let o = OutlineView(onode.view)
      defer:
        destroy(o)
      check o.columnCount() == 2
      var expands = 0
      discard onOutlineExpand(onode, proc(e: OutlineExpandEvent) =
        expands = int(e.key))
      discard onOutlineSelection(onode, proc(e: OutlineSelectionEvent) =
        discard)
      discard onOutlineCollapse(onode, proc(e: OutlineCollapseEvent) =
        discard)
      discard onOutlineActivate(onode, proc(e: OutlineActivateEvent) =
        discard)
      o.setNodes(@[(7'u64, 0'u64, false)])
      o.fireExpand(7)
      discard runMainThreadLoopFor(100)
      check expands == 7
