import std/[tables, strutils, parseutils, uri, sequtils]
import pkg/openparser/regex
import nkit/foundation/geometry
import nkit/gui/layout
import nkit/gui/view
import nkit/gui/split_view
import nkit/gui/label

export layout, view, split_view

## GoRouter-style view router for native widget trees.
##
## Routes map URL-like patterns to builders that produce a ViewNode:
##
##   router.route("/", homePage)
##   router.route("/products/{productId: id}", productPage)
##   router.mountRouter(hostView)
##
## Patterns follow the supranim convention: `{name: type}` segments with a
## trailing `?` marking the parameter optional. Matching runs against the
## openparser regex VM; query strings (`?tab=specs`) never participate in
## matching but land in the same RouteParams as the path parameters.

const
  BuiltinPatterns* = {
    "slug": "[0-9A-Za-z-_]+",
    "anySlug": "[0-9A-Za-z-_/]+",
    "alphaSlug": "[A-Za-z-_]+",
    "uuid": "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}",
    "hex": "[0-9a-fA-F]+",
    "word": "\\w+",
    "wordWithDots": "[\\w\\.]+",
    "semver": "v?[0-9]+(?:\\.[0-9]+){1,3}(?:-[0-9A-Za-z.\\-]+)?",
    "date": "[0-9]{4}-[0-9]{2}-[0-9]{2}",
    "any": ".+",
    "id": "[0-9]+"
  }.toTable
    ## Named segment types usable as `{name: type}`.

type
  RoutePattern* = tuple[key: string, reKey: string, isOptional: bool]

  RouteParams* = ref object
    entries*: OrderedTable[string, string]

  RouteBuilder* = proc(params: RouteParams): ViewNode

  RouteKind* = enum
    rkStatic
    rkDynamic

  Route* = ref object
    ## One registered route. Static routes match by exact key lookup;
    ## dynamic routes run their compiled pattern through the regex VM.
    path*: string
    kind*: RouteKind
    builder*: RouteBuilder
    regexProg: Program
    patterns: seq[RoutePattern]

  Router* = ref object
    statics: Table[string, Route]
    dynamics: seq[Route]
    notFoundBuilder: RouteBuilder
    host: View
    currentRoot*: ViewNode
      ## The root node of the page currently on screen.
    history: seq[string]
    currentPathValue: string

proc newRouteParams*(): RouteParams =
  RouteParams(entries: initOrderedTable[string, string]())

proc get*(p: RouteParams, key: string, default = ""): string =
  ## Returns the parameter value or `default` when absent.
  if p.entries.hasKey(key):
    p.entries[key]
  else:
    default

proc getInt*(p: RouteParams, key: string, default = 0): int =
  ## Returns the parameter parsed as int, or `default` when absent or NaN-ish.
  if p.entries.hasKey(key):
    try:
      parseInt(p.entries[key])
    except ValueError:
      default
  else:
    default

proc has*(p: RouteParams, key: string): bool =
  p.entries.hasKey(key)

iterator pairs*(p: RouteParams): tuple[key, val: string] =
  for k, v in p.entries:
    yield (k, v)

func escapeRegexLiteral(s: string): string =
  for c in s:
    if c in {'.', '*', '+', '?', '(', ')', '[', ']', '{', '}',
             '^', '$', '|', '\\'}:
      result.add('\\')
    result.add(c)

proc compileRoutePattern*(pattern: string):
    tuple[regexForm: string, patterns: seq[RoutePattern]] =
  ## Compiles `/products/{id: id}` style patterns into an anchored regex
  ## form plus the ordered list of parameter patterns. Literal segments are
  ## escaped; unknown identifier-shaped types raise ValueError.
  var i = 0
  while i < pattern.len:
    case pattern[i]
    of '{':
      inc(i) # skip {
      var p: RoutePattern
      i += pattern.parseUntil(p.key, {':'}, i)
      if i >= pattern.len:
        raise newException(ValueError,
          "invalid route pattern `" & pattern & "`: missing ending `}`")
      inc(i) # skip :
      i += pattern.parseUntil(p.reKey, {'}', '?'}, i)
      p.isOptional = i < pattern.len and pattern[i] == '?'
      if p.isOptional:
        if i + 1 < pattern.len and pattern[i + 1] == '}':
          inc(i, 2)
        else:
          raise newException(ValueError,
            "invalid optional pattern in `" & pattern &
            "`: missing ending `}`")
      else:
        inc(i) # skip }
      p.key = strip(p.key)
      p.reKey = strip(p.reKey)
      if p.key.len == 0:
        raise newException(ValueError,
          "empty parameter name in route `" & pattern & "`")
      if p.reKey.len == 0:
        raise newException(ValueError,
          "empty pattern type for `" & p.key & "` in `" & pattern & "`")
      let body =
        if BuiltinPatterns.hasKey(p.reKey):
          BuiltinPatterns[p.reKey]
        else:
          raise newException(ValueError,
            "unknown route pattern type `" & p.reKey & "`. Use one of: " &
            toSeq(BuiltinPatterns.keys).join(", "))
      result.patterns.add(p)
      if p.isOptional:
        result.regexForm.add("(?P<" & p.key & ">(" & body & ")?)")
      else:
        result.regexForm.add("(?P<" & p.key & ">" & body & ")")
    else:
      var lit = ""
      i += pattern.parseUntil(lit, {'{'}, i)
      result.regexForm.add(escapeRegexLiteral(lit))

