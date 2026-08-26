import std/tables
import nkit/gui/layout
import nkit/dialog
when defined(ios):
  import nkit/platform/ios/uifunctions
elif defined(macosx):
  import nkit/platform/macos/nsfunctions

export layout

type
  AlertStyle* = enum
    asInfo
    asWarning
    asCritical

  AlertDialog* = ref object of Dialog
    titleValue*: string
    messageValue*: string
    styleValue*: AlertStyle
    handle: int64

  AlertID* = ref object
    ## Handle passed to button callbacks; call `close` to dismiss the alert.
    handle: int64

var nextAlertButtonId: uint32 = 1
var alertButtonProcs = initTable[uint32, proc(id: AlertID)]()
var alertButtonOrder = initTable[int64, seq[uint32]]()
var alertCallbacksArmed = false

when defined(macosx) and not defined(ios):
  proc alertClickTrampoline(handle: int64, widgetId: cuint, ctx: pointer) {.cdecl.} =
    let wid = uint32(widgetId)
    if alertButtonProcs.hasKey(wid):
      alertButtonProcs[wid](AlertID(handle: handle))

proc ensureAlertClickCallback() =
  when defined(macosx) and not defined(ios):
    if not alertCallbacksArmed:
      naAlertSetClickCallback(alertClickTrampoline)
      alertCallbacksArmed = true

proc close*(id: AlertID) =
  ## Dismisses the alert, aborting its modal run loop.
  when defined(macosx) and not defined(ios):
    naAlertStopModal(id.handle)

proc newAlertDialog*(title: string, message = "",
                     style: AlertStyle = asInfo): AlertDialog =
  when defined(macosx) and not defined(ios):
    ensureAlertClickCallback()
    let h = naAlertCreate(title.cstring, message.cstring, cint(ord(style)))
  else:
    let h = int64(0)
  result = AlertDialog(
    modality: dmNone,
    titleValue: title,
    messageValue: message,
    styleValue: style,
    handle: h)

proc addButton*(a: AlertDialog, label: string,
                onClick: proc(id: AlertID) = nil,
                isDefault = false): AlertDialog {.discardable.} =
  ## Appends a button; onClick receives an `AlertID` that can close the alert.
  ## Returns self for fluent chaining.
  when defined(macosx) and not defined(ios):
    let wid = nextAlertButtonId
    inc nextAlertButtonId
    if not onClick.isNil:
      alertButtonProcs[wid] = onClick
    naAlertAddButton(a.handle, label.cstring, isDefault, wid)
    if not alertButtonOrder.hasKey(a.handle):
      alertButtonOrder[a.handle] = @[]
    alertButtonOrder[a.handle].add(wid)
  a

func buttonCount*(a: AlertDialog): int =
  when defined(macosx) and not defined(ios):
    int(naAlertButtonCount(a.handle))
  else:
    0

proc withContent*(a: AlertDialog, child: ViewNode): AlertDialog {.discardable.} =
  ## Sets arbitrary widget content as the alert's accessory view.
  when defined(macosx) and not defined(ios):
    naAlertSetAccessoryView(a.handle, child.view.native)
  a

method open*(a: AlertDialog): bool {.discardable.} =
  ## Runs the alert modally. Returns true when a registered button fired.
  when defined(macosx) and not defined(ios):
    if a.handle == 0:
      return false
    naAlertRunModal(a.handle) >= 0
  else:
    false

method close*(a: AlertDialog): bool =
  false

proc destroy*(a: AlertDialog) =
  when defined(macosx) and not defined(ios):
    naAlertDestroy(a.handle)

proc fireAlertButtonSimulated*(a: AlertDialog, ordinal: int) =
  ## Test hook: presses a registered button through the callback pipeline.
  when defined(macosx) and not defined(ios):
    if alertButtonOrder.hasKey(a.handle) and
        ordinal >= 0 and ordinal < alertButtonOrder[a.handle].len:
      let wid = alertButtonOrder[a.handle][ordinal]
      if alertButtonProcs.hasKey(wid):
        alertButtonProcs[wid](AlertID(handle: a.handle))
