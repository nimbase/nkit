import std/tables
import ../foundation/id_allocator
import ../window
import ../foundation/event
import ../foundation/event_emitter
import ./view
when defined(ios):
  import ../platform/ios/uifunctions
elif defined(macosx):
  import ../platform/macos/nsfunctions
elif defined(linux):
  import ../platform/linux/gfunctions

export view

type
  ToolbarItemClickedEvent* = ref object of GuiEvent
    ordinal*: int

  ToolbarSearchEvent* = ref object of GuiEvent
    ordinal*: int
    text*: string
    submitted*: bool

  ToolbarDisplayMode* = enum
    tdmIconOnly
    tdmIconAndLabel
    tdmLabelOnly

  Toolbar* = ref object
    handle: int64
    windowId: uint32

var toolbarClicks = initTable[uint32, proc()]()
var toolbarSearches = initTable[uint32, proc(text: string, submitted: bool)]()
var toolbarItemOrder = initTable[int64, seq[uint32]]()
var toolbarTooltips = initTable[uint32, string]()
var toolbarEnabled = initTable[uint32, bool]()
var nextToolbarWidgetId: uint32 = 1
var toolbarCallbacksArmed = false

when defined(macosx) or defined(linux):
  proc toolbarClickTrampoline(widgetId: cuint, ctx: pointer) {.cdecl.} =
    let wid = uint32(widgetId)
    if toolbarClicks.hasKey(wid):
      toolbarClicks[wid]()

  proc toolbarSearchTrampoline(widgetId: cuint, submitted: bool,
                               text: cstring) {.cdecl.} =
    let wid = uint32(widgetId)
    if toolbarSearches.hasKey(wid):
      toolbarSearches[wid](if text.isNil: "" else: $text, submitted)

method typeName(e: ToolbarItemClickedEvent): string = "ToolbarItemClickedEvent"
method typeName(e: ToolbarSearchEvent): string = "ToolbarSearchEvent"

proc newToolbarItemClickedEvent*(ordinal: int): ToolbarItemClickedEvent =
  result = ToolbarItemClickedEvent(ordinal: ordinal)
  discard stamp(result)

proc newToolbarSearchEvent*(ordinal: int, text: string,
                            submitted: bool): ToolbarSearchEvent =
  result = ToolbarSearchEvent(ordinal: ordinal, text: text,
                              submitted: submitted)
  discard stamp(result)

proc ensureToolbarCallbacks() =
  when defined(macosx) or defined(linux):
    if not toolbarCallbacksArmed:
      naToolbarSetClickCallback(toolbarClickTrampoline)
      naToolbarSetSearchCallback(toolbarSearchTrampoline)
      toolbarCallbacksArmed = true

proc attachToolbar*(win: Window): Toolbar =
  ensureToolbarCallbacks()
  when defined(macosx) or defined(linux):
    let h = naToolbarAttach(win.id.uint32)
  else:
    let h = int64(0)
  result = Toolbar(handle: h, windowId: win.id.uint32)

proc trackItem(t: Toolbar, wid: uint32) =
  if not toolbarItemOrder.hasKey(t.handle):
    toolbarItemOrder[t.handle] = @[]
  toolbarItemOrder[t.handle].add(wid)

proc addItem*(t: Toolbar, label: string, symbolName: string,
              onTap: proc()): int =
  ## Appends an icon button; onTap fires on click. Returns the ordinal.
  when defined(macosx) or defined(linux):
    let wid = nextToolbarWidgetId
    inc nextToolbarWidgetId
    if not onTap.isNil:
      toolbarClicks[wid] = onTap
    toolbarEnabled[wid] = true
    let ordinal = naToolbarAddItem(t.handle, label.cstring,
                                   symbolName.cstring, wid)
    t.trackItem(wid)
    result = int(ordinal)
  else:
    0

proc addSeparator*(t: Toolbar): int =
  ## Appends a fixed divider. Returns the ordinal.
  when defined(macosx) or defined(linux):
    let wid = nextToolbarWidgetId
    inc nextToolbarWidgetId
    let ordinal = naToolbarAddSpace(t.handle, false, wid)
    t.trackItem(wid)
    result = int(ordinal)
  else:
    0

proc addFlexibleSpace*(t: Toolbar): int =
  ## Appends a stretchy gap that pushes later items right. Returns the ordinal.
  when defined(macosx) or defined(linux):
    let wid = nextToolbarWidgetId
    inc nextToolbarWidgetId
    let ordinal = naToolbarAddSpace(t.handle, true, wid)
    t.trackItem(wid)
    result = int(ordinal)
  else:
    0

proc addSearch*(t: Toolbar, placeholder = "",
                onSearch: proc(text: string, submitted: bool) = nil): int =
  ## Appends a search field. `onSearch` fires live on typing
  ## (`submitted=false`) and on Enter (`submitted=true`). Returns the ordinal.
  when defined(macosx) or defined(linux):
    let wid = nextToolbarWidgetId
    inc nextToolbarWidgetId
    if not onSearch.isNil:
      toolbarSearches[wid] = onSearch
    let ordinal = naToolbarAddSearch(t.handle, placeholder.cstring, wid)
    t.trackItem(wid)
    result = int(ordinal)
  else:
    0

