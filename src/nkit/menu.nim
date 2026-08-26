import std/tables
import nkit/foundation/event
import nkit/foundation/keyboard
import nkit/foundation/event_emitter
import nkit/foundation/id_allocator
import nkit/foundation/geometry
import nkit/placement
import nkit/positioning_strategy
import nkit/image

when defined(ios):
  import nkit/platform/ios/uifunctions
elif defined(macosx):
  import nkit/platform/macos/nsfunctions

type
  MenuId* = Id
  MenuItemId* = Id

  MenuItemType* = enum
    mitNormal
    mitCheckbox
    mitRadio
    mitSeparator
    mitSubmenu

  MenuItemState* = enum
    misUnchecked
    misChecked
    misMixed

type
  MenuEvent* = ref object of Event
    menuId*: MenuId
  MenuOpenedEvent* = ref object of MenuEvent
  MenuClosedEvent* = ref object of MenuEvent
  MenuItemClickedEvent* = ref object of MenuEvent
    itemId*: MenuItemId
  MenuItemSubmenuOpenedEvent* = ref object of MenuEvent
    itemId*: MenuItemId
  MenuItemSubmenuClosedEvent* = ref object of MenuEvent
    itemId*: MenuItemId

method typeName(e: MenuEvent): string = "MenuEvent"
method typeName(e: MenuOpenedEvent): string = "MenuOpenedEvent"
method typeName(e: MenuClosedEvent): string = "MenuClosedEvent"
method typeName(e: MenuItemClickedEvent): string = "MenuItemClickedEvent"
method typeName(e: MenuItemSubmenuOpenedEvent): string = "MenuItemSubmenuOpenedEvent"
method typeName(e: MenuItemSubmenuClosedEvent): string = "MenuItemSubmenuClosedEvent"

proc newMenuOpenedEvent*(menuId: MenuId): MenuOpenedEvent =
  result = MenuOpenedEvent(menuId: menuId)
  discard stamp(result)

proc newMenuClosedEvent*(menuId: MenuId): MenuClosedEvent =
  result = MenuClosedEvent(menuId: menuId)
  discard stamp(result)

proc newMenuItemClickedEvent*(menuId: MenuId, itemId: MenuItemId): MenuItemClickedEvent =
  result = MenuItemClickedEvent(menuId: menuId, itemId: itemId)
  discard stamp(result)

proc newMenuItemSubmenuOpenedEvent*(menuId: MenuId, itemId: MenuItemId): MenuItemSubmenuOpenedEvent =
  result = MenuItemSubmenuOpenedEvent(menuId: menuId, itemId: itemId)
  discard stamp(result)

proc newMenuItemSubmenuClosedEvent*(menuId: MenuId, itemId: MenuItemId): MenuItemSubmenuClosedEvent =
  result = MenuItemSubmenuClosedEvent(menuId: menuId, itemId: itemId)
  discard stamp(result)

type
  ItemClickSink* = proc(itemKey: uint32) {.closure.}
  MenuIdSink* = proc(menuKey: uint32) {.closure.}

var globalItemClickSink*: ItemClickSink
var globalMenuOpenedSink*: MenuIdSink
var globalMenuClosedSink*: MenuIdSink

when defined(macosx) and not defined(ios):
  proc menuEventTrampoline(kind: cint, id: uint32, ctx: pointer) {.cdecl.} =
    case int(kind)
    of 0:
      if not globalItemClickSink.isNil:
        globalItemClickSink(id)
    of 1:
      if not globalMenuOpenedSink.isNil:
        globalMenuOpenedSink(id)
    of 2:
      if not globalMenuClosedSink.isNil:
        globalMenuClosedSink(id)
    else:
      discard

var menuCallbacksArmed = false

type
  MenuItem* = ref object of EventEmitter[MenuEvent]
    id*: MenuItemId
    nativeKey*: uint32
    itemType*: MenuItemType
    labelValue*: string
    labelSet*: bool
    tooltipValue*: string
    tooltipSet*: bool
    acceleratorValue*: KeyboardAccelerator
    hasAccelerator*: bool
    stateValue*: MenuItemState
    radioGroupValue*: int
    submenuValue*: Menu
    submenuOpenedListener*: ListenerId
    submenuClosedListener*: ListenerId

  Menu* = ref object of EventEmitter[MenuEvent]
    nativeKey*: uint32
    items: seq[MenuItem]

var liveItems: Table[uint32, MenuItem]
var liveMenus: Table[uint32, Menu]

