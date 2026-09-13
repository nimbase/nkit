import std/posix

when defined(ios):
  import ./platform/ios/uifunctions
elif defined(macosx):
  import ./platform/macos/nsfunctions
elif defined(linux):
  import ./platform/linux/gfunctions

type DeviceInfo* = ref object

var sharedDeviceInfoInstance: DeviceInfo

proc sharedDeviceInfo*(): DeviceInfo =
  if sharedDeviceInfoInstance.isNil:
    sharedDeviceInfoInstance = DeviceInfo()
  result = sharedDeviceInfoInstance

proc unameField(field: openArray[char]): string =
  let s = cstring(unsafeAddr field[0])
  if s.len > 0:
    $s
  else:
    ""

proc getName*(info: DeviceInfo): string =
  when defined(macosx) or defined(ios) or defined(linux):
    $naDeviceInfoName()
  else:
    ""

proc getModel*(info: DeviceInfo): string =
  when defined(macosx) or defined(ios) or defined(linux):
    $naDeviceInfoModel()
  else:
    ""

proc getManufacturer*(info: DeviceInfo): string =
  when defined(macosx) or defined(ios) or defined(linux):
    "Apple"
  elif defined(windows):
    ""
  else:
    ""

proc getOsName*(info: DeviceInfo): string =
  when defined(macosx) or defined(ios) or defined(linux):
    "macOS"
  elif defined(windows):
    "Windows"
  elif defined(linux):
    "Linux"
  else:
    ""

proc getOsVersion*(info: DeviceInfo): string =
  when defined(macosx) or defined(ios) or defined(linux):
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
