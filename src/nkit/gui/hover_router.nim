import std/tables
when defined(ios):
  import nkit/platform/ios/uifunctions
elif defined(macosx):
  import nkit/platform/macos/nsfunctions

## Shared dispatcher for NAHoverView clicks so multiple components can use
## hover-backed rows without overwriting each other's global callback slot.

var handlers = initTable[uint32, proc()]()
var armed = false

when defined(macosx) and not defined(ios):
  proc hoverRouterTrampoline(widgetId: uint32, ctx: pointer) {.cdecl.} =
    let h = handlers.getOrDefault(widgetId)
    if not h.isNil:
      h()

proc ensureHoverRouter*() =
  when defined(macosx) and not defined(ios):
    if not armed:
      naHoverSetEventCallback(hoverRouterTrampoline, nil)
      armed = true

proc registerHoverHandler*(widgetId: uint32, handler: proc()) =
  ensureHoverRouter()
  handlers[widgetId] = handler

proc unregisterHoverHandler*(widgetId: uint32) =
  handlers.del(widgetId)

proc fireHoverHandler*(widgetId: uint32) =
  ## Test hook: simulates a click on the hover-backed view.
  when defined(macosx) and not defined(ios):
    ensureHoverRouter()
    naHoverViewFire(widgetId)
