import std/[os, strutils, tables]
import pkg/openparser/yaml

## Project configuration for nkit CLI, loaded from a `nkit.yaml` file in
## the project root (Flutter pubspec-style). Parsed directly into Nim
## objects with openparser/yaml.
##
## Note: this YAML dialect requires quoting scalar values that contain
## spaces; unknown keys are skipped so older CLIs tolerate newer configs.

type
  IosConfig* = object
    ## Platform-specific iOS settings. Field names match the YAML keys.
    bundle_id*: string   ## Defaults to com.example.<name>
    min_version*: string ## Deployment target; defaults to DefaultIosMinVersion

  ProjectConfig* = object
    name*: string        ## App name; doubles as the executable name
    version*: string     ## Feeds CFBundleShortVersionString and the nimble file
    description*: string
    author*: string
    dependencies*: OrderedTable[string, string]
      ## Additional nimble requirements beyond the generated baseline
    ios*: IosConfig

const
  DefaultIosMinVersion* = "15.0"
  ConfigFileName* = "nkit.yaml"

proc defaultBundleId*(name: string): string =
  "com.example." & name

proc applyDefaults*(cfg: var ProjectConfig) =
  ## Fills unset fields with built-in defaults.
  if cfg.name.len == 0:
    raise newException(ValueError,
      "nkit.yaml is missing the required `name` field")
  if cfg.version.len == 0:
    cfg.version = "0.1.0"
  if cfg.description.len == 0:
    cfg.description = "A native app built with nkit"
  if cfg.author.len == 0:
    cfg.author = ""
  if cfg.ios.bundle_id.len == 0:
    cfg.ios.bundle_id = defaultBundleId(cfg.name)
  if cfg.ios.min_version.len == 0:
    cfg.ios.min_version = DefaultIosMinVersion

proc parseProjectConfig*(content: string): ProjectConfig =
  ## Parses nkit.yaml content into a config object and fills defaults.
  result = parseYAML(content, ProjectConfig)
  applyDefaults(result)

proc loadProjectConfig*(path: string): ProjectConfig =
  ## Loads and parses the config file at `path`.
  if not fileExists(path):
    raise newException(IOError, "config not found: " & path)
  parseProjectConfig(readFile(path))

proc discoverProjectFile*(startDir: string): string =
  ## Walks up from `startDir` looking for a nkit.yaml. Empty string when
  ## no project root is found.
  var dir = absolutePath(startDir)
  while true:
    let candidate = dir / ConfigFileName
    if fileExists(candidate):
      return candidate
    let parent = parentDir(dir)
    if parent == dir:
      return ""
    dir = parent

proc findProjectConfig*(startDir = getCurrentDir()): string =
  ## Discovers nkit.yaml from `startDir` upward, raising when absent.
  let found = discoverProjectFile(startDir)
  if found.len == 0:
    raise newException(IOError,
      "no " & ConfigFileName & " found here or in any parent directory;" &
      " run `nkit init` first")
  found
