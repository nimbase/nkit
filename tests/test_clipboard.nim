import unittest
import nkit
import nkit/clipboard
import nkit/image

let cb = sharedClipboard()

suite "clipboard":
  test "text round-trip":
    let original = cb.getClipboardText()
    defer:
      if original.len > 0:
        cb.setClipboardText(original)
    cb.setClipboardText("nativeapi clipboard test")
    check cb.getClipboardText() == "nativeapi clipboard test"

  test "change count bumps on write":
    let before = cb.clipboardChangeCount()
    cb.setClipboardText("count probe")
    check cb.clipboardChangeCount() >= before + 1

  test "clear empties text":
    cb.setClipboardText("to be cleared")
    cb.clearClipboard()
    check cb.getClipboardText() == ""

  test "file paths round-trip":
    cb.setClipboardFiles(@["/tmp/nativeapi-clip-a.txt",
                           "/tmp/nativeapi-clip-b.txt"])
    let files = cb.getClipboardFiles()
    check files.len == 2
    check files[0] == "/tmp/nativeapi-clip-a.txt"
    check files[1] == "/tmp/nativeapi-clip-b.txt"
    cb.setClipboardFiles(@[])
    check cb.getClipboardFiles().len == 0

  test "image round-trip keeps dimensions":
    let img = fromBase64(
      "iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAAFUlEQVR42mP8z8AARIQB" &
      "EwMDAwMDAwAkBgMBjXJ3GgAAAABJRU5ErkJggg==")
    check img != nil
    cb.setClipboardImage(img)
    let restored = cb.getClipboardImage()
    check restored != nil
    check restored.exists()
    check restored.getSize().width > 0.0
    restored.free()

  test "empty pasteboard yields no image":
    cb.clearClipboard()
    check cb.getClipboardImage() == nil
