import std/tables
import nkit/foundation/id_allocator
import nkit/foundation/event
import nkit/foundation/event_emitter
import nkit/gui/view
import nkit/gui/stack
import nkit/gui/segmented

export view, stack, segmented

type
  TabChangedEvent* = ref object of GuiEvent
    tabsId*: Id
    index*: int

  Tabs* = ref object of View
    layout*: Stack
    bar*: SegmentedControl
    contentSlot*: View
    pages: Table[int, View]
    currentIndexValue*: int

var liveTabs: Table[uint32, Tabs]

method typeName(e: TabChangedEvent): string = "TabChangedEvent"

proc newTabChangedEvent*(tabsId: Id, index: int): TabChangedEvent =
  result = TabChangedEvent(tabsId: tabsId, index: index)
  discard stamp(result)

proc currentPage*(t: Tabs): int =
  t.currentIndexValue

proc selectPage*(t: Tabs, index: int) =
  if index == t.currentIndexValue:
    return
  when defined(macosx) or defined(ios):
    if t.currentIndexValue >= 0 and t.pages.hasKey(t.currentIndexValue):
      setHidden(t.pages[t.currentIndexValue], true)
    if t.pages.hasKey(index):
      let page = t.pages[index]
      addSubview(t.contentSlot, page)
      fillParent(page)
      setHidden(page, false)
    t.currentIndexValue = index
    if not t.bar.isNil and getSelectedIndex(t.bar) != index:
      selectIndex(t.bar, index)
    emitAsync(t, newTabChangedEvent(t.id, index))

proc addPage*(t: Tabs, index: int, page: View, showNow = false) =
  t.pages[index] = page
  when defined(macosx) or defined(ios):
    setHidden(page, true)
  if showNow:
    selectPage(t, index)

proc newTabs*(labels: openArray[string]): Tabs =
  let base = newPlainView()
  result = Tabs(currentIndexValue: -1)
  discard wrapView(result, base.native, base.id)
  liveTabs[base.id.uint32] = result

  when defined(macosx) or defined(ios):
    let layout = newStack(stVertical, spacing = 8.0)
    result.layout = layout
    addSubview(result, View(layout))
    fillParent(View(layout))

    let bar = newSegmented(labels)
    result.bar = bar

    let self = result
    discard addListener[GuiEvent, SegmentedSelectEvent](bar, proc(e: SegmentedSelectEvent) =
      if e.index != self.currentIndexValue:
        selectPage(self, e.index))

    let contentSlot = newPlainView()
    result.contentSlot = contentSlot
    contentSlot.setContentHugging(1, 10.0)

    addArranged(layout, View(bar))
    addArranged(layout, contentSlot)

proc destroy*(t: Tabs) =
  freeNative(t)
  liveTabs.del(t.nativeKey)
  shutdownEmitter[GuiEvent](t)

proc onChanged*(t: Tabs, handler: proc(e: TabChangedEvent)): ListenerId {.discardable.} =
  addListener[GuiEvent, TabChangedEvent](t, handler)
