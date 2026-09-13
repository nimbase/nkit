import std/tables
when defined(ios):
  import ../platform/ios/uifunctions
elif defined(macosx):
  import ../platform/macos/nsfunctions
elif defined(linux):
  import ../platform/linux/gfunctions

## Shared dispatcher for NAHoverView clicks so multiple components can use
## hover-backed rows without overwriting each other's global callback slot.

var handlers = initTable[uint32, proc()]()
var armed = false

when defined(macosx) or defined(linux):
  proc hoverRouterTrampoline(widgetId: uint32, ctx: pointer) {.cdecl.} =
    let h = handlers.getOrDefault(widgetId)
    if not h.isNil:
      h()

proc ensureHoverRouter*() =
  when defined(macosx) or defined(linux):
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
  when defined(macosx) or defined(linux):
    ensureHoverRouter()
    naHoverViewFire(widgetId)
