import unittest
import std/monotimes

import nkit

suite "application":
  test "singleton identity":
    let a = initApplication()
    let b = initApplication()
    check cast[pointer](a) == cast[pointer](b)

  test "headless state":
    let app = initApplication()
    check not app.isRunning()
    check not app.isSingleInstance()
    check not app.setIcon("")

  test "dock icon visibility toggles":
    let app = initApplication()
    check app.setDockIconVisible(true)
    check app.setDockIconVisible(false)
    check app.setDockIconVisible(true)

  test "event fan-out through emitter":
    let app = initApplication()
    var requested = 0
    var started = 0
    discard app.addListener(proc(e: ApplicationQuitRequestedEvent) =
      inc requested)
    discard app.addListener(proc(e: ApplicationStartedEvent) =
      inc started)
    app.emit(newApplicationQuitRequestedEvent())
    app.emit(newApplicationStartedEvent())
    app.emit(newApplicationExitingEvent(3))
    check requested == 1
    check started >= 1
