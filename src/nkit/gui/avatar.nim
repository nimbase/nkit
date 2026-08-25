import std/strutils
import nkit/foundation/color
import nkit/foundation/event_emitter
import nkit/gui/view
import nkit/gui/label
import nkit/gui/imageview
import nkit/gui/theme

export view, label, imageview

type
  AvatarSize* = enum
    asSmall
    asMedium
    asLarge

  Avatar* = ref object of View
    sizeValue*: float64
    imageViewValue*: ImageView
    initialsLabel*: Label

proc avatarPointSize(size: AvatarSize): float64 =
  case size
  of asSmall: 24.0
  of asMedium: 40.0
  of asLarge: 64.0

proc initialsFor(name: string): string =
  var parts: seq[string]
  for piece in name.split(' '):
    if piece.len > 0:
      parts.add(piece)
  var resultStr = ""
  if parts.len > 0:
    resultStr.add(parts[0][0].toUpperAscii())
    if parts.len > 1:
      resultStr.add(parts[^1][0].toUpperAscii())
  if resultStr.len == 0:
    resultStr = "?"
  resultStr

proc newAvatar*(size: AvatarSize = asMedium): Avatar =
  let pointSize = avatarPointSize(size)
  let base = newPlainView()
  result = Avatar(sizeValue: pointSize)
  discard wrapView(result, base.native, base.id)
  setBackgroundColor(result, controlBackgroundColor())

proc setImage*(av: Avatar, img: Image) =
  ## Displays an image clipped to a circle.
  when defined(macosx) or defined(ios):
    if av.imageViewValue.isNil:
      let iv = newImageView()
      av.imageViewValue = iv
      addSubview(av, View(iv))
      fillParent(View(iv))
    setCornerRadius(View(av.imageViewValue), av.sizeValue / 2.0)
    setImage(av.imageViewValue, img)
    if not av.initialsLabel.isNil:
      setHidden(av.initialsLabel, true)

proc setInitials*(av: Avatar, name: string) =
  ## Shows circular monogram initials derived from the given name.
  when defined(macosx) or defined(ios):
    if av.initialsLabel.isNil:
      let lbl = newLabel(initialsFor(name))
      av.initialsLabel = lbl
      lbl.setAlignment(laCenter)
      lbl.setFontWeight(fwMedium)
      lbl.setTextColor(labelColor())
      addSubview(av, View(lbl))
      fillParent(View(lbl))
    else:
      setText(av.initialsLabel, initialsFor(name))
    setCornerRadius(av, av.sizeValue / 2.0)
    constrainSize(av, av.sizeValue, av.sizeValue)
    setHidden(av.initialsLabel, false)
    if not av.imageViewValue.isNil:
      av.imageViewValue.clearImage()

proc getSize*(av: Avatar): float64 =
  av.sizeValue

proc destroy*(av: Avatar) =
  freeNative(av)
  shutdownEmitter[GuiEvent](av)
