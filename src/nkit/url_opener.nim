import std/strutils

when defined(ios):
  import nkit/platform/ios/uifunctions
elif defined(macosx):
  import nkit/platform/macos/nsfunctions

type
  UrlOpenErrorCode* = enum
    uoeNone
    uoeInvalidUrlEmpty
    uoeInvalidUrlMissingScheme
    uoeInvalidUrlUnsupportedScheme
    uoeUnsupportedPlatform
    uoeInvocationFailed

  UrlOpenResult* = object
    success*: bool
    errorCode*: UrlOpenErrorCode
    errorMessage*: string

type UrlOpener* = ref object

var sharedUrlOpenerInstance: UrlOpener

proc sharedUrlOpener*(): UrlOpener =
  if sharedUrlOpenerInstance.isNil:
    sharedUrlOpenerInstance = UrlOpener()
  result = sharedUrlOpenerInstance

proc isSupported*(opener: UrlOpener): bool =
  when defined(macosx) and not defined(ios):
    true
  else:
    false

proc validate(url: string): UrlOpenResult =
  let trimmed = url.strip()
  if trimmed.len == 0:
    return UrlOpenResult(
      success: false,
      errorCode: uoeInvalidUrlEmpty,
      errorMessage: "URL is empty.")
  let separator = trimmed.find(':')
  if separator <= 0:
    return UrlOpenResult(
      success: false,
      errorCode: uoeInvalidUrlMissingScheme,
      errorMessage: "URL must include an explicit scheme (http or https).")
  let scheme = trimmed[0 ..< separator].toLowerAscii()
  if scheme != "http" and scheme != "https":
    return UrlOpenResult(
      success: false,
      errorCode: uoeInvalidUrlUnsupportedScheme,
      errorMessage: "Only http and https URLs are supported.")
  UrlOpenResult(success: true, errorCode: uoeNone)

proc canOpen*(opener: UrlOpener, url: string): bool =
  validate(url).success

proc open*(opener: UrlOpener, url: string): UrlOpenResult =
  let validated = validate(url)
  if not validated.success:
    return validated
  when defined(macosx) and not defined(ios):
    var errBuf: array[256, char]
    let opened = naUrlOpen(url.cstring, cast[cstring](addr errBuf[0]), cint(errBuf.len))
    if opened:
      return UrlOpenResult(success: true, errorCode: uoeNone)
    var message = "Failed to open URL."
    let len = cstring(addr errBuf[0]).len
    if len > 0:
      message = $cstring(addr errBuf[0])
    return UrlOpenResult(success: false, errorCode: uoeInvocationFailed, errorMessage: message)
  else:
    return UrlOpenResult(
      success: false,
      errorCode: uoeUnsupportedPlatform,
      errorMessage: "URL opening is not supported on this platform.")
