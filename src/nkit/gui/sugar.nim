## Flutter-style sugar layer. Every public proc returns a `ViewNode` ready to
## drop into `row()`/`column()` trees, or wires events on existing nodes.
## Constructor-first: common properties are optional params, not chainable
## setters.
import nkit/foundation/event_emitter
import nkit/gui/layout
import nkit/gui/theme
import nkit/alert
import nkit/gui/popover
import nkit/gui/split_view
import nkit/gui/toolbar
import nkit/gui/animate
import nkit/gui/label
import nkit/gui/button
import nkit/gui/input
import nkit/gui/textarea
import nkit/gui/switch_widget
import nkit/gui/slider
import nkit/gui/progress
import nkit/gui/segmented
import nkit/gui/select
import nkit/gui/imageview
import nkit/gui/badge
import nkit/gui/avatar
import nkit/gui/separator
import nkit/gui/datepicker
import nkit/gui/scroll
import nkit/gui/card
import nkit/gui/tabs
import nkit/gui/sidebar
import nkit/gui/toast
import nkit/gui/accordion
import nkit/gui/stack
import nkit/gui/router

export layout, theme, label, button, input, textarea, switch_widget, slider,
       progress, segmented, select, imageview, badge, avatar, separator,
       alert, popover, split_view, toolbar, animate,
       datepicker, scroll, card, tabs, sidebar, toast, accordion, stack,
       router

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

proc toNode(v: View): ViewNode =
  ViewNode(v)

# ---------------------------------------------------------------------------
# Alert shorthands
# ---------------------------------------------------------------------------

proc alert*(title: string, message = "", style: AlertStyle = asInfo): AlertDialog =
  ## Shorthand for `newAlertDialog`.
  newAlertDialog(title, message, style)

proc showAlert*(title: string, message = "",
                style: AlertStyle = asInfo): AlertDialog =
  ## Creates an alert ready for fluent `.addButton().open()`.
  alert(title, message, style)

# ---------------------------------------------------------------------------
# Text constructors
# ---------------------------------------------------------------------------

proc text*(value: string): ViewNode =
  ## A plain text label.
  toNode(newLabel(value))

proc text*(value: string, size: float64): ViewNode =
  ## A text label with a custom font size.
  let l = newLabel(value)
  l.setFontSize(size)
  toNode(l)

proc text*(value: string, size: float64, weight: FontWeight): ViewNode =
  ## A text label with a custom font size and weight.
  let l = newLabel(value)
  l.setFontSize(size)
  l.setFontWeight(weight)
  toNode(l)

proc text*(value: string, size: float64, weight: FontWeight,
           color: Color): ViewNode =
  ## A text label with size, weight, and color.
  let l = newLabel(value)
  l.setFontSize(size)
  l.setFontWeight(weight)
  l.setTextColor(color)
  toNode(l)

proc h1*(value: string, color = labelColor()): ViewNode =
  ## Heading 1: 26pt bold.
  let l = newLabel(value)
  l.setFontSize(26.0)
  l.setFontWeight(fwBold)
  l.setTextColor(color)
  toNode(l)

proc h2*(value: string, color = labelColor()): ViewNode =
  ## Heading 2: 20pt semibold.
  let l = newLabel(value)
  l.setFontSize(20.0)
  l.setFontWeight(fwSemibold)
  l.setTextColor(color)
  toNode(l)

proc p*(value: string, color = secondaryLabelColor()): ViewNode =
  ## Body text in secondary label color.
  let l = newLabel(value)
  l.setTextColor(color)
  toNode(l)

# ---------------------------------------------------------------------------
# Button constructors
# ---------------------------------------------------------------------------

proc button*(title: string, style: ButtonStyle = bsPush): ViewNode =
  ## A push button (default), toggle, or other style.
  toNode(newButton(title, style))

proc button*(title: string, style: ButtonStyle, isEnabled: bool): ViewNode =
  ## A button with explicit enabled state.
  let b = newButton(title, style)
  setEnabled(b, isEnabled)
  toNode(b)

proc button*(title: string, onTap: proc(e: ButtonClickEvent)): ViewNode =
  ## A push button with a click handler wired at construction time.
  result = toNode(newButton(title, bsPush))
  onClick(Button(result.view), onTap)

proc checkbox*(title: string, isOn = false): ViewNode =
  ## A checkbox; `isOn` sets the initial state.
  toNode(newButton(title, bsCheckBox))

proc checkbox*(title: string, isOn: bool, isEnabled: bool): ViewNode =
  ## A checkbox with explicit enabled state.
  let b = newButton(title, bsCheckBox)
  setEnabled(b, isEnabled)
  toNode(b)