proc normalizePath*(path: string): string =
  ## Strips the query string and any trailing slash (except root).
  var p = path
  let q = p.find('?')
  if q >= 0:
    p = p[0 ..< q]
  if p.len > 1 and p[^1] == '/':
    p = p[0 ..< ^1]
  p

proc parseQueryInto(query: string, params: RouteParams) =
  ## Parses `key=value&...` pairs into params without clobbering existing
  ## path parameters.
  for pair in query.split('&'):
    if pair.len == 0:
      continue
    let eq = pair.find('=')
    var k: string
    var v: string
    if eq >= 0:
      k = decodeUrl(pair[0 ..< eq])
      v = decodeUrl(pair[eq + 1 ..^ 1])
    else:
      k = decodeUrl(pair)
      v = ""
    if not params.entries.hasKey(k):
      params.entries[k] = v

proc newRouter*(): Router =
  Router(statics: initTable[string, Route]())

proc defaultNotFound(params: RouteParams): ViewNode =
  let l = newLabel("404 - page not found")
  l.setFontSize(16.0)
  ViewNode(l)

proc notFound*(r: Router, builder: RouteBuilder) =
  ## Installs the fallback page rendered when no route matches.
  r.notFoundBuilder = builder

proc route*(r: Router, pattern: string, builder: RouteBuilder) =
  ## Registers a route. Patterns without parameters become static routes
  ## matched by exact lookup; others compile through the regex engine.
  let (form, patterns) = compileRoutePattern(pattern)
  let rt = Route(
    path: normalizePath(pattern),
    builder: builder,
    patterns: patterns)
  if patterns.len == 0:
    rt.kind = rkStatic
    r.statics[normalizePath(pattern)] = rt
  else:
    rt.kind = rkDynamic
    rt.regexProg = compile("^" & form & "$")
    r.dynamics.add(rt)

proc resolve*(r: Router, path: string, params: RouteParams): Route =
  ## Finds the first route matching `path`, filling `params` with path and
  ## query parameters. Returns nil when nothing matches.
  let routePath = normalizePath(path)
  if r.statics.hasKey(routePath):
    return r.statics[routePath]
  let q = path.find('?')
  if q >= 0:
    parseQueryInto(path[q + 1 ..^ 1], params)
  for rt in r.dynamics:
    var vm = initRegexVM(rt.regexProg)
    let m = vm.match(routePath)
    if m.matched:
      var idx = 1
      for p in rt.patterns:
        let g = m.group(idx)
        if g.matched:
          params.entries[p.key] = g.str(routePath)
        inc idx
      return rt
  nil

proc render(r: Router, target: string) =
  ## Builds and swaps in the page for `target` inside the host view.
  if r.host.isNil:
    return
  var params = newRouteParams()
  let rt = r.resolve(target, params)
  let builder =
    if not rt.isNil:
      rt.builder
    elif not r.notFoundBuilder.isNil:
      r.notFoundBuilder
    else:
      defaultNotFound
  if not r.currentRoot.isNil:
    r.currentRoot.view.removeFromParent()
  let root = builder(params)
  addSubview(r.host, root.view)
  let f = getFrameRect(r.host)
  applyLayout(root, size(f.width, f.height))
  watchPaneFrame(r.host, root)
  r.currentRoot = root
  r.currentPathValue = normalizePath(target)

proc go*(r: Router, path: string) =
  ## Navigates to `path`, resetting the history stack to this page.
  r.history = @[normalizePath(path)]
  r.render(path)

proc push*(r: Router, path: string) =
  ## Navigates to `path`, keeping the previous pages recoverable by pop().
  r.history.add(normalizePath(path))
  r.render(path)

proc pop*(r: Router): bool =
  ## Returns to the previous page. False when already at the root entry.
  if r.history.len <= 1:
    return false
  discard r.history.pop()
  r.render(r.history[^1])
  true

proc depth*(r: Router): int =
  r.history.len

proc currentPath*(r: Router): string =
  r.currentPathValue

proc mountRouter*(r: Router, host: View, initialPath = "/") =
  ## Wires the router to a host view (window content or a split pane) and
  ## navigates to `initialPath`.
  r.host = host
  r.go(initialPath)
