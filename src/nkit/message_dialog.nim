import nkit/foundation/event_emitter
import nkit/dialog

when defined(ios):
  import nkit/platform/ios/uifunctions
elif defined(macosx):
  import nkit/platform/macos/nsfunctions

type MessageDialog* = ref object of Dialog
  titleValue*: string
  messageValue*: string
  handle: int64

proc newMessageDialog*(title: string, message: string): MessageDialog =
  when defined(macosx) and not defined(ios):
    let h = naDialogCreate(title.cstring, message.cstring)
  else:
    let h = int64(0)
  result = MessageDialog(
    modality: dmNone,
    titleValue: title,
    messageValue: message,
    handle: h)

proc setTitle*(d: MessageDialog, title: string) =
  d.titleValue = title
  when defined(macosx) and not defined(ios):
    naDialogSetTitle(d.handle, title.cstring)

proc getTitle*(d: MessageDialog): string =
  d.titleValue

proc setMessage*(d: MessageDialog, message: string) =
  d.messageValue = message
  when defined(macosx) and not defined(ios):
    naDialogSetMessage(d.handle, message.cstring)

proc getMessage*(d: MessageDialog): string =
  d.messageValue

proc isOpen*(d: MessageDialog): bool =
  when defined(macosx) and not defined(ios):
    naDialogIsOpen(d.handle)
  else:
    false

method open*(d: MessageDialog): bool =
  when defined(macosx) and not defined(ios):
    if d.handle == 0:
      return false
    naDialogRunModal(d.handle)
    true
  else:
    false

method close*(d: MessageDialog): bool =
  when defined(macosx) and not defined(ios):
    naDialogClose(d.handle)
  else:
    false

proc destroy*(d: MessageDialog) =
  when defined(macosx) and not defined(ios):
    naDialogDestroy(d.handle)