proc ensureMenuCallbacks*() =
  when defined(macosx) and not defined(ios):
    if not menuCallbacksArmed:
      naMenuSetEventCallback(menuEventTrampoline, nil)
      globalItemClickSink = proc(itemKey: uint32) =
        let mi = liveItems.getOrDefault(itemKey)
        if not mi.isNil:
          mi.emit(newMenuItemClickedEvent(mi.id, mi.id))
      globalMenuOpenedSink = proc(menuKey: uint32) =
        let m = liveMenus.getOrDefault(menuKey)
        if not m.isNil:
          m.emit(newMenuOpenedEvent(m.nativeKey.MenuId))
      globalMenuClosedSink = proc(menuKey: uint32) =
        let m = liveMenus.getOrDefault(menuKey)
        if not m.isNil:
          m.emit(newMenuClosedEvent(m.nativeKey.MenuId))
      menuCallbacksArmed = true

proc newMenuItem*(label = "", itemType: MenuItemType = mitNormal): MenuItem =
  ensureMenuCallbacks()
  when defined(macosx) and not defined(ios):
    let key = naMenuItemCreate(label.cstring, cint(ord(itemType)))
  else:
    let key = allocate(typeTagMenuItem).uint32
  result = MenuItem(
    id: key.MenuItemId,
    nativeKey: key,
    itemType: itemType,
    labelValue: label,
    labelSet: label.len > 0,
    radioGroupValue: -1)
  initEmitter(result)
  liveItems[key] = result

proc getId*(mi: MenuItem): MenuItemId =
  mi.id

proc getType*(mi: MenuItem): MenuItemType =
  mi.itemType

proc setLabel*(mi: MenuItem, label: string) =
  mi.labelValue = label
  mi.labelSet = true
  when defined(macosx) and not defined(ios):
    naMenuItemSetLabel(mi.nativeKey, label.cstring)

proc clearLabel*(mi: MenuItem) =
  mi.labelValue = ""
  mi.labelSet = false
  when defined(macosx) and not defined(ios):
    naMenuItemSetLabel(mi.nativeKey, "")

proc getLabel*(mi: MenuItem): string =
  if mi.labelSet:
    mi.labelValue
  else:
    ""

proc hasLabel*(mi: MenuItem): bool =
  mi.labelSet

proc setTooltip*(mi: MenuItem, tooltip: string) =
  mi.tooltipValue = tooltip
  mi.tooltipSet = true
  when defined(macosx) and not defined(ios):
    naMenuItemSetTooltip(mi.nativeKey, tooltip.cstring)

proc clearTooltip*(mi: MenuItem) =
  mi.tooltipValue = ""
  mi.tooltipSet = false
  when defined(macosx) and not defined(ios):
    naMenuItemSetTooltip(mi.nativeKey, nil)

proc setIcon*(mi: MenuItem, img: Image) =
  when defined(macosx) and not defined(ios):
    naMenuItemSetIconPtr(mi.nativeKey, if img.isNil: nil else: img.nativePtr())

proc getTooltip*(mi: MenuItem): string =
  if mi.tooltipSet:
    mi.tooltipValue
  else:
    ""

proc setAccelerator*(mi: MenuItem, acc: KeyboardAccelerator) =
  mi.acceleratorValue = acc
  mi.hasAccelerator = true
  when defined(macosx) and not defined(ios):
    naMenuItemSetAccelerator(mi.nativeKey, acc.key.cstring, acc.modifiers.uint32)

proc clearAccelerator*(mi: MenuItem) =
  mi.acceleratorValue = KeyboardAccelerator()
  mi.hasAccelerator = false
  when defined(macosx) and not defined(ios):
    naMenuItemSetAccelerator(mi.nativeKey, "", cuint(0))

proc getAccelerator*(mi: MenuItem): KeyboardAccelerator =
  if mi.hasAccelerator:
    mi.acceleratorValue
  else:
    KeyboardAccelerator()

proc setEnabled*(mi: MenuItem, enabled: bool) =
  when defined(macosx) and not defined(ios):
    naMenuItemSetEnabled(mi.nativeKey, enabled)

proc isEnabled*(mi: MenuItem): bool =
  when defined(macosx) and not defined(ios):
    naMenuItemIsEnabled(mi.nativeKey)
  else:
    true

proc setState*(mi: MenuItem, state: MenuItemState) =
  case mi.itemType
  of mitCheckbox, mitRadio:
    if mi.itemType == mitRadio and state == misMixed:
      return
    mi.stateValue = state
    when defined(macosx) and not defined(ios):
      naMenuItemSetState(mi.nativeKey, cint(ord(state)))
  else:
    discard

proc getState*(mi: MenuItem): MenuItemState =
  mi.stateValue

proc setRadioGroup*(mi: MenuItem, group: int) =
  mi.radioGroupValue = group
  when defined(macosx) and not defined(ios):
    naMenuItemSetRadioGroup(mi.nativeKey, cint(group))

proc getRadioGroup*(mi: MenuItem): int =
  mi.radioGroupValue

