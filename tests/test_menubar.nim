import unittest

import nkit

when defined(macosx):
  import nkit/menubar

  suite "main menu attach":
    test "set get clear round trip":
      let app = initApplication()
      let bar = newMenu()
      app.setMainMenu(bar)
      check app.getMainMenuKey() == bar.nativeKey
      check cast[pointer](app.getMainMenu()) == cast[pointer](bar)
      app.clearMainMenu()
      check app.getMainMenuKey() == 0
      check app.getMainMenu().isNil
      bar.free()

  suite "standard selectors":
    test "known selectors accepted and recorded":
      let item = newMenuItem("Copy")
      check item.setStandardSelector(ssCopy)
      check item.hasSelector
      check item.getStandardSelector() == "copy:"
      item.free()

    test "unknown selector names rejected":
      let item = newMenuItem("Bogus")
      check not item.setStandardSelectorName("frobnicate:")
      check not item.setStandardSelectorName("")
      check not item.hasSelector
      check item.getStandardSelector() == ""
      item.free()

    test "plain items never carry selectors":
      let item = newMenuItem("About Demo")
      check not item.hasSelector
      item.free()

  suite "standard menu builders":
    test "app menu has canonical items":
      let appM = buildAppMenu("Demo")
      check appM.menu.getItemCount() == 11
      check appM.aboutItem.getLabel() == "About Demo"
      check appM.prefsItem.getLabel() == "Preferences…"
      check appM.prefsItem.getAccelerator().key == ","
      check not appM.prefsItem.hasSelector
      let items = appM.menu.getAllItems()
      check items[6].getLabel() == "Hide Demo"
      check items[6].getStandardSelector() == "hide:"
      check items[10].getLabel() == "Quit Demo"
      check items[10].getStandardSelector() == "terminate:"

    test "edit menu items are all native-handled":
      let edit = buildEditMenu()
      check edit.getItemCount() == 8
      let items = edit.getAllItems()
      check items[0].getLabel() == "Undo"
      check items[0].getStandardSelector() == "undo:"
      check items[0].getAccelerator().key == "Z"
      check items[3].getLabel() == "Cut"
      check items[7].getLabel() == "Select All"
      check items[7].getStandardSelector() == "selectAll:"
      for it in items:
        if it.getType() == mitNormal:
          check it.hasSelector

    test "window menu carries fullscreen shortcut":
      let win = buildWindowMenu()
      check win.getItemCount() == 6
      let items = win.getAllItems()
      check items[0].getStandardSelector() == "performMiniaturize:"
      check items[3].getLabel() == "Enter Full Screen"
      check items[3].getStandardSelector() == "toggleFullScreen:"

    test "top-level assembly and insertion order":
      let bar = newMenu()
      let appM = buildAppMenu("Demo")
      let edit = buildEditMenu()
      let fileM = newMenu()
      discard bar.addTopMenu("", appM.menu)
      discard bar.addTopMenu("Edit", edit)
      let fileHolder = bar.addTopMenu("File", fileM, at = 1)
      check bar.getItemCount() == 3
      check bar.getItemAt(1) == fileHolder
      check fileHolder.getSubmenu() == fileM
      check bar.getItemAt(0).getSubmenu() == appM.menu

    test "plain-item clicks still route to Nim":
      let appM = buildAppMenu("Demo")
      var aboutClicks = 0
      var prefsClicks = 0
      discard appM.aboutItem.addListener(proc(e: MenuItemClickedEvent) =
        inc aboutClicks)
      discard appM.prefsItem.addListener(proc(e: MenuItemClickedEvent) =
        inc prefsClicks)
      if not globalItemClickSink.isNil:
        globalItemClickSink(appM.aboutItem.nativeKey)
        globalItemClickSink(appM.prefsItem.nativeKey)
      check aboutClicks == 1
      check prefsClicks == 1

    test "standardMenuBar builds the canonical skeleton":
      let std = standardMenuBar("Demo")
      check std.bar.getItemCount() == 4
      check std.bar.getItemAt(0).getSubmenu() == std.app.menu
      check std.bar.getItemAt(1).getSubmenu() == std.edit
      check std.bar.getItemAt(2).getSubmenu() == std.window
      check std.bar.getItemAt(3).getSubmenu() == std.help
      check std.app.aboutItem.getLabel() == "About Demo"
