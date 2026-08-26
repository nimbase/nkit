import unittest
import nkit
import nkit/drag_drop
import nkit/gui/view

suite "drag & drop (file)":
  test "enable routes drops to the registered handler":
    let zone = newPlainView()
    var received: seq[string] = @[]
    var calls = 0
    enableFileDrop(zone, proc(paths: seq[string]) =
      calls += 1
      received = paths)
    simulateFileDrop(zone, @["/tmp/a.txt", "/tmp/b.pdf"])
    check calls == 1
    check received == @["/tmp/a.txt", "/tmp/b.pdf"]
    disableFileDrop(zone)

  test "disabled view ignores drops":
    let zone = newPlainView()
    var calls = 0
    enableFileDrop(zone, proc(paths: seq[string]) =
      calls += 1)
    disableFileDrop(zone)
    simulateFileDrop(zone, @["/tmp/ignored.txt"])
    check calls == 0

  test "two views dispatch independently":
    let a = newPlainView()
    let b = newPlainView()
    var fromA = ""
    var fromB = ""
    enableFileDrop(a, proc(paths: seq[string]) =
      if paths.len > 0:
        fromA = paths[0])
    enableFileDrop(b, proc(paths: seq[string]) =
      if paths.len > 0:
        fromB = paths[0])
    simulateFileDrop(a, @["/tmp/from-a.txt"])
    simulateFileDrop(b, @["/tmp/from-b.txt"])
    check fromA == "/tmp/from-a.txt"
    check fromB == "/tmp/from-b.txt"