proc setSubmenu*(mi: MenuItem, submenu: Menu) =
  if not mi.submenuValue.isNil:
    if mi.submenuOpenedListener != 0:
      discard mi.submenuValue.removeListener(mi.submenuOpenedListener)
      mi.submenuOpenedListener = 0
    if mi.submenuClosedListener != 0:
      discard mi.submenuValue.removeListener(mi.submenuClosedListener)
      mi.submenuClosedListener = 0
  mi.submenuValue = submenu
  when defined(macosx) and not defined(ios):
    let submenuKey = if submenu.isNil: uint32(0) else: submenu.nativeKey
    naMenuItemSetSubmenu(mi.nativeKey, submenuKey)
  if not submenu.isNil:
    let selfRef = mi
    mi.submenuOpenedListener = submenu.addListener(proc(e: MenuOpenedEvent) =
      selfRef.emit(newMenuItemSubmenuOpenedEvent(selfRef.id, selfRef.id)))
    mi.submenuClosedListener = submenu.addListener(proc(e: MenuClosedEvent) =
      selfRef.emit(newMenuItemSubmenuClosedEvent(selfRef.id, selfRef.id)))

proc getSubmenu*(mi: MenuItem): Menu =
  mi.submenuValue

proc free*(mi: MenuItem) =
  liveItems.del(mi.nativeKey)
  when defined(macosx) and not defined(ios):
    naMenuItemFree(mi.nativeKey)

proc newMenu*(): Menu =
  ensureMenuCallbacks()
  when defined(macosx) and not defined(ios):
    let key = naMenuCreate()
  else:
    let key = allocate(typeTagMenu).uint32
  result = Menu(nativeKey: key)
  initEmitter(result)
  liveMenus[key] = result

proc getId*(m: Menu): MenuId =
  m.nativeKey.MenuId

proc addItem*(m: Menu, item: MenuItem) =
  m.items.add(item)
  when defined(macosx) and not defined(ios):
    naMenuAddItem(m.nativeKey, item.nativeKey)

proc insertItem*(m: Menu, index: Natural, item: MenuItem) =
  if index >= m.items.len:
    m.addItem(item)
    return
  m.items.insert(item, index)
  when defined(macosx) and not defined(ios):
    naMenuInsertItem(m.nativeKey, item.nativeKey, cint(index))

proc removeItem*(m: Menu, item: MenuItem): bool =
  for i in 0 ..< m.items.len:
    if m.items[i] == item:
      when defined(macosx) and not defined(ios):
        discard naMenuRemoveItem(m.nativeKey, item.nativeKey)
      m.items.delete(i)
      return true
  false

proc removeItemById*(m: Menu, itemId: MenuItemId): bool =
  for i in 0 ..< m.items.len:
    if m.items[i].id == itemId:
      when defined(macosx) and not defined(ios):
        discard naMenuRemoveItem(m.nativeKey, m.items[i].nativeKey)
      m.items.delete(i)
      return true
  false

proc removeItemAt*(m: Menu, index: Natural): bool =
  if index >= m.items.len:
    return false
  let item = m.items[index]
  when defined(macosx) and not defined(ios):
    discard naMenuRemoveItem(m.nativeKey, item.nativeKey)
  m.items.delete(index)
  true

proc clearItems*(m: Menu) =
  when defined(macosx) and not defined(ios):
    naMenuClear(m.nativeKey)
  m.items.setLen(0)

proc addSeparator*(m: Menu) =
  m.addItem(newMenuItem("", mitSeparator))

proc insertSeparator*(m: Menu, index: Natural) =
  m.insertItem(index, newMenuItem("", mitSeparator))

proc getItemCount*(m: Menu): int =
  m.items.len

proc getItemAt*(m: Menu, index: Natural): MenuItem =
  if index < m.items.len:
    result = m.items[index]

proc getItemById*(m: Menu, itemId: MenuItemId): MenuItem =
  for it in m.items:
    if it.id == itemId:
      return it

proc getAllItems*(m: Menu): seq[MenuItem] =
  m.items

proc open*(m: Menu, strategy: PositioningStrategy, placement: Placement = plBottomStart) =
  var x = 0'f64
  var y = 0'f64
  case strategy.kind
  of pstAbsolute:
    x = strategy.absolutePosition.x
    y = strategy.absolutePosition.y
  of pstCursorPosition:
    let p = strategy.resolvePoint()
    x = p.x
    y = p.y
  of pstRelative:
    let rect = strategy.getRelativeRectangle()
    let offset = strategy.relativeOffset
    x = rect.x + offset.x
    y = rect.y + offset.y
  when defined(macosx) and not defined(ios):
    naMenuPopup(m.nativeKey, x, y, cint(ord(placement)))

proc close*(m: Menu): bool =
  when defined(macosx) and not defined(ios):
    naMenuCancelTracking(m.nativeKey)
  true

proc free*(m: Menu) =
  liveMenus.del(m.nativeKey)
  when defined(macosx) and not defined(ios):
    naMenuFree(m.nativeKey)
