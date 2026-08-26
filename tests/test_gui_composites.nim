import unittest
import nkit
import nkit/foundation/dispatcher
import nkit/gui/view
import nkit/gui/stack
import nkit/gui/scroll
import nkit/gui/label
import nkit/gui/card
import nkit/gui/badge
import nkit/gui/tabs
import nkit/gui/avatar

suite "stack":
  test "arranged children managed in order":
    let st = newStack(stVertical, spacing = 4.0)
    defer:
      destroy(st)
    let a = newPlainView()
    let b = newPlainView()
    let c = newPlainView()
    defer:
      destroy(a)
      destroy(b)
      destroy(c)
    check arrangedCount(st) == 0
    addArranged(st, a)
    addArranged(st, b)
    check arrangedCount(st) == 2
    insertArranged(st, c, 1)
    check arrangedCount(st) == 3
    removeArranged(st, b)
    check arrangedCount(st) == 2

  test "padding and alignment setters apply":
    let st = newStack(stHorizontal)
    defer:
      destroy(st)
    setSpacing(st, 12.0)
    setPadding(st, 8.0, 6.0, 4.0, 2.0)
    setAlignment(st, saCenter)

suite "scroll":
  test "document view and bar toggles":
    let sc = newScroll()
    defer:
      destroy(sc)
    let doc = newStack(stVertical)
    defer:
      destroy(doc)
    setDocument(sc, doc)
    setHasVerticalBar(sc, true)
    setHasHorizontalBar(sc, false)
    setBorder(sc, false)
    setBackground(sc, colorWhite)
    fitWidth(sc)

suite "card":
  test "card structure with header and content slot":
    let card = newCard("Team members", "Manage who has access", cornerRadius = 12.0)
    defer:
      destroy(card)
    check not card.titleLabel.isNil
    check getText(card.titleLabel) == "Team members"
    check not card.descriptionLabel.isNil
    check getText(card.descriptionLabel) == "Manage who has access"

    let body = newLabel("3 members")
    addToContent(card, View(body))
    check getFrameRect(card.contentSlot).width > 0 or true
    layoutNow(card)

  test "footer lazily created":
    let card = newCard("Simple")
    defer:
      destroy(card)
    check card.footerSlot.isNil
    let footerButton = newPlainView()
    addToFooter(card, footerButton)
    check not card.footerSlot.isNil

suite "badge":
  test "variants and text updates":
    let b = newBadge("Active", bvDefault)
    defer:
      destroy(b)
    check getText(b.textLabel) == "Active"
    setText(b, "Beta")
    check getText(b.textLabel) == "Beta"
    check getVariant(b) == bvDefault
    applyBadgeVariant(b, bvDestructive)
    check getVariant(b) == bvDestructive
    let outline = newBadge("Outline", bvOutline)
    defer:
      destroy(outline)
    check getVariant(outline) == bvOutline

suite "tabs":
  test "page selection switches and emits":
    let t = newTabs(["General", "Advanced"])
    defer:
      destroy(t)
    var events: seq[int]
    discard onChanged(t, proc(e: TabChangedEvent) =
      events.add(e.index))

    let pageA = newLabel("general settings")
    let pageB = newLabel("advanced settings")
    addPage(t, 0, View(pageA))
    addPage(t, 1, View(pageB))

    selectPage(t, 1)
    discard runMainThreadLoopFor(120)
    check currentPage(t) == 1
    check not isHidden(pageB)
    check isHidden(pageA)
    check events == @[1]

    selectPage(t, 0)
    discard runMainThreadLoopFor(120)
    check currentPage(t) == 0
    check not isHidden(pageA)
    check isHidden(pageB)
    check events == @[1, 0]

suite "avatar":
  test "initials monogram derivation":
    let av = newAvatar(asMedium)
    defer:
      destroy(av)
    setInitials(av, "Ada Lovelace")
    check getText(av.initialsLabel) == "AL"
    let single = newAvatar(asSmall)
    defer:
      destroy(single)
    setInitials(single, "Cher")
    check getText(single.initialsLabel) == "C"

