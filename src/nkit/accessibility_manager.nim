when defined(ios):
  import nkit/platform/ios/uifunctions
elif defined(macosx):
  import nkit/platform/macos/nsfunctions

proc enableAccessibility*() =
  when defined(macosx) and not defined(ios):
    naAccessibilityEnable()

proc isAccessibilityEnabled*(): bool =
  when defined(macosx) and not defined(ios):
    naAccessibilityIsEnabled()
  else:
    false
