when defined(ios):
  import ./platform/ios/uifunctions
elif defined(macosx):
  import ./platform/macos/nsfunctions
elif defined(linux):
  import ./platform/linux/gfunctions

proc enableAccessibility*() =
  when defined(macosx) or defined(linux):
    naAccessibilityEnable()

proc isAccessibilityEnabled*(): bool =
  when defined(macosx) or defined(linux):
    naAccessibilityIsEnabled()
  else:
    false
