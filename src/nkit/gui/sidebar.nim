import std/strutils
import nkit/foundation/id_allocator
import nkit/foundation/event
import nkit/foundation/event_emitter
import nkit/gui/view
import nkit/gui/stack
import nkit/gui/scroll
import nkit/gui/label
import nkit/gui/separator
import nkit/gui/imageview
import nkit/gui/badge
import nkit/gui/theme
import nkit/gui/hover_router
import nkit/platform/macos/nsfunctions

export view, stack, scroll

type
  SidebarSelectEvent* = ref object of GuiEvent
    sidebarId*: Id
    itemIndex*: int

  SidebarItem* = ref object of View
    rowIndex*: int
    labelText*: string
    badgeValue*: Badge

  Sidebar* = ref object of View
    listStack*: Stack
    items: seq[SidebarItem]
    selectedIndexValue*: int

method typeName(e: SidebarSelectEvent): string = "SidebarSelectEvent"

proc newSidebarSelectEvent*(sidebarId: Id, itemIndex: int): SidebarSelectEvent =
  result = SidebarSelectEvent(sidebarId: sidebarId, itemIndex: itemIndex)
  discard stamp(result)

proc selectIndex*(sb: Sidebar, index: int) =
  ## Marks the given item selected and emits the selection event.
  if index < 0 or index >= sb.items.len or index == sb.selectedIndexValue:
    return
  when defined(macosx) or defined(ios):
    if sb.selectedIndexValue >= 0 and sb.selectedIndexValue < sb.items.len:
      naHoverViewSetSelected(sb.items[sb.selectedIndexValue].native, false)
    naHoverViewSetSelected(sb.items[index].native, true)
  sb.selectedIndexValue = index
  emitAsync(sb, newSidebarSelectEvent(sb.id, index))

proc newSidebar*(): Sidebar =
  ensureHoverRouter()
  let vid = allocate(typeTagGuiWidget)
  let scroller = newScroll()
  result = Sidebar(selectedIndexValue: -1)
  discard wrapView(result, scroller.native, vid)

  when defined(macosx) or defined(ios):
    let list = newStack(stVertical, spacing = 2.0)
    result.listStack = list
    setPadding(list, 6.0, 10.0, 6.0, 10.0)
    setDocument(scroller, View(list))
    fitWidth(scroller, 8.0, 8.0)

proc addSectionHeader*(sb: Sidebar, title: string): Label =
  let lbl = newLabel(title.toUpperAscii())
  lbl.setFontSize(11.0)
  lbl.setFontWeight(fwSemibold)
  lbl.setTextColor(secondaryLabelColor())
  when defined(macosx) or defined(ios):
    addArranged(sb.listStack, lbl)
  result = lbl

proc addItem*(sb: Sidebar, title: string, symbolName = "", badgeText = ""): SidebarItem =
  let itemVid = allocate(typeTagGuiWidget)
  when defined(macosx) or defined(ios):
    let hoverPtr = naHoverViewCreate(itemVid.uint32)
  else:
    let hoverPtr: pointer = nil
  let index = sb.items.len
  result = SidebarItem(rowIndex: index, labelText: title, badgeValue: nil)
  discard wrapView(result, hoverPtr, itemVid)
  sb.items.add(result)

  let self = sb
  let itemIndex = index
  registerHoverHandler(itemVid.uint32, proc() = selectIndex(self, itemIndex))

  when defined(macosx) or defined(ios):
    let row = newStack(stHorizontal, spacing = 8.0)
    row.setPadding(10.0, 5.0, 10.0, 5.0)

    if symbolName.len > 0:
      let icon = newImageView()
      icon.setSymbol(symbolName, 15.0, weight = 2)
      icon.setContentHugging(0, 750.0)
      addArranged(row, icon)

    let text = newLabel(title)
    addArranged(row, text)

    let spacer = newPlainView()
    spacer.setContentHugging(0, 1.0)
    addArranged(row, spacer)

    if badgeText.len > 0:
      let pill = newBadge(badgeText, bvSecondary)
      result.badgeValue = pill
      addArranged(row, pill)

    addSubview(result, View(row))
    fillParent(View(row))
    addArranged(sb.listStack, result)

proc addSeparatorLine*(sb: Sidebar) =
  when defined(macosx) or defined(ios):
    let sep = newSeparator(soHorizontal)
    sep.setThickness(1.0)
    setContentHugging(sep, 1, 750.0)
    addArranged(sb.listStack, sep)

proc getSelectedIndex*(sb: Sidebar): int =
  sb.selectedIndexValue

proc getItemCount*(sb: Sidebar): int =
  sb.items.len

proc getItem*(sb: Sidebar, index: int): SidebarItem =
  if index >= 0 and index < sb.items.len:
    sb.items[index]
  else:
    nil

proc fireItemClick*(sb: Sidebar, index: int) =
  ## Full-stack test hook.
  when defined(macosx) or defined(ios):
    if index >= 0 and index < sb.items.len:
      fireHoverHandler(sb.items[index].nativeKey)

proc onSelect*(sb: Sidebar, handler: proc(e: SidebarSelectEvent)): ListenerId {.discardable.} =
  addListener[GuiEvent, SidebarSelectEvent](sb, handler)

proc destroy*(sb: Sidebar) =
  for item in sb.items:
    unregisterHoverHandler(item.nativeKey)
    shutdownEmitter[GuiEvent](item)
  sb.items.setLen(0)
  freeNative(sb)
  shutdownEmitter[GuiEvent](sb)
