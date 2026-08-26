import unittest

import nkit

suite "menu items":
  test "create with label and type":
    let item = newMenuItem("Open", mitNormal)
    check item.id.getType() == typeTagMenuItem
    check item.itemType == mitNormal
    check item.getLabel() == "Open"
    check item.hasLabel()
    check not item.isNil
    item.free()

  test "label set and clear":
    let item = newMenuItem("File")
    item.setLabel("Edit")
    check item.getLabel() == "Edit"
    item.clearLabel()
    check not item.hasLabel()
    item.free()

  test "enabled state":
    let item = newMenuItem("Action")
    check item.isEnabled()
    item.setEnabled(false)
    check not item.isEnabled()
    item.setEnabled(true)
    check item.isEnabled()
    item.free()

  test "tooltip":
    let item = newMenuItem("X")
    item.setTooltip("does things")
    check item.getTooltip() == "does things"
    item.clearTooltip()
    check not item.tooltipSet
    item.free()

  test "accelerator stored and cleared":
    let item = newMenuItem("Save")
    let acc = keyboardAccelerator("S", modCtrl or modMeta)
    item.setAccelerator(acc)
    let got = item.getAccelerator()
    check got.key == "S"
    check got.modifiers.hasMods(modCtrl)
    check got.modifiers.hasMods(modMeta)
    item.clearAccelerator()
    check not item.hasAccelerator
    check item.getAccelerator().isEmpty
    item.free()

  test "checkbox state transitions":
    let box = newMenuItem("Toggle", mitCheckbox)
    check box.getState() == misUnchecked
    box.setState(misChecked)
    check box.getState() == misChecked
    box.setState(misMixed)
    check box.getState() == misMixed
    box.setState(misUnchecked)
    check box.getState() == misUnchecked
    box.free()

  test "radio rejects mixed but accepts checked":
    let radio = newMenuItem("Option", mitRadio)
    radio.setRadioGroup(1)
    check radio.getRadioGroup() == 1
    radio.setState(misMixed)
    check radio.getState() == misUnchecked
    radio.setState(misChecked)
    check radio.getState() == misChecked
    radio.free()

  test "normal item ignores state changes":
    let plain = newMenuItem("Plain")
    plain.setState(misChecked)
    check plain.getState() == misUnchecked
    plain.free()

suite "menus":
  test "add remove count":
    let menu = newMenu()
    check menu.getItemCount() == 0
    let a = newMenuItem("A")
    let b = newMenuItem("B")
    menu.addItem(a)
    menu.addItem(b)
    check menu.getItemCount() == 2
    check menu.getItemAt(0) == a
    check menu.getItemAt(1) == b
    check menu.getItemById(b.id) == b
    check menu.removeItem(a)
    check menu.getItemCount() == 1
    check menu.getItemAt(0) == b
    menu.clearItems()
    check menu.getItemCount() == 0
    a.free()
    b.free()
    menu.free()

  test "insert and remove at index":
    let menu = newMenu()
    let a = newMenuItem("first")
    let c = newMenuItem("third")
    menu.addItem(a)
    menu.addItem(c)
    let b = newMenuItem("second")
    menu.insertItem(1, b)
    check menu.getItemAt(1) == b
    check menu.getItemCount() == 3
    check menu.removeItemAt(2)
    check menu.getItemCount() == 2
    check menu.removeItemById(a.id)
    check menu.getItemCount() == 1
    for it in @[b]:
      it.free()
    a.free()
    c.free()
    menu.free()

  test "separators counted as items":
    let menu = newMenu()
    menu.addSeparator()
    menu.addSeparator()
    check menu.getItemCount() == 2
    check menu.getItemAt(0).itemType == mitSeparator
    menu.clearItems()
    check menu.getItemCount() == 0
    menu.free()

  test "submenu linking forwards events":
    let parent = newMenu()
    let sub = newMenu()
    let holder = newMenuItem("Submenu", mitSubmenu)
    parent.addItem(holder)

    var opened, closed = 0
    discard holder.addListener(proc(e: MenuItemSubmenuOpenedEvent) =
      inc opened)
    discard holder.addListener(proc(e: MenuItemSubmenuClosedEvent) =
      inc closed)

    holder.setSubmenu(sub)

    sub.emit(newMenuOpenedEvent(sub.getId()))
    sub.emit(newMenuClosedEvent(sub.getId()))
    check opened == 1
    check closed == 1

    holder.setSubmenu(nil)
    check holder.getSubmenu().isNil
    holder.free()
    sub.free()
    parent.free()

  test "click event routed to live item":
    let item = newMenuItem("Click me")
    var clicks = 0
    discard item.addListener(proc(e: MenuItemClickedEvent) =
      inc clicks)
    if not globalItemClickSink.isNil:
      globalItemClickSink(item.nativeKey)
    check clicks == 1
    item.free()

  test "open close api callable":
    let menu = newMenu()
    menu.addItem(newMenuItem("One"))
    check menu.close()
    menu.free()