proc radio*(title: string, isOn = false): ViewNode =
  ## A radio button; `isOn` sets the initial state.
  toNode(newButton(title, bsRadio))

proc radio*(title: string, isOn: bool, isEnabled: bool): ViewNode =
  ## A radio button with explicit enabled state.
  let b = newButton(title, bsRadio)
  setEnabled(b, isEnabled)
  toNode(b)

# ---------------------------------------------------------------------------
# Text input constructors
# ---------------------------------------------------------------------------

proc input*(placeholder = "", isEditable = true): ViewNode =
  ## A single-line text field.
  let inp = newInput(placeholder)
  setEditable(inp, isEditable)
  toNode(inp)

proc password*(placeholder = "", isEditable = true): ViewNode =
  ## A password field (hidden text).
  let inp = newPasswordField(placeholder)
  setEditable(inp, isEditable)
  toNode(inp)

proc search*(placeholder = "", isEditable = true): ViewNode =
  ## A search field with magnifying glass icon.
  let inp = newSearchField(placeholder)
  setEditable(inp, isEditable)
  toNode(inp)

proc textarea*(placeholder = "", height = 90.0,
               isEditable = true): ViewNode =
  ## A multi-line text area.
  let ta = newTextArea(placeholder)
  constrainSize(ta, 0.0, height)
  setEditable(ta, isEditable)
  toNode(ta)

# ---------------------------------------------------------------------------
# Switch, slider, progress
# ---------------------------------------------------------------------------

proc `switch`*(isOn = false): ViewNode =
  ## A toggle switch.
  toNode(newSwitch(isOn))

proc slider*(value = 50.0, low = 0.0, high = 100.0): ViewNode =
  ## A horizontal slider.
  toNode(newSlider(low, high, value))

proc bar*(value = 0.0): ViewNode =
  ## A horizontal progress bar.
  toNode(newProgress(psBar, value = value))

proc spinner*(): ViewNode =
  ## An indeterminate spinning progress indicator.
  toNode(newProgress(psSpinner))

# ---------------------------------------------------------------------------
# Selection controls
# ---------------------------------------------------------------------------

proc segmented*(labels: openArray[string], selected = 0): ViewNode =
  ## A segmented control with `labels`; `selected` highlights one.
  let sc = newSegmented(labels)
  selectIndex(sc, selected)
  toNode(sc)

proc pick*(items: openArray[string]): ViewNode =
  ## A dropdown (NSPopUpButton) populated with `items`.
  toNode(newSelect(items))

# ---------------------------------------------------------------------------
# Decoration
# ---------------------------------------------------------------------------

proc icon*(symbolName: string, pointSize = 16.0, weight = 2): ViewNode =
  ## An SF Symbol icon. `weight` maps to NSFont weight (2 = regular).
  let iv = newImageView()
  iv.setSymbol(symbolName, pointSize)
  toNode(iv)

proc chip*(textValue: string, variant: BadgeVariant = bvDefault): ViewNode =
  ## A small badge / chip.
  toNode(newBadge(textValue, variant))

proc avatar*(name: string, size: AvatarSize = asMedium): ViewNode =
  ## A circular avatar showing the first two characters of `name`.
  let av = newAvatar(size)
  av.setInitials(name)
  toNode(av)

proc divider*(orientation: SeparatorOrientation = soHorizontal,
              thickness = 1.0): ViewNode =
  ## A thin separator line.
  let sep = newSeparator(orientation)
  sep.setThickness(thickness)
  sep.setContentHugging(1, 750.0)
  toNode(sep)

# ---------------------------------------------------------------------------
# Date picker
# ---------------------------------------------------------------------------

proc datePicker*(unixSeconds = 0.0): ViewNode =
  ## A date picker in text-field style.
  let dp = newDatePicker(dpsTextField)
  if unixSeconds > 0.0:
    setUnixSeconds(dp, unixSeconds)
  toNode(dp)

proc datePicker*(style: DatePickerStyle, unixSeconds = 0.0): ViewNode =
  ## A date picker with an explicit style.
  let dp = newDatePicker(style)
  if unixSeconds > 0.0:
    setUnixSeconds(dp, unixSeconds)
  toNode(dp)

# ---------------------------------------------------------------------------
# Scroll
# ---------------------------------------------------------------------------

proc scroll*(child: ViewNode): ViewNode =
  ## Wraps `child` in a vertical scroll view.
  let sc = newScroll()
  setDocument(sc, child.view)
  fitWidth(sc)
  toNode(sc)

