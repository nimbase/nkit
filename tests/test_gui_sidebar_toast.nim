import unittest
import nkit
import nkit/gui/view
import nkit/gui/sidebar
import nkit/gui/toast

suite "sidebar":
  test "items, headers, separators accumulate":
    let sb = newSidebar()
    defer:
      destroy(sb)
    discard addSectionHeader(sb, "Platform")
    check addItem(sb, "Home", symbolName = "house") != nil
    check addItem(sb, "Search", symbolName = "magnifyingglass", badgeText = "3") != nil
    addSeparatorLine(sb)
    discard addSectionHeader(sb, "Workspace")
    check addItem(sb, "Settings", symbolName = "gearshape") != nil
    check getItemCount(sb) == 3
    let item = getItem(sb, 1)
    check item.labelText == "Search"
    check not item.badgeValue.isNil
    check getItem(sb, 9).isNil

  test "selection state and event routing":
    let sb = newSidebar()
    defer:
      destroy(sb)
    var selected = -1
    discard onSelect(sb, proc(e: SidebarSelectEvent) =
      selected = e.itemIndex)
    discard addItem(sb, "One")
    discard addItem(sb, "Two")
    discard addItem(sb, "Three")

    fireItemClick(sb, 2)
    discard runMainThreadLoopFor(120)
    check getSelectedIndex(sb) == 2
    check selected == 2
    check naHoverViewIsSelected(getItem(sb, 2).native)
    check not naHoverViewIsSelected(getItem(sb, 0).native)

    fireItemClick(sb, 0)
    discard runMainThreadLoopFor(120)
    check getSelectedIndex(sb) == 0
    check selected == 0

suite "toast":
  test "show queues a toast and dismissal emits event":
    let tm = sharedToastManager()
    var dismissed: seq[uint32]
    discard onDismissed(tm, proc(e: ToastDismissedEvent) =
      dismissed.add(e.toastId))

    let id = tm.show("Saved", "Your changes are live", durationMs = 600.0)
    check id > 0'u32
    discard runMainThreadLoopFor(2000)
    check dismissed.contains(id)

  test "close dismisses immediately":
    let tm = sharedToastManager()
    var closedId = 0'u32
    discard onDismissed(tm, proc(e: ToastDismissedEvent) =
      closedId = e.toastId)
    let id = tm.show("Closing soon", durationMs = 30000.0)
    check activeToasts(tm) >= 1
    tm.close(id)
    discard runMainThreadLoopFor(500)
    check closedId == id
