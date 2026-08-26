import unittest
import nkit/alert
import nkit/gui/input
import nkit/gui/layout

suite "alerts v2":
  test "buttons register in order and count matches":
    let alert = newAlertDialog("Delete items", "This cannot be undone",
                               asWarning)
    defer:
      alert.destroy()
    alert.addButton("Cancel")
    alert.addButton("Delete")
    alert.addButton("Delete all")
    check alert.buttonCount() == 3

  test "simulated presses dispatch registered callbacks by ordinal":
    let alert = newAlertDialog("Confirm")
    defer:
      alert.destroy()
    var pressed = ""
    alert.addButton("No", proc(id: AlertID) = pressed = "no")
    alert.addButton("Yes", proc(id: AlertID) = pressed = "yes")
    fireAlertButtonSimulated(alert, 0)
    check pressed == "no"
    fireAlertButtonSimulated(alert, 1)
    check pressed == "yes"

  test "withContent accepts a ViewNode":
    let alert = newAlertDialog("Rename", "Enter a new name")
    defer:
      alert.destroy()
    let nameInput = newInput("untitled layer")
    alert.withContent(ViewNode(nameInput))
    check alert.buttonCount() == 0

  test "styles are preserved":
    let info = newAlertDialog("i", "", asInfo)
    let crit = newAlertDialog("c", "", asCritical)
    defer:
      info.destroy()
      crit.destroy()
    check info.styleValue == asInfo
    check crit.styleValue == asCritical