proc scroll*(child: ViewNode, vertical: bool,
             horizontal: bool): ViewNode =
  ## Wraps `child` in a scroll view with explicit axis toggles.
  let sc = newScroll()
  setDocument(sc, child.view)
  setHasVerticalBar(sc, vertical)
  setHasHorizontalBar(sc, horizontal)
  if vertical and not horizontal:
    fitWidth(sc)
  toNode(sc)

# ---------------------------------------------------------------------------
# Card
# ---------------------------------------------------------------------------

proc card*(title: string, description: string,
           children: varargs[ViewNode]): ViewNode =
  ## A card with title, description, and body children.
  let c = newCard(title, description)
  for child in children:
    addToContent(c, child.view)
  toNode(c)

proc card*(title: string, children: varargs[ViewNode]): ViewNode =
  ## A card with title only.
  let c = newCard(title)
  for child in children:
    addToContent(c, child.view)
  toNode(c)

proc card*(children: varargs[ViewNode]): ViewNode =
  ## A bare card with no header.
  let c = newCard()
  for child in children:
    addToContent(c, child.view)
  toNode(c)

# ---------------------------------------------------------------------------
# Tabs
# ---------------------------------------------------------------------------

proc tabs*(labels: openArray[string]): ViewNode =
  ## A tab bar with labels; content pages added later via `addPage`.
  toNode(newTabs(labels))

proc tabs*(pages: openArray[tuple[label: string,
            child: ViewNode]]): ViewNode =
  ## A tab bar where each entry pairs a label with a content view.
  var labels = newSeq[string](pages.len)
  for i, p in pages:
    labels[i] = p.label
  let t = newTabs(labels)
  for i, p in pages:
    addPage(t, i, p.child.view, showNow = (i == 0))
  toNode(t)

# ---------------------------------------------------------------------------
# Sidebar
# ---------------------------------------------------------------------------

proc sidebar*(items: openArray[string]): ViewNode =
  ## A sidebar listing `items`; selection tracked internally.
  let sb = newSidebar()
  for item in items:
    discard addItem(sb, item)
  toNode(sb)

proc sidebar*(items: openArray[string],
              onSelectItem: proc(idx: int)): ViewNode =
  ## A sidebar with a selection callback.
  let sb = newSidebar()
  for item in items:
    discard addItem(sb, item)
  onSelect(sb, proc(e: SidebarSelectEvent) = onSelectItem(e.itemIndex))
  toNode(sb)

# ---------------------------------------------------------------------------
# Toast
# ---------------------------------------------------------------------------

proc showToast*(title, message: string,
                durationMs = 4000.0): uint32 =
  ## Fires a floating toast in the bottom-right corner. Returns a toast ID.
  show(sharedToastManager(), title, message, durationMs)

# ---------------------------------------------------------------------------
# Accordion
# ---------------------------------------------------------------------------

type
  AccordionEntryData* = tuple[title: string, content: ViewNode,
                              contentHeight: float64]

proc accordionItem*(title: string, content: ViewNode,
                    contentHeight = 0.0): AccordionEntryData =
  ## Builds a single accordion entry for use with `accordion`.
  (title, content, contentHeight)

proc accordion*(items: varargs[AccordionEntryData],
                singleOpen = true): ViewNode =
  ## An accordion populated from `accordionItem` entries.
  let acc = newAccordion(singleOpen)
  for item in items:
    discard addItem(acc, item.title, item.content.view, item.contentHeight)
  toNode(acc)

proc accordion*(titles: openArray[string],
                contents: openArray[ViewNode],
                singleOpen = true): ViewNode =
  ## An accordion with paired titles and content views.
  doAssert titles.len == contents.len,
    "accordion: titles and contents must have the same length"
  let acc = newAccordion(singleOpen)
  for i in 0 ..< titles.len:
    discard addItem(acc, titles[i], contents[i].view)
  toNode(acc)

# ---------------------------------------------------------------------------
# Popover
# ---------------------------------------------------------------------------

proc showPopover*(child: ViewNode,
                  sz: Size = size(240.0, 130.0),
                  background: Color = controlBackgroundColor()): proc(e: ButtonClickEvent) =
  ## Returns an onClick handler that toggles a popover anchored to the
  ## button that was pressed.
  var pop: Popover = nil
  return proc(e: ButtonClickEvent) =
    if not pop.isNil and pop.isShown():
      pop.close()
      return
    if not pop.isNil:
      pop.destroy()
    pop = newPopover(sz.width, sz.height)
    setBackgroundColor(pop, background)
    let anchor = findView(e.buttonId.uint32)
    addSubview(pop, child.view)
    fillParent(child.view, left = 16.0, top = 16.0, right = 16.0, bottom = 16.0)
    if not anchor.isNil:
      pop.show(anchor, peBottom)