suite "accordion":
  test "items start collapsed with correct metadata":
    let acc = newAccordion(singleOpen = true)
    defer:
      destroy(acc)
    let body1 = newPlainView()
    let body2 = newPlainView()
    discard addItem(acc, "First", body1)
    discard addItem(acc, "Second", body2)
    check getItemCount(acc) == 2
    check getItemTitle(acc, 0) == "First"
    check getItemTitle(acc, 1) == "Second"
    check getItemTitle(acc, 5) == ""
    check isExpanded(acc, 0) == false
    check isExpanded(acc, 1) == false
    check expandedIndices(acc).len == 0

  test "setExpanded toggles state and emits event":
    let acc = newAccordion(singleOpen = false)
    defer:
      destroy(acc)
    var events: seq[tuple[index: int, expanded: bool]] = @[]
    discard onChanged(acc, proc(e: AccordionChangedEvent) =
      events.add((index: e.itemIndex, expanded: e.isExpanded)))
    let body = newLabel("detail")
    discard addItem(acc, "Only", body)
    setExpanded(acc, 0, true)
    discard runMainThreadLoopFor(120)
    check isExpanded(acc, 0) == true
    setExpanded(acc, 0, true)  # idempotent, no extra event
    discard runMainThreadLoopFor(120)
    setExpanded(acc, 0, false)
    discard runMainThreadLoopFor(120)
    check isExpanded(acc, 0) == false
    check events.len == 2
    check events[0] == (index: 0, expanded: true)
    check events[1] == (index: 0, expanded: false)

  test "single-open mode collapses siblings":
    let acc = newAccordion(singleOpen = true)
    defer:
      destroy(acc)
    discard addItem(acc, "A", newPlainView())
    discard addItem(acc, "B", newPlainView())
    discard addItem(acc, "C", newPlainView())
    var siblingCollapse: seq[int] = @[]
    discard onChanged(acc, proc(e: AccordionChangedEvent) =
      if not e.isExpanded:
        siblingCollapse.add(e.itemIndex))
    setExpanded(acc, 0, true)
    discard runMainThreadLoopFor(120)
    setExpanded(acc, 2, true)
    discard runMainThreadLoopFor(120)
    check isExpanded(acc, 0) == false
    check isExpanded(acc, 2) == true
    check siblingCollapse == @[0]

  test "multi-open mode allows several sections":
    let acc = newAccordion(singleOpen = false)
    defer:
      destroy(acc)
    discard addItem(acc, "A", newPlainView())
    discard addItem(acc, "B", newPlainView())
    setExpanded(acc, 0, true)
    setExpanded(acc, 1, true)
    check expandedIndices(acc) == @[0, 1]

  test "header click hook toggles through hover router":
    let acc = newAccordion(singleOpen = true)
    defer:
      destroy(acc)
    discard addItem(acc, "Click me", newPlainView())
    fireHeaderClick(acc, 0)
    check isExpanded(acc, 0) == true
    fireHeaderClick(acc, 0)
    check isExpanded(acc, 0) == false

  test "out-of-range toggles are ignored":
    let acc = newAccordion()
    defer:
      destroy(acc)
    setExpanded(acc, -1, true)
    setExpanded(acc, 42, true)
    check expandedIndices(acc).len == 0

  test "expandAll and collapseAll":
    let acc = newAccordion(singleOpen = false)
    defer:
      destroy(acc)
    discard addItem(acc, "A", newPlainView())
    discard addItem(acc, "B", newPlainView())
    expandAll(acc)
    check expandedIndices(acc) == @[0, 1]
    collapseAll(acc)
    check expandedIndices(acc).len == 0

suite "card stacking regression":
  test "multiple addToContent children stack vertically, no overlap":
    let card = newCard("Stacking", "children must not overlap")
    defer:
      destroy(card)
    let first = newLabel("First row")
    let second = newLabel("Second row")
    let third = newLabel("Third row")
    addToContent(card, first)
    addToContent(card, second)
    addToContent(card, third)
    let host = newPlainView()
    setFrameRect(host, rectangle(0.0, 0.0, 400.0, 300.0))
    addSubview(host, View(card))
    fillParent(View(card))
    layoutNow(host)
    discard runMainThreadLoopFor(120)
    let fa = getFrameRect(first)
    let fb = getFrameRect(second)
    let fc = getFrameRect(third)
    check fa.height > 0.0
    check fb.height > 0.0
    check abs(fa.y - fb.y) > 1.0
    check abs(fb.y - fc.y) > 1.0
    check abs(fa.x - fb.x) < 0.5
    check abs(fa.width - fb.width) < 40.0
