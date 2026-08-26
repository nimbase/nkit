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
