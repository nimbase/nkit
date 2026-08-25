import nkit/foundation/object_registry
import nkit/window

type WindowRegistry* = ref object
  objects: ObjectRegistry[Window]

var sharedWindowRegistryInstance: WindowRegistry

proc sharedWindowRegistry*(): WindowRegistry =
  if sharedWindowRegistryInstance.isNil:
    result = WindowRegistry(objects: newObjectRegistry[Window]())
    sharedWindowRegistryInstance = result
  else:
    result = sharedWindowRegistryInstance

proc add*(reg: WindowRegistry, window: Window) =
  reg.objects.add(window.id.uint32, window)

proc get*(reg: WindowRegistry, id: WindowId): Window =
  reg.objects.get(id.uint32)

proc contains*(reg: WindowRegistry, id: WindowId): bool =
  reg.objects.contains(id.uint32)

proc getAll*(reg: WindowRegistry): seq[Window] =
  reg.objects.getAll()

proc remove*(reg: WindowRegistry, id: WindowId): bool =
  reg.objects.remove(id.uint32)

proc clear*(reg: WindowRegistry) =
  reg.objects.clear()

proc len*(reg: WindowRegistry): int =
  reg.objects.len()
