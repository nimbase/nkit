when defined(ios):
  import ./platform/ios/uifunctions
elif defined(macosx):
  import ./platform/macos/nsfunctions
elif defined(linux):
  import ./platform/linux/gfunctions

type AppInfo* = ref object

var sharedAppInfoInstance: AppInfo

proc sharedAppInfo*(): AppInfo =
  if sharedAppInfoInstance.isNil:
    sharedAppInfoInstance = AppInfo()
  result = sharedAppInfoInstance

proc getName*(info: AppInfo): string =
  when defined(macosx) or defined(ios) or defined(linux):
    $naAppInfoName()
  else:
    ""

proc getIdentifier*(info: AppInfo): string =
  when defined(macosx) or defined(ios) or defined(linux):
    $naAppInfoIdentifier()
  else:
    ""

proc getVersion*(info: AppInfo): string =
  when defined(macosx) or defined(ios) or defined(linux):
    $naAppInfoVersion()
  else:
    ""

proc getBuildNumber*(info: AppInfo): string =
  when defined(macosx) or defined(ios) or defined(linux):
    $naAppInfoBuildNumber()
  else:
    ""
