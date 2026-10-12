## Mailbox + file-tree demo: checkbox cells, editable subjects,
## row reorder, live filtering, and a lazily loaded outline node.
## Click headers to sort (shift-click chains), drag rows to reorder,
## expand Archive to lazy-load it, and type in the filter box.
import nkit
import nkit/gui/sugar
import std/sequtils

when defined(macosx):
  import nkit/gui/table
  import nkit/gui/outline

  let app = initApplication()

  let win = newWindow()
  win.setTitle("Tables & Outlines")
  win.setSize(size(900.0, 560.0), false)

  let mail = newTableView(allowMultiple = true)
  discard mail.addColumn("Read", 60.0, sortable = false, kind = tckCheck)
  discard mail.addColumn("From", 170.0)
  discard mail.addColumn("Subject", 280.0)
  discard mail.addColumn("Date", 110.0)
  mail.setRows(@[
    @["", "ada@x", "Borrow checker notes", "09:12"],
    @["", "grace@x", "Compiler pipeline", "08:47"],
    @["", "alan@x", "Halting problem, again", "Yesterday"],
  ])
  mail.setCellChecked(1, 0, true)
  mail.setColumnEditable(2, true)
  mail.setReorderable(true)
  mail.setAcceptsFiles(true)

  let tree = newOutlineView(allowMultiple = true)
  discard tree.addColumn("Name", 190.0)
  discard tree.addColumn("Unread", 70.0)
  discard tree.addColumn("Done", 60.0, kind = tckCheck)
  tree.setNodes(@[(1'u64, 0'u64, true), (2'u64, 1'u64, false),
                  (3'u64, 1'u64, false), (4'u64, 0'u64, false)])
  tree.setRowTexts(1, @["Mailboxes", "45", ""])
  tree.setRowTexts(2, @["Inbox", "42", ""])
  tree.setRowTexts(3, @["Drafts", "3", ""])
  tree.setRowTexts(4, @["Archive", "", ""])
  tree.setPendingMore(4)
  tree.setAcceptsMoves(true)
  tree.setAcceptsFiles(true)

  var status = text("Select a row.")
  let filterBox = input("Filter messages…")

  discard onChanged(filterBox, proc(e: InputChangedEvent) =
    let q = getText(Input(filterBox.view))
    if q.len == 0:
      mail.clearFilter()
    else:
      mail.setFilter(q)
    setText(status, "Filter: '" & q & "' (" & $mail.rowCount() & " rows)"))

  discard mail.onSort(proc(e: TableSortEvent) =
    if e.chain.len > 1:
      mail.sortByChain(e.chain)
    else:
      mail.sortBy(e.column, e.ascending))

  discard mail.onSelection(proc(e: TableSelectionEvent) =
    let sel = mail.getSelectedRows()
    setText(status, "Table: " & $sel.len & " selected"))

  discard mail.onCheck(proc(e: TableCheckEvent) =
    setText(status, "Row " & $e.row & " read=" & $e.checked))

  discard mail.onEdit(proc(e: TableEditEvent) =
    setText(status, "Edited row " & $e.row & ": " & e.text))

  discard mail.onReorder(proc(e: TableReorderEvent) =
    let src = mail.getDropSources()
    var rows = mail.getRows()
    var moving: seq[seq[string]] = @[]
    for s in src:
      moving.add(rows[s])
    var kept: seq[seq[string]] = @[]
    for i, r in rows.pairs:
      if i notin src:
        kept.add(r)
    let at = min(e.targetRow, kept.len)
    kept.insert(moving, at)
    mail.clearFilter()
    mail.setRows(kept)
    setText(status, "Moved " & $src.len & " row(s) to " & $e.targetRow))

  discard mail.onFileDrop(proc(e: TableFileDropEvent) =
    setText(status, "Files onto row " & $e.targetRow & ": " &
      $mail.getDropFiles().len))

  discard tree.onSelection(proc(e: OutlineSelectionEvent) =
    setText(status, "Outline keys: " & $tree.getSelectedKeys()))

  discard tree.onExpand(proc(e: OutlineExpandEvent) =
    if e.key == 4 and tree.hasPendingMore(4):
      tree.appendChildren(4, @[(5'u64, 4'u64, false),
                               (6'u64, 4'u64, false)])
      tree.setRowTexts(5, @["2024", "120", ""])
      tree.setRowTexts(6, @["2025", "300", ""])
      setText(status, "Archive loaded lazily"))

  discard tree.onMove(proc(e: OutlineMoveEvent) =
    let keys = tree.getDropKeys()
    var nodes = tree.getNodes()
    for k in keys:
      for i in 0 ..< nodes.len:
        if nodes[i].key == k:
          nodes[i].parent = e.parent
    tree.setNodes(nodes)
    setText(status, "Moved " & $keys.len & " node(s)"))

  discard tree.onCheck(proc(e: OutlineCheckEvent) =
    setText(status, "Node " & $e.key & " done=" & $e.checked))

  layout(
    padding(
      column(
        h1("Tables & Outlines"),
        filterBox,
        expanded(
          verticalSplitView(
            splitPane(toNode(mail), minWidth = 220.0),
            splitPane(toNode(tree), minWidth = 160.0)
          )
        ),
        status
      ).spacing(12).crossAlign(caStretch),
      all(16.0)
    )
  )

  win.show()
  discard app.run()
else:
  echo "table_demo needs macOS"
