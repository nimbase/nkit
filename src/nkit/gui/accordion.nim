import nkit/foundation/id_allocator
import nkit/foundation/event
import nkit/foundation/event_emitter
import nkit/gui/view
import nkit/gui/stack
import nkit/gui/label
import nkit/gui/theme
import nkit/gui/hover_router
when defined(ios):
  import nkit/platform/ios/uifunctions
elif defined(macosx):
  import nkit/platform/macos/nsfunctions

export view, stack

type
  AccordionChangedEvent* = ref object of GuiEvent
    accordionId*: Id
    itemIndex*: int
    isExpanded*: bool

  AccordionItem* = ref object of View
    ## Header row of one accordion section (hover-highlighted, clickable).
    labelText*: string
    chevronLabel*: Label
    titleLabel*: Label

  AccordionEntry = object
    header: AccordionItem
    body: View
    expanded: bool
    fixedHeight: float64

  Accordion* = ref object of View
    root*: Stack
    singleOpenValue*: bool
    items: seq[AccordionEntry]

method typeName(e: AccordionChangedEvent): string = "AccordionChangedEvent"

proc newAccordionChangedEvent*(accordionId: Id, itemIndex: int,
                               isExpanded: bool): AccordionChangedEvent =
  result = AccordionChangedEvent(accordionId: accordionId, itemIndex: itemIndex,
                                 isExpanded: isExpanded)
  discard stamp(result)

const chevronCollapsed* = "\u25B8"
const chevronExpanded* = "\u25BE"

proc setChevron(item: AccordionItem, expanded: bool) =
  setText(item.chevronLabel, if expanded: chevronExpanded else: chevronCollapsed)

proc newAccordion*(singleOpen = true): Accordion =
  ensureHoverRouter()
  let vid = allocate(typeTagGuiWidget)
  result = Accordion(singleOpenValue: singleOpen)
  let base = newPlainView()
  discard wrapView(result, base.native, vid)

  when defined(macosx) or defined(ios):
    let root = newStack(stVertical, spacing = 4.0)
    result.root = root
    addSubview(result, View(root))
    fillParent(View(root))

proc setExpanded*(acc: Accordion, index: int, expanded: bool)

proc addItem*(acc: Accordion, title: string, contentView: View,
              contentHeight = 0.0): int =
  ## Appends a section. contentHeight of 0 auto-measures the content's
  ## fitting size; pass an explicit height for scrollable or dynamic bodies.
  let headerVid = allocate(typeTagGuiWidget)
  when defined(macosx) and not defined(ios):
    let hoverPtr = naHoverViewCreate(headerVid.uint32)
  else:
    let hoverPtr: pointer = nil

  let index = acc.items.len
  let header = AccordionItem(labelText: title)
  discard wrapView(header, hoverPtr, headerVid)

  var entry = AccordionEntry(header: header, body: nil, expanded: false,
                             fixedHeight: contentHeight)

  when defined(macosx) or defined(ios):
    let row = newStack(stHorizontal, spacing = 8.0)
    row.setPadding(10.0, 7.0, 10.0, 7.0)
    row.setAlignment(saLeading)

    let chevron = newLabel(chevronCollapsed)
    chevron.setFontSize(12.0)
    chevron.setTextColor(secondaryLabelColor())
    header.chevronLabel = chevron
    addArranged(row, chevron)

    let text = newLabel(title)
    text.setFontSize(13.0)
    text.setFontWeight(fwSemibold)
    header.titleLabel = text
    addArranged(row, text)

    addSubview(header, View(row))
    fillParent(View(row))

    let wrapper = newPlainView()
    entry.body = wrapper
    if contentView != nil:
      addSubview(wrapper, contentView)
      fillParent(contentView, left = 12.0, top = 2.0, right = 12.0, bottom = 10.0)
      var bodyHeight = contentHeight
      if bodyHeight <= 0.0:
        let m = measure(contentView)
        bodyHeight = m.height + 12.0
      if bodyHeight > 0.0:
        constrainSize(wrapper, 0.0, bodyHeight)
    setHidden(wrapper, true)

    addArranged(acc.root, header)
    addArranged(acc.root, wrapper)

  acc.items.add(entry)

  let self = acc
  let itemIndex = index
  registerHoverHandler(headerVid.uint32, proc() =
    setExpanded(self, itemIndex, not self.items[itemIndex].expanded))

  result = index

proc setExpanded*(acc: Accordion, index: int, expanded: bool) =
  if index < 0 or index >= acc.items.len:
    return
  if acc.items[index].expanded == expanded:
    return
  when defined(macosx) or defined(ios):
    if expanded and acc.singleOpenValue:
      for i in 0 ..< acc.items.len:
        if i != index and acc.items[i].expanded:
          setHidden(acc.items[i].body, true)
          setChevron(acc.items[i].header, false)
          acc.items[i].expanded = false
          emitAsync(acc, newAccordionChangedEvent(acc.id, i, false))
    setHidden(acc.items[index].body, not expanded)
    setChevron(acc.items[index].header, expanded)
  acc.items[index].expanded = expanded
  emitAsync(acc, newAccordionChangedEvent(acc.id, index, expanded))

proc isExpanded*(acc: Accordion, index: int): bool =
  if index >= 0 and index < acc.items.len:
    acc.items[index].expanded
  else:
    false

proc expandedIndices*(acc: Accordion): seq[int] =
  for i in 0 ..< acc.items.len:
    if acc.items[i].expanded:
      result.add(i)

proc expandAll*(acc: Accordion) =
  for i in 0 ..< acc.items.len:
    setExpanded(acc, i, true)

proc collapseAll*(acc: Accordion) =
  for i in 0 ..< acc.items.len:
    setExpanded(acc, i, false)

proc getItemCount*(acc: Accordion): int =
  acc.items.len

proc getItemTitle*(acc: Accordion, index: int): string =
  if index >= 0 and index < acc.items.len:
    acc.items[index].header.labelText
  else:
    ""

proc isSingleOpen*(acc: Accordion): bool =
  acc.singleOpenValue

proc fireHeaderClick*(acc: Accordion, index: int) =
  ## Full-stack test hook.
  when defined(macosx) and not defined(ios):
    if index >= 0 and index < acc.items.len:
      fireHoverHandler(acc.items[index].header.nativeKey)

proc onChanged*(acc: Accordion,
                handler: proc(e: AccordionChangedEvent)): ListenerId {.discardable.} =
  addListener[GuiEvent, AccordionChangedEvent](acc, handler)

proc destroy*(acc: Accordion) =
  for entry in acc.items:
    unregisterHoverHandler(entry.header.nativeKey)
    shutdownEmitter[GuiEvent](entry.header)
  acc.items.setLen(0)
  freeNative(acc)
  shutdownEmitter[GuiEvent](acc)
