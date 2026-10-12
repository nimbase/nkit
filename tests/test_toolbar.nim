import unittest
import nkit
import nkit/gui/toolbar
import nkit/gui/view
import nkit/foundation/dispatcher

suite "toolbar":
  test "attach to a window and register items in order":
    let win = newWindow()
    defer:
      free(win)
    let tb = attachToolbar(win)
    check tb != nil
    var pressed = ""
    discard tb.addItem("New", "plus", proc() = pressed = "new")
    discard tb.addItem("Save", "square.and.arrow.down",
                       proc() = pressed = "save")
    check tb.itemCount() == 2

  test "item callbacks dispatch through the pipeline by ordinal":
    let win = newWindow()
    defer:
      free(win)
    let tb = attachToolbar(win)
    var log: seq[string] = @[]
    discard tb.addItem("One", "", proc() = log.add("one"))
    discard tb.addItem("Two", "star", proc() = log.add("two"))
    fireToolbarItemSimulated(tb, 0)
    fireToolbarItemSimulated(tb, 1)
    check log == @["one", "two"]

  test "multiple toolbars dispatch independently":
    let w1 = newWindow()
    let w2 = newWindow()
    defer:
      free(w1)
      free(w2)
    let t1 = attachToolbar(w1)
    let t2 = attachToolbar(w2)
    var who = ""
    discard t1.addItem("A", "", proc() = who = "t1")
    discard t2.addItem("B", "", proc() = who = "t2")
    fireToolbarItemSimulated(t1, 0)
    check who == "t1"
    fireToolbarItemSimulated(t2, 0)
    check who == "t2"

  test "separators spaces and search append in order":
    let win = newWindow()
    defer:
      free(win)
    let tb = attachToolbar(win)
    let b0 = tb.addItem("Back", "chevron.left", proc() = discard)
    let s1 = tb.addSeparator()
    let f2 = tb.addFlexibleSpace()
    let q3 = tb.addSearch("Filter settings")
    check (b0, s1, f2, q3) == (0, 1, 2, 3)
    check tb.itemCount() == 4

  test "removeItem drops the ordinal and shifts the rest":
    let win = newWindow()
    defer:
      free(win)
    let tb = attachToolbar(win)
    var log: seq[string] = @[]
    discard tb.addItem("One", "", proc() = log.add("one"))
    discard tb.addSeparator()
    discard tb.addItem("Two", "", proc() = log.add("two"))
    check tb.itemCount() == 3
    tb.removeItem(1)
    check tb.itemCount() == 2
    fireToolbarItemSimulated(tb, 0)
    fireToolbarItemSimulated(tb, 1)
    check log == @["one", "two"]
    tb.removeItem(9)
    check tb.itemCount() == 2

  test "tooltip and enabled round trips":
    let win = newWindow()
    defer:
      free(win)
    let tb = attachToolbar(win)
    let o = tb.addItem("Save", "square.and.arrow.down", proc() = discard)
    tb.setItemTooltip(o, "Save the document")
    check tb.getItemTooltip(o) == "Save the document"
    check tb.isItemEnabled(o)
    tb.setItemEnabled(o, false)
    check not tb.isItemEnabled(o)
    tb.setItemEnabled(o, true)
    check tb.isItemEnabled(o)

  test "search events route text and submit flag":
    let win = newWindow()
    defer:
      free(win)
    let tb = attachToolbar(win)
    var seen: seq[tuple[text: string, submitted: bool]] = @[]
    let q = tb.addSearch("Filter", proc(text: string, submitted: bool) =
      seen.add((text, submitted)))
    fireToolbarSearchSimulated(tb, q, "appear", submitted = false)
    fireToolbarSearchSimulated(tb, q, "appearance", submitted = true)
    check seen == @[("appear", false), ("appearance", true)]

  test "display modes and customization are callable":
    let win = newWindow()
    defer:
      free(win)
    let tb = attachToolbar(win)
    discard tb.addItem("A", "", proc() = discard)
    tb.setDisplayMode(tdmIconAndLabel)
    tb.setDisplayMode(tdmIconOnly)
    tb.setSmallSize(true)
    tb.setSmallSize(false)
    tb.setAllowsCustomization(true)
    tb.setAllowsCustomization(false)
    tb.setShowsBaselineSeparator(true)
    tb.setSelectedItem(0)
    tb.clearSelection()
    check tb.itemCount() == 1
