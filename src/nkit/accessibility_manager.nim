when defined(macosx) or defined(ios):
  import nkit/platform/macos/nsfunctions

proc enableAccessibility*() =
  when defined(macosx) or defined(ios):
    naAccessibilityEnable()

proc isAccessibilityEnabled*(): bool =
  when defined(macosx) or defined(ios):
    naAccessibilityIsEnabled()
  else:
    false
