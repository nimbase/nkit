import unittest
import std/times
import nkit
import nkit/gui/view
import nkit/gui/button
import nkit/gui/label
import nkit/gui/separator
import nkit/gui/input
import nkit/gui/textarea
import nkit/gui/switch_widget
import nkit/gui/slider
import nkit/gui/progress
import nkit/gui/segmented
import nkit/gui/select
import nkit/gui/datepicker
import nkit/gui/imageview

suite "button":
  test "title and state round trips":
    let b = newButton("Save", bsPush)
    defer:
      destroy(b)
    check b.style == bsPush
    check getTitle(b) == "Save"
    setTitle(b, "Open")
    check getTitle(b) == "Open"
    setState(b, csOn)
    check getState(b) == csOn
    setState(b, csOff)
    check getState(b) == csOff

  test "click event routes through native target":
    let b = newButton()
    var clicks = 0
    discard onClick(b, proc(e: ButtonClickEvent) =
      inc clicks
      check e.buttonId == b.id)
    fireClick(b)
    discard runMainThreadLoopFor(100)
    check clicks == 1

  test "toggle style preserves independent instances":
    let b1 = newButton("One", bsToggle)
    let b2 = newButton("Two", bsToggle)
    defer:
      destroy(b1)
      destroy(b2)
    setState(b1, csOn)
    setState(b2, csOff)
    check getState(b1) == csOn
    check getState(b2) == csOff

suite "label":
  test "text and styling round trips":
    let l = newLabel("Hello")
    defer:
      destroy(l)
    check getText(l) == "Hello"
    setText(l, "World")
    check getText(l) == "World"
    setFontSize(l, 14.0)
    setFontWeight(l, fwBold)
    setAlignment(l, laCenter)
    setWraps(l, true, maxLines = 2)

suite "separator":
  test "orientation and thickness":
    let s = newSeparator(soHorizontal)
    defer:
      destroy(s)
    let v = newSeparator(soVertical)
    defer:
      destroy(v)
    setThickness(s, 2.0)
    let f = getFrameRect(s)
    check abs(f.height - 2.0) < 0.01

suite "input":
  test "text placeholder editable round trips":
    let i = newInput("Type here", istSingleLine)
    defer:
      destroy(i)
    check i.style == istSingleLine
    check getPlaceholder(i) == "Type here"
    setPlaceholder(i, "Search...")
    check getPlaceholder(i) == "Search..."
    check getText(i) == ""
    setText(i, "hello world")
    check getText(i) == "hello world"
    check isEditable(i)
    setEditable(i, false)
    check not isEditable(i)

  test "change event fires via native path":
    let i = newInput()
    var changes = 0
    discard onChanged(i, proc(e: InputChangedEvent) =
      inc changes
      check e.inputId == i.id)
    fireChange(i)
    discard runMainThreadLoopFor(100)
    check changes == 1

  test "secure field hides text natively":
    let pw = newPasswordField("Password")
    defer:
      destroy(pw)
    check pw.style == istSecure

suite "textarea":
  test "text round trip and editability":
    let ta = newTextArea("first line")
    defer:
      destroy(ta)
    check getText(ta) == "first line"
    setText(ta, "line one\nline two\nline three")
    check getText(ta) == "line one\nline two\nline three"
    check isEditable(ta)
    setEditable(ta, false)
    check not isEditable(ta)

  test "change event fires":
    let ta = newTextArea()
    var changes = 0
    discard onChanged(ta, proc(e: TextAreaChangedEvent) =
      inc changes)
    fireChange(ta)
    discard runMainThreadLoopFor(100)
    check changes == 1

suite "switch":
  test "state toggles":
    let sw = newSwitch(false)
    defer:
      destroy(sw)
    check getState(sw) == false
    setState(sw, true)
    check getState(sw) == true

  test "toggled event carries new state":
    let sw = newSwitch(false)
    var events = 0
    discard onToggled(sw, proc(e: SwitchToggledEvent) =
      inc events
      check e.isOn == getState(sw))
    setState(sw, true)
    fireToggle(sw)
    discard runMainThreadLoopFor(100)
    check events == 1

suite "slider":
  test "range and value round trips":
    let s = newSlider(0.0, 50.0, 25.0)
    defer:
      destroy(s)
    check getMinValue(s) == 0.0
    check getMaxValue(s) == 50.0
    check abs(getValue(s) - 25.0) < 0.01
    setValue(s, 40.0)
    check abs(getValue(s) - 40.0) < 0.01
    setRange(s, 10.0, 20.0)
    check getMinValue(s) == 10.0

suite "progress":
  test "bar value and determinate mode":
    let p = newProgress(psBar, value = 30.0)
    defer:
      destroy(p)
    check not isIndeterminate(p)
    check abs(getValue(p) - 30.0) < 0.01
    setValue(p, 75.0)
    check abs(getValue(p) - 75.0) < 0.01

  test "spinner is indeterminate by default":
    let sp = newProgress(psSpinner)
    defer:
      destroy(sp)
    check isIndeterminate(sp)

suite "segmented control":
  test "labels selection round trip":
    let sc = newSegmented(["Day", "Week", "Month"])
    defer:
      destroy(sc)
    check count(sc) == 3
    check getSelectedIndex(sc) == 0
    selectIndex(sc, 2)
    check getSelectedIndex(sc) == 2
    setLabels(sc, ["A", "B"])
    check count(sc) == 2

  test "select event carries index":
    let sc = newSegmented(["One", "Two"])
    var selected = -1
    discard onSelect(sc, proc(e: SegmentedSelectEvent) =
      selected = e.index)
    selectIndex(sc, 1)
    fireSelect(sc)
    discard runMainThreadLoopFor(100)
    check selected == 1

suite "select popup":
  test "items and selection":
    let sel = newSelect(["Apple", "Banana", "Cherry"])
    defer:
      destroy(sel)
    check count(sel) == 3
    check getSelectedIndex(sel) == -1 or getSelectedIndex(sel) == 0
    chooseIndex(sel, 1)
    check getSelectedIndex(sel) == 1
    check getSelectedTitle(sel) == "Banana"
    addItem(sel, "Durian")
    check count(sel) == 4
    clearItems(sel)
    check count(sel) == 0

suite "datepicker":
  test "unix seconds round trip":
    let dp = newDatePicker(dpsTextField)
    defer:
      destroy(dp)
    let nowSeconds = getTime().toUnixFloat()
    setUnixSeconds(dp, nowSeconds)
    let got = getUnixSeconds(dp)
    check abs(got - nowSeconds) < 2.0

suite "image view":
  test "symbol image assignment":
    let iv = newImageView()
    defer:
      destroy(iv)
    setSymbol(iv, "square.and.pencil", pointSize = 20.0, weight = 4)
    clearImage(iv)
    let img = fromBase64(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")
    setImage(iv, img)
    setScaling(iv, ivsFit)
