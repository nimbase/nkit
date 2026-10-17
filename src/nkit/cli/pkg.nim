import std/os
import ./ios
import ./dmg

## Installer package building for the nkit CLI (macOS only).
##
## `nkit bundle --pkg` turns the built .app into a flat component package
## with `pkgbuild` and places the resulting .pkg at the root of the disk
## image next to the app, so one .dmg offers both drag-to-install and the
## guided installer.
##
## The package installs the .app to /Applications. Identifier and version
## come from nkit.yaml (bundle_id and version), never from flags, so --pkg
## only works inside a project directory; plain `nkit bundle` keeps working
## on any .app with no config in scope.
##
## As in dmg.nim, pure builders (path defaults, argument assembly) are kept
## apart from the process wrapper so they can be unit tested without ever
## invoking pkgbuild.

const
  PkgInstallLocation* = "/Applications"
    ## Where the component package installs the .app on the target machine.

func pkgPathFor*(dmgOutPath, appName: string): string =
  ## Where the installer lands: beside the disk image, so both artifacts
  ## stay together even when `--out` redirects the image. With the default
  ## image location this is beside the app it was built from, i.e.
  ## `build/macos/Demo.dmg` yields `build/macos/Demo.pkg`.
  parentDir(dmgOutPath) / (appName & ".pkg")

func composePkgArgs*(component, identifier, version, outPath: string,
                     signIdentity = ""): string =
  ## Assembles the `pkgbuild` invocation for a component package.
  ##
  ## Identifier and version are always passed explicitly (both come from
  ## nkit.yaml) rather than letting pkgbuild infer them from the
  ## component's Info.plist, so the package contents are determined by the
  ## project config alone. `--sign` is added only when an identity is
  ## given; unsigned packages install fine locally and Gatekeeper signing
  ## stays a later step.
  result = "pkgbuild --component \"" & component &
    "\" --install-location \"" & PkgInstallLocation &
    "\" --identifier \"" & identifier &
    "\" --version \"" & version & "\""
  if signIdentity.len > 0:
    result.add(" --sign \"" & signIdentity & "\"")
  result.add(" \"" & outPath & "\"")

# --- process wrapper -------------------------------------------------------

proc buildPkg*(component, identifier, version, outPath: string,
               signIdentity = ""): int =
  ## Builds the flat component package; non-zero means pkgbuild failed.
  ## A stale package at the output path is removed first so rebuilds
  ## behave like hdiutil's -ov rather than failing on an existing file.
  ensureParentDir(outPath)
  if fileExists(outPath):
    removeFile(outPath)
  runStreaming(composePkgArgs(component, identifier, version, outPath,
    signIdentity))
