import unittest
import nkit
import nkit/mouse_monitor
import nkit/foundation/event_emitter
import nkit/foundation/dispatcher

suite "mouse monitor":
  test "start/stop lifecycle (local)":
    let mon = newMouseMonitor()
    check mon.isMonitoring() == false
    check mon.startLocal() == true
    check mon.isMonitoring() == true
    check mon.isGlobal() == false
    mon.stop()
    check mon.isMonitoring() == false
    # restart on the other channel works after stop
    check mon.startGlobal() == true
    check mon.isGlobal() == true
    mon.stop()
    check mon.isMonitoring() == false

  test "double start is idempotent":
    let mon = newMouseMonitor()
    check mon.startLocal() == true
    check mon.startLocal() == true
    mon.stop()

  test "event pipeline delivers via trampoline simulation":
    let mon = newMouseMonitor()
    var received = 0
    discard addListener[MouseEvent, MouseEvent](mon, proc(e: MouseEvent) =
      received += 1)
    check mon.startLocal() == true
    # Simulate the C trampoline firing as if a click happened.
    fireMouseSimulated(int(makLeftDown), 120.0, 80.0, 1)
    discard runMainThreadLoopFor(100)
    check received == 1
    mon.stop()
