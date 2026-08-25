import std/tables
import nkit/foundation/event
import nkit/gui/view
import nkit/gui/hover_router
import nkit/platform/macos/nsfunctions

export view

## File drag-and-drop onto any plain view. The C side reports drops through
## one global callback slot; this router dispatches by widget id so any
## number of views can accept files simultaneously.

var dropHandlers = initTable[uint32, proc(paths: seq[string])]()
var armed = false

when defined(macosx) or defined(ios):
  proc dropTrampoline(widgetId: cuint, paths: ptr cstring, count: cint,
                      ctx: pointer) {.cdecl.} =
    let handler = dropHandlers.getOrDefault(uint32(widgetId))
    if handler.isNil:
      return
    var files: seq[string] = @[]
    if count > 0 and not paths.isNil:
      let arr = cast[ptr UncheckedArray[cstring]](paths)
      for i in 0 ..< int(count):
        files.add($arr[i])
    handler(files)

proc ensureDropRouter*() =
  when defined(macosx) or defined(ios):
    if not armed:
      naDropSetEventCallback(dropTrampoline, nil)
      armed = true

proc enableFileDrop*(v: View, handler: proc(paths: seq[string])) =
  ## Registers the view as a drop target for file URLs.
  ensureDropRouter()
  when defined(macosx) or defined(ios):
    naViewSetDropEnabled(v.native, true, v.id.uint32)
    dropHandlers[v.id.uint32] = handler

proc disableFileDrop*(v: View) =
  when defined(macosx) or defined(ios):
    naViewSetDropEnabled(v.native, false, v.id.uint32)
    dropHandlers.del(v.id.uint32)

proc simulateFileDrop*(v: View, paths: seq[string]) =
  ## Test hook: feeds paths through the router as if the user dropped them.
  when defined(macosx) or defined(ios):
    var cstrs: seq[cstring] = @[]
    for p in paths:
      cstrs.add(p.cstring)
    dropTrampoline(cuint(v.id.uint32), addr cstrs[0], cint(cstrs.len), nil)
