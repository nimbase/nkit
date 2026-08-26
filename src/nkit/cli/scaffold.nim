import std/[os, strutils]
import nkit/cli/project

## Project scaffolding templates used by `nkit init`.
## Renders nkit.yaml, the nimble file and a starter application.

func renderConfigYaml*(name, version, description, author,
                       bundleId: string): string =
  """# nkit.yaml - project configuration for the nkit toolchain
name: "$1"
version: "$2"
description: "$3"
author: "$4"

dependencies:
  nkit: ">= 0.1.0"

ios:
  bundle_id: $5
  min_version: "15.0"
""".replace("$1", name).replace("$2", version).replace("$3", description) .
     replace("$4", author).replace("$5", bundleId)

func renderNimbleFile*(name, version, description, author,
                       license: string): string =
  """# Package

version       = "$1"
author        = "$2"
description   = "$3"
license       = "$4"
srcDir        = "src"
bin           = @["$5"]


# Dependencies

requires "nim >= 2.2.10"
requires "nkit >= 0.1.0"
""".replace("$1", version).replace("$2", author) .
     replace("$3", description).replace("$4", license).replace("$5", name)

const StarterMain* = """
## Starter application built with nkit.
import nkit/gui/appdsl_cocoa

dslWindowSize = size(420.0, 320.0)

initApp("Counter") do:
  state do:
    var clicks = 0
    var countLabel = text("0", 48.0, fwLight)
    var statusText = p("press increment to start")

  render do:
    padding(
      column(
        h1("Counter"),
        expanded(centered(countLabel)),
        row(
          button("increment", proc(e: ButtonClickEvent) =
            inc clicks
            setText(countLabel, $clicks)
            setText(statusText, "clicked " & $clicks & "x")),
          button("reset", proc(e: ButtonClickEvent) =
            clicks = 0
            setText(countLabel, "0")
            setText(statusText, "counter cleared"))
        ).spacing(12).crossAlign(caStretch),
        centered(statusText)
      ).spacing(16),
      all(24.0)
    )
"""

proc scaffoldProject*(rootDir, name, version, description,
                      author: string) =
  ## Writes nkit.yaml, the nimble file and a starter main into `rootDir`.
  createDir(rootDir / "src")
  let bundleId = defaultBundleId(name)
  writeFile(rootDir / ConfigFileName,
    renderConfigYaml(name, version, description, author, bundleId))
  writeFile(rootDir / (name & ".nimble"),
    renderNimbleFile(name, version, description, author, "MIT"))
  writeFile(rootDir / "src" / (name & ".nim"), StarterMain)
