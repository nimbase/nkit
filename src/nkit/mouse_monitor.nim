import std/[sequtils]
import nkit/foundation/event
import nkit/foundation/geometry
import nkit/foundation/event_emitter

when defined(macosx) or defined(ios):
  import nkit/platform/macos/nsfunctions

export geometry

type
  MouseActivityKind* = enum
    makMoved
    makLeftDown
    makLeftUp
    makRightDown
    makRightUp
    makOtherDown
    makOtherUp
    makScrollWheel

  MouseEvent* = ref object of Event
    kind*: MouseActivityKind
    position*: Point
    clickCount*: int
    global*: bool

  MouseMonitor* = ref object of EventEmitter[MouseEvent]
    runningValue*: bool
    globalValue*: bool

var activeMonitors: seq[MouseMonitor] = @[]

method typeName(e: MouseEvent): string = "MouseEvent"

proc newMouseEvent*(kind: MouseActivityKind, position: Point,
                    clickCount: int, isGlobal: bool): MouseEvent =
  result = MouseEvent(kind: kind, position: position,
                      clickCount: clickCount, global: isGlobal)
  discard stamp(result)

when defined(macosx) or defined(ios):
  proc mouseTrampoline(kind: cint, x: cdouble, y: cdouble,
                       clicks: cint, ctx: pointer) {.cdecl.} =
    if kind < 0 or kind > ord(high(MouseActivityKind)):
      return
    let k = cast[MouseActivityKind](kind)
    for m in activeMonitors:
      m.emit(newMouseEvent(k, point(x, y), clicks, m.globalValue))

proc newMouseMonitor*(): MouseMonitor =
  result = MouseMonitor(runningValue: false, globalValue: false)
  initEmitter(result)

proc startGlobal*(m: MouseMonitor): bool =
  ## System-wide monitor. macOS never delivers this app's own events here.
  if m.runningValue:
    return true
  when defined(macosx) or defined(ios):
    if naMouseStartMonitor(true, mouseTrampoline, nil):
      m.runningValue = true
      m.globalValue = true
      if m notin activeMonitors:
        activeMonitors.add(m)
      return true
    return false
  else:
    false

proc startLocal*(m: MouseMonitor): bool =
  ## Monitors events targeting our own windows.
  if m.runningValue:
    return true
  when defined(macosx) or defined(ios):
    if naMouseStartMonitor(false, mouseTrampoline, nil):
      m.runningValue = true
      m.globalValue = false
      if m notin activeMonitors:
        activeMonitors.add(m)
      return true
    return false
  else:
    false

proc stop*(m: MouseMonitor) =
  when defined(macosx) or defined(ios):
    if m.runningValue:
      naMouseStopMonitors()
      m.runningValue = false
      let idx = activeMonitors.find(m)
      if idx >= 0:
        activeMonitors.delete(idx)

proc isMonitoring*(m: MouseMonitor): bool =
  m.runningValue

proc onMouseMove*(m: MouseMonitor,
                  handler: proc(e: MouseEvent)): ListenerId =
  addListener[MouseEvent, MouseEvent](m, proc(e: MouseEvent) =
    if e.kind == makMoved:
      handler(e))

proc onMouseButton*(m: MouseMonitor,
                    handler: proc(e: MouseEvent)): ListenerId =
  addListener[MouseEvent, MouseEvent](m, proc(e: MouseEvent) =
    if e.kind != makMoved and e.kind != makScrollWheel:
      handler(e))

proc fireMouseSimulated*(kind: int, x, y: float64, clicks: int) =
  ## Test hook: feeds an event through the monitor pipeline as if the OS
  ## had delivered it.
  when defined(macosx) or defined(ios):
    mouseTrampoline(cint(kind), cdouble(x), cdouble(y), cint(clicks), nil)

proc isGlobal*(m: MouseMonitor): bool =
  m.runningValue and m.globalValue
