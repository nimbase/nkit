import nkit/foundation/color
import nkit/foundation/event_emitter
import nkit/gui/view
import nkit/gui/label
import nkit/gui/stack
import nkit/gui/separator
import nkit/gui/theme

export view, label, stack, separator

type
  Card* = ref object of View
    root*: Stack
    headerStack*: Stack
    titleLabel*: Label
    descriptionLabel*: Label
    contentSlot*: Stack
    footerSlot*: View

proc newCard*(title = "", description = "", cornerRadius = 10.0): Card =
  let root = newStack(stVertical, spacing = 0.0)
  root.setPadding(16.0)

  result = Card(root: root)
  discard wrapView(result, root.native)
  setBackgroundColor(result, controlBackgroundColor())
  setCornerRadius(result, cornerRadius)
  setBorder(result, separatorColor(), 1.0)

  var headerSpacing = 4.0
  if title.len > 0 and description.len > 0:
    headerSpacing = 6.0
  let header = newStack(stVertical, spacing = headerSpacing)
  result.headerStack = header

  if title.len > 0:
    let tl = newLabel(title)
    tl.setFontSize(15.0)
    tl.setFontWeight(fwSemibold)
    tl.setTextColor(labelColor())
    result.titleLabel = tl
    addArranged(header, tl)

  if description.len > 0:
    let dl = newLabel(description)
    dl.setFontSize(13.0)
    dl.setTextColor(secondaryLabelColor())
    dl.setWraps(true)
    result.descriptionLabel = dl
    addArranged(header, dl)

  addArranged(root, header)

  if title.len > 0 or description.len > 0:
    let sep = newSeparator(soHorizontal)
    addArranged(root, sep)

  let content = newStack(stVertical, spacing = 8.0)
  setArrangedFill(content, true)
  result.contentSlot = content
  addArranged(root, View(content))

proc destroy*(c: Card) =
  freeNative(c)
  shutdownEmitter[GuiEvent](c)

proc addToContent*(c: Card, child: View) =
  ## Appends a row to the card body. Multiple children stack vertically.
  addArranged(c.contentSlot, child)

proc addToFooter*(c: Card, child: View) =
  if c.footerSlot.isNil:
    let footer = newPlainView()
    c.footerSlot = footer
    addArranged(c.root, footer)
  addSubview(c.footerSlot, child)
  fillParent(child)
