import ./foundation/event_emitter
import ./dialog

when defined(ios):
  import ./platform/ios/uifunctions
elif defined(macosx):
  import ./platform/macos/nsfunctions
elif defined(linux):
  import ./platform/linux/gfunctions

type MessageDialog* = ref object of Dialog
  titleValue*: string
  messageValue*: string
  handle: int64

proc newMessageDialog*(title: string, message: string): MessageDialog =
  when defined(macosx) or defined(linux):
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
  when defined(macosx) or defined(linux):
    naDialogSetTitle(d.handle, title.cstring)

proc getTitle*(d: MessageDialog): string =
  d.titleValue

proc setMessage*(d: MessageDialog, message: string) =
  d.messageValue = message
  when defined(macosx) or defined(linux):
    naDialogSetMessage(d.handle, message.cstring)

proc getMessage*(d: MessageDialog): string =
  d.messageValue

proc isOpen*(d: MessageDialog): bool =
  when defined(macosx) or defined(linux):
    naDialogIsOpen(d.handle)
  else:
    false

method open*(d: MessageDialog): bool =
  when defined(macosx) or defined(linux):
    if d.handle == 0:
      return false
    naDialogRunModal(d.handle)
    true
  else:
    false

method close*(d: MessageDialog): bool =
  when defined(macosx) or defined(linux):
    naDialogClose(d.handle)
  else:
    false

proc destroy*(d: MessageDialog) =
  when defined(macosx) or defined(linux):
    naDialogDestroy(d.handle)
