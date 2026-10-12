import std/[os, strutils, sequtils, tables]
import ./ios

## Disk image packaging for the nkit CLI.
##
## Staging a directory and handing it to `hdiutil create -srcfolder` gives
## a mounted volume containing the .app, any extra files the developer adds,
## and the /Applications shortcut, with no Finder scripting or temporary
## code-signing step involved.
##
## Nothing here reads the project configuration: packaging is driven by an
## .app bundle on disk, named by the caller or found by convention, so it
## works in any directory holding a built app.
##
## As in ios.nim, pure builders (entry resolution, argument assembly) are kept
## apart from the process wrappers so they can be unit tested without ever
## invoking hdiutil.

const
  DmgFormatChoices* = ["ULFO", "UDZO", "UDBZ"]
    ## Compression formats offered by hdiutil for a read-only image.
    ## ULFO (lzfse) is the smallest and fastest on any recent macOS, UDZO
    ## (zlib) is the most widely compatible, UDBZ is deprecated.
  DmgFsChoices* = ["HFS+", "APFS"]
    ## Volume filesystems. HFS+ reaches back the furthest, APFS is the
    ## modern default.
  ApplicationsLink* = "Applications"
    ## The drag-to-install shortcut placed at the volume root.
  VolumeIconName* = ".VolumeIcon.icns"
    ## Finder picks this file up automatically when it sits at the root of
    ## the source folder, so passing it with `-f` sets a custom volume icon.
  StageDirName* = ".bundle"
    ## Staging directory, created next to the image so it lands under
    ## `build/` by default and `nkit clean` removes it with the rest

type
  VolumeEntry* = object
    ## One item to be copied to the root of the volume.
    source*: string
      ## Absolute path of the file or directory on disk
    label*: string
      ## Name the item takes at the volume root

func appNameFrom*(bundlePath: string): string =
  ## The app name a bundle carries, i.e. its directory name without the
  ## `.app` extension
  let base = bundlePath.splitPath.tail
  if base.toLowerAscii.endsWith(".app"):
    return base[0 ..< base.len - 4]
  base

proc discoverAppBundle*(outDir = "build"): string =
  ## Finds the app bundle `nkit build macos` left under `outDir`.
  ##
  ## Returns an empty string when there is none. Raises ValueError when the
  ## directory holds several, since guessing which one to ship would be worse
  ## than asking the caller to name it.
  let dir = outDirFor(pfMacos, outDir)
  if not dirExists(dir):
    return ""
  var found: seq[string]
  for kind, path in walkDir(dir):
    if kind == pcDir and path.toLowerAscii.endsWith(".app"):
      found.add path
  case found.len
  of 0: discard
  of 1: result = found[0]
  else:
    var names = found.mapIt(it.splitPath.tail).join(", ")
    raise newException(ValueError,
      "several app bundles under " & dir & " (" & names &
      "); name one: nkit bundle <app>.app")

proc volumeEntries*(appBundle: string, files,
                    dirs: seq[string]): seq[VolumeEntry] =
  ## Resolves the app bundle plus every extra into volume-root entries, in
  ## the order they will be written. Files and directories are flattened to
  ## their basename, extensions and all.
  ##
  ## Raises ValueError when a path does not exist, or when two entries would
  ## claim the same label at the volume root.
  result.add VolumeEntry(
    source: appBundle, label: appBundle.splitPath.tail)
  var seen = initTable[string, string]()
  seen[result[0].label] = appBundle
  for (paths, isDir) in [(files, false), (dirs, true)]:
    for path in paths:
      let
        label = path.splitPath.tail
        exists = if isDir: dirExists(path) else: fileExists(path)
      if label.len == 0:
        raise newException(ValueError,
          "cannot tell what to call " & path & " on the volume")
      if not exists:
        raise newException(ValueError,
          (if isDir: "no such directory: " else: "no such file: ") & path)
      if label in seen:
        raise newException(ValueError,
          label & " is provided twice (" & seen[label] & " and " & path &
          "); the volume root cannot hold both")
      seen[label] = path
      result.add VolumeEntry(source: path, label: label)

func stagePath*(outDir, appName: string): string =
  ## Scratch directory the volume is assembled in, kept beside the image
  outDir / StageDirName / appName

func defaultDmgPath*(appBundle: string): string =
  ## Where the image lands unless `--out` says otherwise: beside the app it
  ## was built from, so `build/macos/Demo.app` yields `build/macos/Demo.dmg`
  parentDir(appBundle) / (appNameFrom(appBundle) & ".dmg")

func composeDmgArgs*(stageDir, volName, outPath: string,
                      imageFormat = "", fs = ""): string =
  ## Assembles the `hdiutil create` invocation.
  ##
  ## `-format` and `-fs` are left out when empty so that hdiutil applies its
  ## own defaults (UDZO, and a filesystem derived from the source folder)
  ## rather than this tool second-guessing them.
  ##
  ## `-anyowners` keeps hdiutil from asking for authentication when the
  ## staging directory holds a file it cannot attribute to the current user.
  result = "hdiutil create -srcfolder \"" & stageDir &
    "\" -volname \"" & volName & "\" -anyowners -ov"
  if imageFormat.len > 0:
    result.add(" -format " & imageFormat)
  if fs.len > 0:
    result.add(" -fs \"" & fs & "\"")
  result.add(" \"" & outPath & "\"")

# --- process wrappers ------------------------------------------------------

proc stageVolume*(stageDir: string, entries: seq[VolumeEntry],
                  applicationsLink = true): seq[string] =
  ## Rebuilds `stageDir` from scratch and fills it with `entries`, followed
  ## by the /Applications symlink. Returns the paths written.
  if dirExists(stageDir):
    removeDir(stageDir)
  createDir(stageDir)
  for entry in entries:
    let dest = stageDir / entry.label
    if dirExists(entry.source):
      copyDir(entry.source, dest)
    else:
      copyFile(entry.source, dest)
    result.add dest
  if applicationsLink:
    let dest = stageDir / ApplicationsLink
    createSymlink("/Applications", dest)
    result.add dest

proc ensureParentDir*(path: string) =
  ## Creates the directory an output path lives in when it is missing;
  ## hdiutil will not do it for us
  let parent = parentDir(path)
  if parent.len > 0 and not dirExists(parent):
    createDir(parent)

proc createDmg*(stageDir, volName, outPath: string,
                imageFormat = "", fs = ""): int =
  ## Writes the compressed read-only image; non-zero means hdiutil failed
  ensureParentDir(outPath)
  runStreaming(composeDmgArgs(stageDir, volName, outPath, imageFormat, fs))