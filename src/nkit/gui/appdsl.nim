import std/[macros]

## Backend-agnostic application DSL.
##
## `initApp` transforms this shape:
##
##   initApp("Title") do:
##     state do:
##       <statements run once before UI builds>
##     render do:
##       <imperative setup...>
##       <last expression = root widget>
##
## into a program that boots a backend window via the hook contract below.
## Backends implement:
##   dslCreateWindow(title: string)
##   dslMountAndRun(win, root)
## See gui/appdsl_cocoa.nim for the native macOS implementation. Custom
## renderers (immediate mode, custom canvases) can ship their own hooks and
## re-export this macro unchanged.

proc splitRenderBody(body: NimNode): tuple[pre: NimNode, root: NimNode] =
  ## The last statement in the render block is the root widget.
  ## Everything before it is imperative (setup, wiring, side effects).
  if body.len == 0:
    error("render block is empty", body)
  result.pre = newStmtList()
  for i in 0 ..< body.len - 1:
    let stmt = body[i]
    if stmt.kind != nnkCommentStmt:
      result.pre.add(stmt)
  result.root = body[^1]

proc extractBlocks(body: NimNode): tuple[stateBody, renderPre: NimNode,
                                          rootWidget: NimNode] =
  result.stateBody = newStmtList()
  var sawRender = false
  for node in body:
    if node.kind in {nnkCall, nnkCommand} and node[0].kind == nnkIdent:
      case $node[0]
      of "state":
        let blk = node[^1]
        blk.expectKind({nnkStmtList})
        for s in blk:
          if s.kind != nnkCommentStmt:
            result.stateBody.add(s)
      of "render":
        if sawRender:
          error("duplicate render block", node)
        sawRender = true
        let blk = node[^1]
        blk.expectKind({nnkStmtList})
        (result.renderPre, result.rootWidget) = splitRenderBody(blk)
      else:
        error("unknown block '" & $node[0] & "'; expected 'state' or 'render'", node)
    else:
      error("initApp body accepts only 'state' and 'render' blocks", node)
  if not sawRender:
    error("missing render block", body)

proc genInitApplication(title: NimNode, body: NimNode): NimNode =
  var stateBody: NimNode
  var renderPre: NimNode
  var rootWidget: NimNode
  (stateBody, renderPre, rootWidget) = extractBlocks(body)

  result = quote do:
    block:
      when defined(nkitTrace):
        proc nlog(msg: string) =
          let f = open("/tmp/nkit_nim.log", fmAppend)
          f.writeLine(msg)
          f.close()
        nlog("macro: dslCreateWindow start")
      let nbWin {.inject.} = dslCreateWindow(`title`)
      when defined(nkitTrace): nlog("macro: stateBody start")
      `stateBody`
      when defined(nkitTrace): nlog("macro: stateBody done, nbBuildUi start")
      proc nbBuildUi(): auto =
        `renderPre`
        `rootWidget`
      when defined(nkitTrace): nlog("macro: nbBuildUi defined, dslMountAndRun start")
      dslMountAndRun(nbWin, nbBuildUi())
      when defined(nkitTrace): nlog("macro: dslMountAndRun done")

macro initApp*(title: static string, body: untyped): untyped =
  genInitApplication(newLit(title), body)

macro initApp*(body: untyped): untyped =
  genInitApplication(newLit("nativeapi Application"), body)
