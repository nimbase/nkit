import std/monotimes
import nkit/foundation/event
import nkit/foundation/event_emitter

when defined(ios):
  import nkit/platform/ios/uifunctions
elif defined(macosx):
  import nkit/platform/macos/nsfunctions
when defined(ios):
  import nkit/platform/ios/dispatcher_ios
  export dispatcher_ios.ensurePlatformDispatcher
elif defined(macosx):
  import nkit/platform/macos/dispatcher_macos
  export dispatcher_macos.ensurePlatformDispatcher

type
  ApplicationEvent* = ref object of Event
  ApplicationStartedEvent* = ref object of ApplicationEvent
  ApplicationExitingEvent* = ref object of ApplicationEvent
    exitCode*: int
  ApplicationActivatedEvent* = ref object of ApplicationEvent
  ApplicationDeactivatedEvent* = ref object of ApplicationEvent
  ApplicationQuitRequestedEvent* = ref object of ApplicationEvent

method typeName(e: ApplicationEvent): string = "ApplicationEvent"
method typeName(e: ApplicationStartedEvent): string = "ApplicationStartedEvent"
method typeName(e: ApplicationExitingEvent): string = "ApplicationExitingEvent"
method typeName(e: ApplicationActivatedEvent): string = "ApplicationActivatedEvent"
method typeName(e: ApplicationDeactivatedEvent): string = "ApplicationDeactivatedEvent"
method typeName(e: ApplicationQuitRequestedEvent): string = "ApplicationQuitRequestedEvent"

proc newApplicationStartedEvent*(): ApplicationStartedEvent =
  result = ApplicationStartedEvent()
  discard stamp(result)

proc newApplicationExitingEvent*(exitCode: int): ApplicationExitingEvent =
  result = ApplicationExitingEvent(exitCode: exitCode)
  discard stamp(result)

proc newApplicationActivatedEvent*(): ApplicationActivatedEvent =
  result = ApplicationActivatedEvent()
  discard stamp(result)

proc newApplicationDeactivatedEvent*(): ApplicationDeactivatedEvent =
  result = ApplicationDeactivatedEvent()
  discard stamp(result)

proc newApplicationQuitRequestedEvent*(): ApplicationQuitRequestedEvent =
  result = ApplicationQuitRequestedEvent()
  discard stamp(result)

import nkit/window
import nkit/window_manager
import nkit/menu

type Application* = ref object of EventEmitter[ApplicationEvent]
  running*: bool
  exitCode*: int
  primaryWindow*: Window

when defined(macosx) or defined(ios):
  proc onStartedTrampoline(ctx: pointer) {.cdecl.} =
    cast[Application](ctx).emit(newApplicationStartedEvent())

  proc onActivatedTrampoline(ctx: pointer) {.cdecl.} =
    cast[Application](ctx).emit(newApplicationActivatedEvent())

  proc onDeactivatedTrampoline(ctx: pointer) {.cdecl.} =
    cast[Application](ctx).emit(newApplicationDeactivatedEvent())

  proc onQuitRequestedTrampoline(ctx: pointer) {.cdecl.} =
    cast[Application](ctx).emit(newApplicationQuitRequestedEvent())

  proc onExitingTrampoline(exitCode: cint, ctx: pointer) {.cdecl.} =
    let app = cast[Application](ctx)
    app.exitCode = int(exitCode)
    app.emit(newApplicationExitingEvent(int(exitCode)))

var sharedApp: Application

proc initApplication*(): Application =
  if sharedApp.isNil:
    result = Application()
    initEmitter(result)
    when defined(macosx) or defined(ios):
      ensurePlatformDispatcher()
      if naAppInit():
        naAppSetCallbacks(
          cast[pointer](result),
          onStartedTrampoline,
          onActivatedTrampoline,
          onDeactivatedTrampoline,
          onQuitRequestedTrampoline,
          onExitingTrampoline)
        result.emit(newApplicationStartedEvent())
    sharedApp = result
  else:
    result = sharedApp

proc run*(app: Application): int =
  app.running = true
  when defined(macosx) or defined(ios):
    result = int(naAppRun())
  else:
    result = 0
  app.running = false
  app.emit(newApplicationExitingEvent(result))

proc run*(app: Application, window: Window): int =
  app.primaryWindow = window
  window.show()
  window.focus()
  result = app.run()

proc getPrimaryWindow*(app: Application): Window =
  app.primaryWindow

proc setPrimaryWindow*(app: Application, window: Window) =
  app.primaryWindow = window

proc getAllWindows*(app: Application): seq[Window] =
  sharedWindowManager().getAllWindows()

proc setDockMenu*(app: Application, menu: Menu) =
  ensureMenuCallbacks()
  when defined(macosx) or defined(ios):
    naAppSetDockMenu(menu.nativeKey)

proc clearDockMenu*(app: Application) =
  when defined(macosx) or defined(ios):
    naAppSetDockMenu(0)

proc getDockMenuKey*(app: Application): uint32 =
  when defined(macosx) or defined(ios):
    naAppDockMenu()
  else:
    0

proc quitApp*(app: Application, exitCode = 0) =
  app.exitCode = exitCode
  app.emit(newApplicationQuitRequestedEvent())
  when defined(macosx) or defined(ios):
    naAppQuit()

proc stopApp*(app: Application) =
  when defined(macosx) or defined(ios):
    naAppStop()

proc isRunning*(app: Application): bool =
  app.running

proc isSingleInstance*(app: Application): bool =
  false

proc setIcon*(app: Application, path: string): bool =
  when defined(macosx) or defined(ios):
    naAppSetIcon(path.cstring)
  else:
    false

proc setDockIconVisible*(app: Application, visible: bool): bool =
  when defined(macosx) or defined(ios):
    naAppSetDockIconVisible(visible)
  else:
    false

proc setMenuBarOnly*(app: Application, menuBarOnly: bool): bool =
  ## Menu-bar-only (accessory) apps have no Dock icon or regular windows.
  setDockIconVisible(app, not menuBarOnly)
