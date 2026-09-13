import ../foundation/event_emitter
import ./view
import ../image

when defined(ios):
  import ../platform/ios/uifunctions
elif defined(macosx):
  import ../platform/macos/nsfunctions
elif defined(linux):
  import ../platform/linux/gfunctions

export view, image

type
  ImageViewScaling* = enum
    ivsProportionally
    ivsFit
    ivsStretch

  ImageView* = ref object of View

proc newImageView*(): ImageView =
  when defined(macosx) or defined(ios) or defined(linux):
    let nativePtr = naImageViewCreate()
  else:
    let nativePtr: pointer = nil
  result = ImageView()
  discard wrapView(result, nativePtr)

proc destroy*(iv: ImageView) =
  when defined(macosx) or defined(ios) or defined(linux):
    naImageViewFree(iv.native)
    iv.native = nil
  shutdownEmitter[GuiEvent](iv)

proc setImage*(iv: ImageView, img: Image) =
  when defined(macosx) or defined(ios) or defined(linux):
    let nativeImagePtr = if img.isNil: nil else: img.nativePtr()
    naImageViewSetImagePtr(iv.native, nativeImagePtr)

proc setSymbol*(iv: ImageView, symbolName: string, pointSize = 16.0,
                weight = 2) =
  ## SF Symbol name based icon (e.g. "square.and.pencil").
  when defined(macosx) or defined(ios) or defined(linux):
    naImageViewSetSymbol(iv.native, symbolName.cstring, pointSize, cint(weight))

proc clearImage*(iv: ImageView) =
  when defined(macosx) or defined(ios) or defined(linux):
    naImageViewClear(iv.native)

proc setScaling*(iv: ImageView, scaling: ImageViewScaling) =
  when defined(macosx) or defined(ios) or defined(linux):
    naImageViewSetScaling(iv.native, cint(ord(scaling)))
