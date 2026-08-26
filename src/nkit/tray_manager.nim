import std/tables
import nkit/foundation/object_registry
import nkit/tray_icon

type TrayManager* = ref object
  objects: ObjectRegistry[TrayIcon]

var sharedTrayManagerInstance: TrayManager

proc isSupported*(tm: TrayManager): bool =
  when defined(macosx) and not defined(ios):
    true
  else:
    false

proc get*(tm: TrayManager, id: TrayIconId): TrayIcon =
  tm.objects.get(id.uint32)

proc getAll*(tm: TrayManager): seq[TrayIcon] =
  tm.objects.getAll()

proc remove*(tm: TrayManager, id: TrayIconId): bool =
  tm.objects.remove(id.uint32)

proc len*(tm: TrayManager): int =
  tm.objects.len()

proc shutdown*(tm: TrayManager) =
  for tray in tm.getAll():
    discard tray.setVisible(false)
    tray.setContextMenu(nil)
  tm.objects.clear()

proc sharedTrayManager*(): TrayManager =
  if sharedTrayManagerInstance.isNil:
    result = TrayManager(objects: newObjectRegistry[TrayIcon]())
    sharedTrayManagerInstance = result
  else:
    result = sharedTrayManagerInstance

proc createTray*(tm: TrayManager): TrayIcon =
  result = newTrayIcon()
  tm.objects.add(result.id.uint32, result)
  when defined(macosx) and not defined(ios):
    if globalTrayClickSink.isNil:
      let manager = tm
      globalTrayClickSink = proc(trayKey: uint32, kind: int) =
        let tray = manager.get(trayKey.TrayIconId)
        if not tray.isNil:
          tray.dispatchTrayEvent(kind)
          case kind
          of 0:
            if tray.trigger == cmtClicked:
              discard tray.openContextMenu()
          of 1:
            if tray.trigger == cmtRightClicked:
              discard tray.openContextMenu()
          of 2:
            if tray.trigger == cmtDoubleClicked:
              discard tray.openContextMenu()
          else:
            discard
