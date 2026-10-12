import unittest

import nkit

when defined(macosx):
  import nkit/dock

  suite "dock tile":
    test "badge set get clear":
      let app = initApplication()
      app.setDockBadge("3")
      check app.getDockBadge() == "3"
      check app.hasDockBadge()
      app.clearDockBadge()
      check app.getDockBadge() == ""
      check not app.hasDockBadge()

    test "empty badge clears":
      let app = initApplication()
      app.setDockBadge("7")
      check app.hasDockBadge()
      app.setDockBadge("")
      check not app.hasDockBadge()

    test "attention request and cancel callable":
      let app = initApplication()
      let req = app.requestDockAttention(daInformational)
      app.cancelDockAttention(req)
      let crit = app.requestDockAttention(daCritical)
      app.cancelDockAttention(crit)

    test "progress set indeterminate clear callable":
      let app = initApplication()
      app.setDockProgress(0.5)
      app.setDockProgress(2.0)
      app.setDockProgressIndeterminate(true)
      app.setDockProgressIndeterminate(false)
      app.clearDockProgress()

    test "dock menu object identity":
      let app = initApplication()
      let menu = dockMenu("Alpha", "Beta")
      check menu.getItemCount() == 2
      app.setDockMenu(menu)
      check app.getDockMenuKey() == menu.nativeKey
      check cast[pointer](app.getDockMenu()) == cast[pointer](menu)
      app.refreshDockMenu()
      app.clearDockMenu()
      check app.getDockMenu().isNil
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

    test "dock reopen emits event":
      let app = initApplication()
      var reopens = 0
      discard app.addListener(proc(e: ApplicationDockReopenEvent) =
        inc reopens)
      onDockReopenTrampoline(cast[pointer](app))
      check reopens == 1
