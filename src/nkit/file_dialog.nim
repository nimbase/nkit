import nkit/foundation/event
import nkit/dialog
import nkit/platform/macos/nsfunctions

when defined(macosx) or defined(ios):
  import std/strutils

type
  OpenFileDialog* = ref object of Dialog
    titleValue*: string
    allowsMultipleValue*: bool
    canChooseDirectoriesValue*: bool
    filtersValue*: seq[string]
    initialDirectoryValue*: string
    handle: pointer

proc newOpenFileDialog*(title = ""): OpenFileDialog =
  when defined(macosx) or defined(ios):
    let h = naOpenPanelCreate(title.cstring)
  else:
    let h: pointer = nil
  result = OpenFileDialog(
    modality: dmNone,
    titleValue: title,
    handle: h)

proc setAllowsMultiple*(d: OpenFileDialog, value: bool) =
  d.allowsMultipleValue = value
  when defined(macosx) or defined(ios):
    naOpenPanelSetAllowsMultiple(d.handle, value)

proc setCanChooseDirectories*(d: OpenFileDialog, value: bool) =
  d.canChooseDirectoriesValue = value
  when defined(macosx) or defined(ios):
    naOpenPanelSetCanChooseDirectories(d.handle, value)

proc setFilters*(d: OpenFileDialog, extensions: seq[string]) =
  d.filtersValue = extensions
  when defined(macosx) or defined(ios):
    var exts: seq[cstring] = @[]
    for e in extensions:
      exts.add(e.cstring)
    if exts.len > 0:
      naOpenPanelSetFilters(d.handle, addr exts[0], cint(exts.len))
    else:
      naOpenPanelSetFilters(d.handle, nil, 0)

proc setInitialDirectory*(d: OpenFileDialog, path: string) =
  d.initialDirectoryValue = path
  when defined(macosx) or defined(ios):
    naOpenPanelSetInitialDirectory(d.handle, path.cstring)

method open*(d: OpenFileDialog): seq[string] =
  ## Runs the panel modally and returns the chosen paths (empty on cancel).
  when defined(macosx) or defined(ios):
    var paths: ptr cstring = nil
    let count = naOpenPanelRunModal(d.handle, addr paths)
    if count > 0 and not paths.isNil:
      for i in 0 ..< int(count):
        let item = cast[ptr UncheckedArray[cstring]](paths)[i]
        result.add($item)
      naClipboardFreeStringList(paths, count)
  else:
    discard

type
  SaveFileDialog* = ref object of Dialog
    titleValue*: string
    defaultNameValue*: string
    filtersValue*: seq[string]
    handle: pointer

proc newSaveFileDialog*(title = "", defaultName = ""): SaveFileDialog =
  when defined(macosx) or defined(ios):
    let h = naSavePanelCreate(title.cstring, defaultName.cstring)
  else:
    let h: pointer = nil
  result = SaveFileDialog(
    modality: dmNone,
    titleValue: title,
    defaultNameValue: defaultName,
    handle: h)

proc setNameField*(d: SaveFileDialog, name: string) =
  d.defaultNameValue = name
  when defined(macosx) or defined(ios):
    naSavePanelSetNameField(d.handle, name.cstring)

proc setFilters*(d: SaveFileDialog, extensions: seq[string]) =
  d.filtersValue = extensions
  when defined(macosx) or defined(ios):
    var exts: seq[cstring] = @[]
    for e in extensions:
      exts.add(e.cstring)
    if exts.len > 0:
      naSavePanelSetFilters(d.handle, addr exts[0], cint(exts.len))
    else:
      naSavePanelSetFilters(d.handle, nil, 0)

method open*(d: SaveFileDialog): string =
  ## Runs the panel modally; returns the chosen path or "" on cancel.
  when defined(macosx) or defined(ios):
    let path = naSavePanelRunModal(d.handle)
    if not path.isNil:
      result = $path
      naClipboardFreeString(path)
  else:
    ""