proc widgetIdAt*(t: Toolbar, ordinal: int): uint32 =
  if toolbarItemOrder.hasKey(t.handle) and
      ordinal >= 0 and ordinal < toolbarItemOrder[t.handle].len:
    toolbarItemOrder[t.handle][ordinal]
  else:
    0

proc removeItem*(t: Toolbar, ordinal: int) =
  ## Removes the item at `ordinal`. Later ordinals shift down.
  when defined(macosx) or defined(linux):
    let wid = t.widgetIdAt(ordinal)
    if wid == 0:
      return
    naToolbarRemoveItem(t.handle, wid)
    toolbarItemOrder[t.handle].delete(ordinal)
    toolbarClicks.del(wid)
    toolbarSearches.del(wid)
    toolbarTooltips.del(wid)
    toolbarEnabled.del(wid)

proc setItemTooltip*(t: Toolbar, ordinal: int, tooltip: string) =
  when defined(macosx) or defined(linux):
    let wid = t.widgetIdAt(ordinal)
    if wid == 0:
      return
    toolbarTooltips[wid] = tooltip
    naToolbarSetItemTooltip(t.handle, wid, tooltip.cstring)

proc getItemTooltip*(t: Toolbar, ordinal: int): string =
  toolbarTooltips.getOrDefault(t.widgetIdAt(ordinal), "")

proc setItemEnabled*(t: Toolbar, ordinal: int, enabled: bool) =
  when defined(macosx) or defined(linux):
    let wid = t.widgetIdAt(ordinal)
    if wid == 0:
      return
    toolbarEnabled[wid] = enabled
    naToolbarSetItemEnabled(t.handle, wid, enabled)

proc isItemEnabled*(t: Toolbar, ordinal: int): bool =
  let wid = t.widgetIdAt(ordinal)
  if wid == 0:
    return false
  when defined(macosx) or defined(linux):
    naToolbarIsItemEnabled(t.handle, wid)
  else:
    toolbarEnabled.getOrDefault(wid, true)

proc setDisplayMode*(t: Toolbar, mode: ToolbarDisplayMode) =
  ## Icon-only, icon+label, or label-only for the whole toolbar.
  when defined(macosx) or defined(linux):
    naToolbarSetDisplayMode(t.handle, cint(ord(mode)))

proc setSmallSize*(t: Toolbar, small: bool) =
  ## Compact (`true`) or regular control size.
  when defined(macosx) or defined(linux):
    naToolbarSetSizeMode(t.handle, small)

proc setAllowsCustomization*(t: Toolbar, allowed: bool) =
  ## Shows the drag-to-customize palette entry (NSToolbar).
  when defined(macosx) or defined(linux):
    naToolbarSetAllowsCustomization(t.handle, allowed)

proc setShowsBaselineSeparator*(t: Toolbar, show: bool) =
  when defined(macosx) or defined(linux):
    naToolbarSetShowsBaselineSeparator(t.handle, show)

proc setSelectedItem*(t: Toolbar, ordinal: int) =
  ## Highlights one button as selected (selectable-item toolbars).
  when defined(macosx) or defined(linux):
    naToolbarSetSelectedItem(t.handle, t.widgetIdAt(ordinal))

proc clearSelection*(t: Toolbar) =
  when defined(macosx) or defined(linux):
    naToolbarSetSelectedItem(t.handle, 0)

proc getSearchText*(t: Toolbar, ordinal: int): string =
  when defined(macosx) or defined(linux):
    let wid = t.widgetIdAt(ordinal)
    if wid == 0:
      return ""
    $naToolbarGetSearchText(t.handle, wid)
  else:
    ""

proc itemCount*(t: Toolbar): int =
  when defined(macosx) or defined(linux):
    int(naToolbarItemCount(t.handle))
  else:
    0

proc fireToolbarItemSimulated*(t: Toolbar, ordinal: int) =
  ## Test hook: presses a toolbar item through the callback pipeline.
  when defined(macosx) or defined(ios) or defined(linux):
    let wid = t.widgetIdAt(ordinal)
    if wid != 0 and toolbarClicks.hasKey(wid):
      toolbarClicks[wid]()

proc fireToolbarSearchSimulated*(t: Toolbar, ordinal: int, text: string,
                                 submitted = true) =
  ## Test hook: delivers search text through the callback pipeline.
  when defined(macosx) or defined(linux):
    naToolbarFireSearch(t.widgetIdAt(ordinal), submitted, text.cstring)
  else:
    let wid = t.widgetIdAt(ordinal)
    if wid != 0 and toolbarSearches.hasKey(wid):
      toolbarSearches[wid](text, submitted)
