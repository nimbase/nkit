import unittest
import nkit/gui/popover
import nkit/gui/view
import nkit/foundation/event_emitter
import nkit/foundation/dispatcher

suite "popover":
  test "content view hosts children":
    let pop = newPopover(260.0, 180.0)
    defer:
      pop.destroy()
    check pop.id.uint32 != 0
    let child = newPlainView()
    addSubview(pop, child)
    check subviewCount(pop) == 1

  test "closed event fires through the pipeline":
    let pop = newPopover()
    defer:
      pop.destroy()
    var closedCount = 0
    discard onClosed(pop, proc(e: PopoverClosedEvent) =
      closedCount += 1)
    # Simulate the C-side close notification.
    fireClosedSimulated(pop)
    discard runMainThreadLoopFor(80)
    check closedCount == 1

  test "show/hide state without anchor stays safe":
    let pop = newPopover()
    defer:
      pop.destroy()
    check isShown(pop) == false
