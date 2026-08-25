when defined(macosx) or defined(ios):
  import nkit/platform/macos/nsfunctions

type AppInfo* = ref object

var sharedAppInfoInstance: AppInfo

proc sharedAppInfo*(): AppInfo =
  if sharedAppInfoInstance.isNil:
    sharedAppInfoInstance = AppInfo()
  result = sharedAppInfoInstance

proc getName*(info: AppInfo): string =
  when defined(macosx) or defined(ios):
    $naAppInfoName()
  else:
    ""

proc getIdentifier*(info: AppInfo): string =
  when defined(macosx) or defined(ios):
    $naAppInfoIdentifier()
  else:
    ""

proc getVersion*(info: AppInfo): string =
  when defined(macosx) or defined(ios):
    $naAppInfoVersion()
  else:
    ""

proc getBuildNumber*(info: AppInfo): string =
  when defined(macosx) or defined(ios):
    $naAppInfoBuildNumber()
  else:
    ""