# ---------------------------------------------------------------------------
# Event wiring on ViewNode (resolved by handler event type)
# ---------------------------------------------------------------------------

proc onClick*(n: ViewNode,
              handler: proc(e: ButtonClickEvent)): ListenerId {.discardable.} =
  ## Wires a click handler on a Button node.
  doAssert n.view of Button, "onClick target is not a button"
  onClick(Button(n.view), handler)

proc onToggled*(n: ViewNode,
                handler: proc(e: SwitchToggledEvent)): ListenerId {.discardable.} =
  ## Wires a toggle handler on a SwitchWidget node.
  doAssert n.view of SwitchWidget, "onToggled target is not a switch"
  onToggled(SwitchWidget(n.view), handler)

proc onChanged*(n: ViewNode,
                handler: proc(e: InputChangedEvent)): ListenerId =
  ## Wires a change handler on an Input node.
  doAssert n.view of Input, "onChanged target is not an input"
  onChanged(Input(n.view), handler)

proc onSubmitted*(n: ViewNode,
                  handler: proc(e: InputSubmittedEvent)): ListenerId =
  ## Wires a submission handler on an Input node.
  doAssert n.view of Input, "onSubmitted target is not an input"
  onSubmitted(Input(n.view), handler)

proc onChanged*(n: ViewNode,
                handler: proc(e: SliderChangedEvent)): ListenerId =
  ## Wires a change handler on a Slider node.
  doAssert n.view of Slider, "onChanged target is not a slider"
  onChanged(Slider(n.view), handler)

proc onChanged*(n: ViewNode,
                handler: proc(e: SelectChangedEvent)): ListenerId =
  ## Wires a change handler on a Select node.
  doAssert n.view of Select, "onChanged target is not a select"
  onChanged(Select(n.view), handler)

proc onChanged*(n: ViewNode,
                handler: proc(e: SegmentedSelectEvent)): ListenerId =
  ## Wires a selection handler on a SegmentedControl node.
  doAssert n.view of SegmentedControl,
    "onChanged target is not a segmented control"
  onSelect(SegmentedControl(n.view), handler)

proc onChanged*(n: ViewNode,
                handler: proc(e: TextAreaChangedEvent)): ListenerId =
  ## Wires a change handler on a TextArea node.
  doAssert n.view of TextArea, "onChanged target is not a textarea"
  onChanged(TextArea(n.view), handler)

proc onChanged*(n: ViewNode,
                handler: proc(e: DateChangedEvent)): ListenerId =
  ## Wires a date-change handler on a DatePicker node.
  doAssert n.view of DatePicker, "onChanged target is not a date picker"
  onDateChanged(DatePicker(n.view), handler)

proc onChanged*(n: ViewNode,
                handler: proc(e: TabChangedEvent)): ListenerId =
  ## Wires a page-change handler on a Tabs node.
  doAssert n.view of Tabs, "onChanged target is not a tabs view"
  onChanged(Tabs(n.view), handler)

proc onSelect*(n: ViewNode,
               handler: proc(e: SidebarSelectEvent)): ListenerId =
  ## Wires a selection handler on a Sidebar node.
  doAssert n.view of Sidebar, "onSelect target is not a sidebar"
  onSelect(Sidebar(n.view), handler)

proc onChanged*(n: ViewNode,
                handler: proc(e: AccordionChangedEvent)): ListenerId =
  ## Wires an expand/collapse handler on an Accordion node.
  doAssert n.view of Accordion, "onChanged target is not an accordion"
  onChanged(Accordion(n.view), handler)

# ---------------------------------------------------------------------------
# Text helpers routed by runtime widget kind
# ---------------------------------------------------------------------------

proc setText*(n: ViewNode, value: string) =
  ## Sets the visible text on Label, Button, Input, TextArea, or Badge.
  let v = n.view
  if v of Label:
    setText(Label(v), value)
  elif v of Button:
    setTitle(Button(v), value)
  elif v of Input:
    setText(Input(v), value)
  elif v of TextArea:
    setText(TextArea(v), value)
  elif v of Badge:
    setText(Badge(v), value)

proc getText*(n: ViewNode): string =
  ## Returns the visible text from Label, Button, Input, or TextArea.
  let v = n.view
  if v of Label:
    getText(Label(v))
  elif v of Button:
    getTitle(Button(v))
  elif v of Input:
    getText(Input(v))
  elif v of TextArea:
    getText(TextArea(v))
  else:
    ""
