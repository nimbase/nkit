import std/posix

when defined(ios):
  import nkit/platform/ios/uifunctions
elif defined(macosx):
  import nkit/platform/macos/nsfunctions

type DeviceInfo* = ref object

var sharedDeviceInfoInstance: DeviceInfo

proc sharedDeviceInfo*(): DeviceInfo =
  if sharedDeviceInfoInstance.isNil:
    sharedDeviceInfoInstance = DeviceInfo()
  result = sharedDeviceInfoInstance

proc unameField(field: array[256, char]): string =
  let s = cstring(addr field[0])
  if s.len > 0:
    $s
  else:
    ""

proc getName*(info: DeviceInfo): string =
  when defined(macosx) or defined(ios):
    $naDeviceInfoName()
  else:
    ""

proc getModel*(info: DeviceInfo): string =
  when defined(macosx) or defined(ios):
    $naDeviceInfoModel()
  else:
    ""

proc getManufacturer*(info: DeviceInfo): string =
  when defined(macosx) or defined(ios):
    "Apple"
  elif defined(windows):
    ""
  else:
    ""

proc getOsName*(info: DeviceInfo): string =
  when defined(macosx) or defined(ios):
    "macOS"
  elif defined(windows):
    "Windows"
  elif defined(linux):
    "Linux"
  else:
    ""

proc getOsVersion*(info: DeviceInfo): string =
  when defined(macosx) or defined(ios):
    $naDeviceInfoOsVersion()
  else:
    ""

proc getKernelVersion*(info: DeviceInfo): string =
  var u: Utsname
  if uname(u) == 0:
    result = unameField(u.release)
  else:
    result = ""

proc getArchitecture*(info: DeviceInfo): string =
  var u: Utsname
  if uname(u) == 0:
    result = unameField(u.machine)
  else:
    result = ""