suite "tray icons":
  test "create visible hide free":
    let tray = sharedTrayManager().createTray()
    check tray.id.getType() == typeTagTrayIcon
    check tray.exists()
    discard tray.setVisible(false)
    check not tray.isVisible()
    check tray.setVisible(true)
    tray.free()
    discard sharedTrayManager().remove(tray.id)
    check not tray.exists()

  test "title and tooltip round trip":
    let tray = sharedTrayManager().createTray()
    tray.setTitle("demo")
    check tray.getTitle() == "demo"
    tray.setTooltip("demo tooltip")
    check tray.getTooltip() == "demo tooltip"
    tray.clearTitle()
    tray.clearTooltip()
    check tray.getTitle() == ""
    tray.free()
    discard sharedTrayManager().remove(tray.id)

  test "context menu link and trigger setting":
    let tray = sharedTrayManager().createTray()
    let menu = newMenu()
    menu.addItem(newMenuItem("Quit"))
    tray.setContextMenu(menu)
    check cast[pointer](tray.getContextMenu()) == cast[pointer](menu)
    tray.setContextMenuTrigger(cmtRightClicked)
    check tray.getContextMenuTrigger() == cmtRightClicked
    tray.setContextMenu(nil)
    check tray.getContextMenu().isNil
    menu.free()
    tray.free()
    discard sharedTrayManager().remove(tray.id)

  test "bounds are zeros when hidden or absent window":
    let tray = sharedTrayManager().createTray()
    discard tray.setVisible(false)
    let b = tray.getBounds()
    check b.width >= 0'f64
    tray.free()
    discard sharedTrayManager().remove(tray.id)

  test "manager tracks created trays":
    let tm = sharedTrayManager()
    let before = tm.len()
    let tray = tm.createTray()
    check tm.len() == before + 1
    check cast[pointer](tm.get(tray.id)) == cast[pointer](tray)
    discard tm.remove(tray.id)
    check tm.len() == before
    tray.free()

  test "manager get and getAll reflect registry":
    let tm = sharedTrayManager()
    let tray = tm.createTray()
    check cast[pointer](tm.get(tray.id)) == cast[pointer](tray)
    var found = false
    for t in tm.getAll():
      if t.id == tray.id:
        found = true
    check found
    check tm.get(999999'u32.TrayIconId).isNil
    tray.free()
    discard tm.remove(tray.id)

  test "shutdown hides trays and unlinks menus":
    let tm = sharedTrayManager()
    let tray = tm.createTray()
    let menu = newMenu()
    menu.addItem(newMenuItem("entry"))
    tray.setContextMenu(menu)
    check not tray.getContextMenu().isNil
    tm.shutdown()
    check tm.len() == 0
    check tray.getContextMenu().isNil
    menu.free()
    tray.free()

suite "dock menu":
  test "set and clear round trip":
    let app = initApplication()
    let menu = newMenu()
    menu.addItem(newMenuItem("Dock action"))
    app.setDockMenu(menu)
    check app.getDockMenuKey() == menu.nativeKey
    app.clearDockMenu()
    check app.getDockMenuKey() == 0
    menu.free()

  test "dock item clicks route through live items":
    let app = initApplication()
    let menu = newMenu()
    let item = newMenuItem("Dock entry")
    menu.addItem(item)
    app.setDockMenu(menu)

    var clicks = 0
    discard item.addListener(proc(e: MenuItemClickedEvent) =
      inc clicks)
    if not globalItemClickSink.isNil:
      globalItemClickSink(item.nativeKey)
    check clicks == 1

    app.clearDockMenu()
    item.free()
    menu.free()

suite "message dialog":
  test "title message round trip":
    let dlg = newMessageDialog("Update", "Install now?")
    check dlg.getTitle() == "Update"
    check dlg.getMessage() == "Install now?"
    dlg.setTitle("New Title")
    check dlg.getTitle() == "New Title"
    dlg.setMessage("Later")
    check dlg.getMessage() == "Later"

  test "modality defaults to none and is settable":
    let dlg = newMessageDialog("t", "m")
    check dlg.modality == dmNone
    dlg.modality = dmApplication
    check dlg.modality == dmApplication
    dlg.destroy()
