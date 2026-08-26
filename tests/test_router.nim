import unittest
import std/[strutils]
import nkit/gui/router
import nkit/gui/view
import nkit/gui/label
import nkit/window
import nkit/application

suite "router pattern compilation":
  test "builtin id type compiles and matches digits":
    let (form, patterns) = compileRoutePattern("/products/{productId: id}")
    check form == "/products/(?P<productId>[0-9]+)"
    check patterns.len == 1
    check patterns[0].key == "productId"
    check not patterns[0].isOptional

  test "date, uuid, slug types are available":
    let (_, dp) = compileRoutePattern("/archive/{day: date}")
    check dp[0].reKey == "date"
    let (_, up) = compileRoutePattern("/files/{fileId: uuid}")
    check up[0].reKey == "uuid"
    let (_, sp) = compileRoutePattern("/blog/{slug: slug}")
    check sp[0].reKey == "slug"

  test "optional parameter compiles to optional group":
    let (form, patterns) = compileRoutePattern("/posts/{page: id?}")
    check patterns[0].isOptional
    check form.contains("(?P<page>(")

  test "unknown pattern type raises with suggestions":
    expect ValueError:
      discard compileRoutePattern("/x/{v: nonsense}")
    expect ValueError:
      discard compileRoutePattern("/codes/{code:[A-Z]{3}}")

suite "router matching":
  setup:
    let r = newRouter()
    r.route("/", proc(p: RouteParams): ViewNode =
      ViewNode(newLabel("home")))
    r.route("/about", proc(p: RouteParams): ViewNode =
      ViewNode(newLabel("about")))
    r.route("/products/{productId: id}", proc(p: RouteParams): ViewNode =
      ViewNode(newLabel("product " & p.get("productId"))))
    r.route("/archive/{day: date}/{slug: slug}", proc(p: RouteParams): ViewNode =
      ViewNode(newLabel(p.get("day") & ":" & p.get("slug"))))
    r.route("/files/{fileId: hex}", proc(p: RouteParams): ViewNode =
      ViewNode(newLabel("file " & p.get("fileId"))))

  test "static route resolves by exact key":
    var params = newRouteParams()
    let rt = r.resolve("/about", params)
    check not rt.isNil
    check rt.kind == rkStatic

  test "static route tolerates trailing slash":
    var params = newRouteParams()
    check not r.resolve("/about/", params).isNil

  test "dynamic id route extracts parameter":
    var params = newRouteParams()
    let rt = r.resolve("/products/42", params)
    check not rt.isNil
    check rt.kind == rkDynamic
    check params.get("productId") == "42"
    check params.getInt("productId") == 42

  test "dynamic route rejects wrong shapes":
    var params = newRouteParams()
    check r.resolve("/products/abc", params).isNil
    check r.resolve("/products/42/x", params).isNil

  test "multi-segment route extracts both parameters":
    var params = newRouteParams()
    discard r.resolve("/archive/2026-08-25/nim-2-2", params)
    check params.get("day") == "2026-08-25"
    check params.get("slug") == "nim-2-2"

  test "hex builtin validates its own shape":
    var ok = newRouteParams()
    check not r.resolve("/files/deadbeef", ok).isNil
    check ok.get("fileId") == "deadbeef"
    var bad = newRouteParams()
    check r.resolve("/files/nothex!", bad).isNil

  test "query params land in RouteParams":
    var params = newRouteParams()
    discard r.resolve("/products/7?tab=specs&ref=home%20page", params)
    check params.get("productId") == "7"
    check params.get("tab") == "specs"
    check params.get("ref") == "home page"

  test "path param wins over same-named query param":
    var params = newRouteParams()
    discard r.resolve("/products/7?productId=999", params)
    check params.get("productId") == "7"

  test "unknown path returns nil route":
    var params = newRouteParams()
    check r.resolve("/nope", params).isNil

suite "router navigation":
  var r: Router
  var host: View

  proc makePage(text: string): RouteBuilder =
    result = proc(p: RouteParams): ViewNode =
      ViewNode(newLabel(text))

  proc labelOf(r: Router): string =
    let root = r.currentRoot
    if not root.isNil and root.view of Label:
      getText(Label(root.view))
    else:
      ""

  setup:
    if host.isNil:
      discard initApplication()
      host = newPlainView()
    r = newRouter()
    r.route("/", makePage("home"))
    r.route("/a", makePage("a"))
    r.route("/b", makePage("b"))

  test "mount renders initial path":
    r.mountRouter(host)
    check r.currentPath() == "/"
    check r.depth() == 1
    check r.labelOf() == "home"

  test "go resets the stack":
    r.mountRouter(host)
    r.push("/a")
    r.push("/b")
    check r.depth() == 3
    r.go("/")
    check r.depth() == 1
    check r.labelOf() == "home"

  test "push grows stack and pop returns":
    r.mountRouter(host)
    r.push("/a")
    check r.labelOf() == "a"
    r.push("/b")
    check r.depth() == 3
    check r.pop()
    check r.currentPath() == "/a"
    check r.pop()
    check r.currentPath() == "/"
    check not r.pop()

  test "unmatched path renders fallback page":
    r.notFound(proc(p: RouteParams): ViewNode = ViewNode(newLabel("lost")))
    r.mountRouter(host)
    r.push("/nowhere")
    check r.labelOf() == "lost"

  test "dynamic builder receives live params":
    r.route("/items/{itemId: id}",
      proc(p: RouteParams): ViewNode = ViewNode(newLabel("item" & p.get("itemId"))))
    r.mountRouter(host)
    r.push("/items/9")
    check r.labelOf() == "item9"
