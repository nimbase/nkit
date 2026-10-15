import std/[os, strutils, osproc]
import ./ios

## App resources for the nkit CLI (macOS/iOS).
##
## Flutter-style: `nkit.yaml` declares `assets` (resource dirs/files) and
## an `icon` (.icns file or .iconset directory). At build time the assets
## are copied into <App>.app/Resources/ preserving their project-relative
## paths, and the icon is placed at the Resources root with CFBundleIconFile
## pointing at it. Runtime lookup therefore uses the Resources prefix, e.g.
## `Bundle.main.path(forResource:ofType:inDirectory:)` with
## inDirectory "assets/images".
##
## Copy/validation helpers are pure filesystem work so they unit test
## without Xcode; only convertIconset shells out to `iconutil`.

func resourcesDirFor*(platform: Platform, outDir, appName: string): string =
  ## Bundle directory that receives assets and the app icon.
  appBundlePath(platform, outDir, appName) / "Resources"

proc resolveInside(projectDir, entry: string): string =
  ## Resolves a yaml-declared path against the project root, rejecting
  ## absolute paths and `..` escapes. Raises ValueError.
  if entry.len == 0:
    raise newException(ValueError, "empty asset path")
  if isAbsolute(entry):
    raise newException(ValueError,
      "asset paths must be relative to the project root: " & entry)
  let base = absolutePath(projectDir)
  result = absolutePath(base / entry)
  if result != base and not result.startsWith(base & DirSep):
    raise newException(ValueError,
      "asset path escapes the project root: " & entry)

proc copyAssets*(projectDir: string, assets: seq[string],
                 destDir: string): int =
  ## Copies each entry into `destDir`, preserving the path relative to
  ## `projectDir` (Flutter parity, avoids name collisions). Directories
  ## contribute their file contents recursively; a lone file entry is
  ## copied as-is. Returns the number of files copied. Raises ValueError
  ## for missing sources, IOError on copy failure.
  for entry in assets:
    if entry.len == 0:
      continue
    let src = resolveInside(projectDir, entry)
    if dirExists(src):
      for rel in walkDirRec(src, yieldFilter = {pcFile}, relative = true):
        let target = destDir / entry / rel
        createDir(parentDir(target))
        copyFile(src / rel, target)
        inc result
    elif fileExists(src):
      let target = destDir / entry
      createDir(parentDir(target))
      copyFile(src, target)
      inc result
    else:
      raise newException(ValueError, "asset not found: " & entry)

proc iconPlistName*(projectDir, iconPath: string): string =
  ## Validates the `icon` setting and derives the CFBundleIconFile value
  ## (file/dir name without extension). Accepts a .icns file or a
  ## .iconset directory; raises ValueError otherwise.
  if iconPath.len == 0:
    raise newException(ValueError, "empty icon path")
  let src = resolveInside(projectDir, iconPath)
  let (_, name, ext) = splitFile(src)
  if fileExists(src) and ext == ".icns":
    return name
  if dirExists(src) and ext == ".iconset":
    return name
  raise newException(ValueError,
    "icon must be a .icns file or a .iconset directory: " & iconPath)

proc convertIconset*(iconsetPath, outIcns: string) =
  ## Converts an .iconset directory with Apple's `iconutil`. Raises
  ## ValueError when iconutil reports failure.
  let code = execCmd("iconutil -c icns \"" & iconsetPath &
    "\" -o \"" & outIcns & "\"")
  if code != 0:
    raise newException(ValueError,
      "iconutil failed to convert " & iconsetPath)

proc installIcon*(projectDir, iconPath, destDir: string): string =
  ## Copies (.icns) or converts (.iconset) the app icon into `destDir`,
  ## returning the CFBundleIconFile value for Info.plist.
  let name = iconPlistName(projectDir, iconPath)
  let src = absolutePath(projectDir / iconPath)
  let target = destDir / (name & ".icns")
  if dirExists(src):
    convertIconset(src, target)
  else:
    copyFile(src, target)
  result = name
