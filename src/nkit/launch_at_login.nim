when defined(macosx) or defined(ios):
  import nkit/platform/macos/nsfunctions

type LaunchAtLogin* = ref object
  id*: string
  displayName*: string
  programPath*: string
  arguments*: seq[string]
  defaultId*: string
  defaultProgramPath*: string

var defaultIdCache: string
var defaultDisplayNameCache: string
var defaultProgramPathCache: string

proc detectDefaults() =
  when defined(macosx) or defined(ios):
    if defaultIdCache.len == 0:
      defaultIdCache = $naLalDefaultId()
      defaultDisplayNameCache = $naLalDefaultDisplayName()
      defaultProgramPathCache = $naLalDefaultProgramPath()

proc isSupported*(): bool =
  when defined(macosx) or defined(ios):
    naLalIsSupported()
  else:
    false

proc newLaunchAtLogin*(id = "", displayName = ""): LaunchAtLogin =
  detectDefaults()
  result = LaunchAtLogin(
    id: if id.len > 0: id else: defaultIdCache,
    displayName: if displayName.len > 0: displayName else: defaultDisplayNameCache,
    programPath: defaultProgramPathCache,
    arguments: @[],
    defaultId: defaultIdCache,
    defaultProgramPath: defaultProgramPathCache)

proc getId*(l: LaunchAtLogin): string =
  l.id

proc getDisplayName*(l: LaunchAtLogin): string =
  l.displayName

proc setDisplayName*(l: LaunchAtLogin, displayName: string): bool =
  l.displayName = displayName
  true

proc setProgram*(l: LaunchAtLogin, executablePath: string, arguments: seq[string] = @[]): bool =
  l.programPath = executablePath
  l.arguments = arguments
  true

proc getExecutablePath*(l: LaunchAtLogin): string =
  l.programPath

proc getArguments*(l: LaunchAtLogin): seq[string] =
  l.arguments

proc canUseConfiguredProgram(l: LaunchAtLogin): bool =
  if l.arguments.len != 0:
    return false
  l.programPath.len == 0 or l.programPath == l.defaultProgramPath

proc enable*(l: LaunchAtLogin): bool =
  when defined(macosx) or defined(ios):
    if not l.canUseConfiguredProgram():
      return false
    naLalEnable(l.id.cstring)
  else:
    false

proc disable*(l: LaunchAtLogin): bool =
  when defined(macosx) or defined(ios):
    naLalDisable(l.id.cstring)
  else:
    false

proc isEnabled*(l: LaunchAtLogin): bool =
  when defined(macosx) or defined(ios):
    naLalIsEnabled(l.id.cstring)
  else:
    false
