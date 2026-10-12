import unittest

import nkit
import nkit/gui/view

when defined(macosx):
  suite "view context menus":
    test "set get clear round trip":
      let v = newPlainView()
      defer:
        destroy(v)
      check not v.hasContextMenu()
      check v.getContextMenu().isNil
      let menu = newMenu()
      menu.addItem(newMenuItem("One"))
      v.setContextMenu(menu)
      check v.hasContextMenu()
      check cast[pointer](v.getContextMenu()) == cast[pointer](menu)
      v.clearContextMenu()
      check not v.hasContextMenu()
      check v.getContextMenu().isNil
      menu.free()

    test "set nil detaches":
      let v = newPlainView()
      defer:
        destroy(v)
      let menu = newMenu()
      v.setContextMenu(menu)
      check v.hasContextMenu()
      v.setContextMenu(nil)
      check not v.hasContextMenu()
      menu.free()

    test "freeing menu detaches views":
      let v = newPlainView()
      defer:
        destroy(v)
      let menu = newMenu()
      menu.addItem(newMenuItem("X"))
      v.setContextMenu(menu)
      check v.hasContextMenu()
      menu.free()
      check not v.hasContextMenu()
      check v.getContextMenu().isNil

    test "openContextMenu callable headless":
      let v = newPlainView()
      defer:
        destroy(v)
      check not v.openContextMenu()
      let menu = newMenu()
      menu.addItem(newMenuItem("Y"))
      v.setContextMenu(menu)
      discard v.openContextMenu()
      menu.free()

    test "dynamic items via MenuOpenedEvent":
      let v = newPlainView()
      defer:
        destroy(v)
      let menu = newMenu()
      menu.addItem(newMenuItem("Static"))
      v.setContextMenu(menu)
      var opened = 0
      discard menu.addListener(proc(e: MenuOpenedEvent) =
        inc opened)
      menu.emit(newMenuOpenedEvent(menu.getId()))
      check opened == 1
      check menu.getItemCount() == 1
      menu.free()

  suite "window context menus":
    test "set get clear on content view":
      let w = newWindow()
      let menu = newMenu()
      menu.addItem(newMenuItem("Win item"))
      w.setContextMenu(menu)
      check w.hasContextMenu()
      check cast[pointer](w.getContextMenu()) == cast[pointer](menu)
      w.clearContextMenu()
      check not w.hasContextMenu()
      menu.free()
      w.free()
