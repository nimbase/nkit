import nkit/foundation/color
import nkit/foundation/event_emitter
import nkit/gui/view
import nkit/gui/label
import nkit/gui/theme

export view, label

type
  BadgeVariant* = enum
    bvDefault
    bvSecondary
    bvDestructive
    bvOutline
    bvSuccess

  Badge* = ref object of View
    textLabel*: Label
    variantValue*: BadgeVariant

proc badgeBackground(variant: BadgeVariant): Color =
  case variant
  of bvDefault: accentColor()
  of bvSecondary: secondaryLabelColor()
  of bvDestructive: systemRed()
  of bvSuccess: systemGreen()
  of bvOutline: colorTransparent

proc badgeForeground(variant: BadgeVariant): Color =
  case variant
  of bvSecondary: labelColor()
  of bvOutline: accentColor()
  else: colorWhite

proc applyBadgeVariant*(b: Badge, variant: BadgeVariant) =
  b.variantValue = variant
  when defined(macosx) or defined(ios):
    setBackgroundColor(b, badgeBackground(variant))
    if not b.textLabel.isNil:
      setTextColor(b.textLabel, badgeForeground(variant))
      if variant == bvOutline:
        setBorder(b, accentColor(), 1.0)
      else:
        setBorder(b, colorTransparent, 0.0)

proc newBadge*(text: string, variant: BadgeVariant = bvDefault): Badge =
  let base = newPlainView()
  result = Badge(textLabel: nil)
  discard wrapView(result, base.native, base.id)

  let label = newLabel(text)
  result.textLabel = label
  label.setFontSize(11.0)
  label.setFontWeight(fwMedium)
  addSubview(result, label)
  fillParent(label, left = 8.0, top = 3.0, right = 8.0, bottom = 3.0)

  setCornerRadius(result, 9.0)
  applyBadgeVariant(result, variant)

proc destroy*(b: Badge) =
  freeNative(b)
  shutdownEmitter[GuiEvent](b)

proc setText*(b: Badge, text: string) =
  when defined(macosx) or defined(ios):
    if not b.textLabel.isNil:
      setText(b.textLabel, text)

proc getVariant*(b: Badge): BadgeVariant =
  b.variantValue
