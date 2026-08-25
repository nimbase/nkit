import nkit/foundation/color
import nkit/foundation/event
import nkit/foundation/event_emitter
import nkit/gui/view

when defined(macosx) or defined(ios):
  import nkit/platform/macos/nsfunctions

export color

type
  AppearanceChangedEvent* = ref object of GuiEvent

  Theme* = ref object of EventEmitter[GuiEvent]
    armed: bool

var sharedThemeInstance*: Theme

proc newAppearanceChangedEvent*(): AppearanceChangedEvent =
  result = new(AppearanceChangedEvent)
  discard stamp(result)

proc themeChangedTrampoline(ctx: pointer) {.cdecl.} =
  let t = cast[Theme](ctx)
  if not t.isNil:
    emitAsync(t, newAppearanceChangedEvent())

proc sharedTheme*(): Theme =
  if sharedThemeInstance.isNil:
    sharedThemeInstance = Theme()
    initEmitter(sharedThemeInstance)
  result = sharedThemeInstance

proc ensureThemeCallback(t: Theme) =
  when defined(macosx) or defined(ios):
    if not t.armed:
      naThemeSetChangedCallback(themeChangedTrampoline, cast[pointer](t))
      t.armed = true

proc onAppearanceChanged*(handler: proc(e: AppearanceChangedEvent)): ListenerId =
  let t = sharedTheme()
  ensureThemeCallback(t)
  t.addListener(handler)

proc triggerAppearanceChanged*() =
  let t = sharedTheme()
  emitAsync(t, newAppearanceChangedEvent())

proc isDarkMode*(): bool =
  when defined(macosx) or defined(ios):
    naThemeIsDark()
  else:
    false

template themeColorGetter(name: untyped, getter: untyped) =
  proc name*(): Color =
    var r, g, b, a: uint8
    getter(addr r, addr g, addr b, addr a)
    Color(r: r, g: g, b: b, a: a)

when defined(macosx) or defined(ios):
  themeColorGetter(accentColor, naThemeAccentColor)
  themeColorGetter(labelColor, naThemeLabelColor)
  themeColorGetter(secondaryLabelColor, naThemeSecondaryLabelColor)
  themeColorGetter(tertiaryLabelColor, naThemeTertiaryLabelColor)
  themeColorGetter(quaternaryLabelColor, naThemeQuaternaryLabelColor)
  themeColorGetter(placeholderTextColor, naThemePlaceholderTextColor)
  themeColorGetter(controlTextColor, naThemeControlTextColor)
  themeColorGetter(windowBackgroundColor, naThemeWindowBackgroundColor)
  themeColorGetter(controlBackgroundColor, naThemeControlBackgroundColor)
  themeColorGetter(textBackgroundColor, naThemeTextBackgroundColor)
  themeColorGetter(separatorColor, naThemeSeparatorColor)
  themeColorGetter(selectedContentColor, naThemeSelectedContentColor)
  themeColorGetter(systemRed, naThemeSystemRed)
  themeColorGetter(systemGreen, naThemeSystemGreen)
  themeColorGetter(systemBlue, naThemeSystemBlue)
  themeColorGetter(systemOrange, naThemeSystemOrange)
  themeColorGetter(systemYellow, naThemeSystemYellow)
  themeColorGetter(systemPurple, naThemeSystemPurple)
  themeColorGetter(systemPink, naThemeSystemPink)
  themeColorGetter(systemTeal, naThemeSystemTeal)
  themeColorGetter(systemIndigo, naThemeSystemIndigo)
  themeColorGetter(systemMint, naThemeSystemMint)
  themeColorGetter(systemCyan, naThemeSystemCyan)
  themeColorGetter(systemBrown, naThemeSystemBrown)
  themeColorGetter(systemGray, naThemeSystemGray)
