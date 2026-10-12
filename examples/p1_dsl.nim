## P1 services on the macro DSL: initApp with state/render blocks.
## Same interface as p1_lowlevel.nim / p1_flutter.nim.
import nkit/gui/appdsl_cocoa

dslWindowSize = size(680.0, 460.0)

initApp("P1 Services") do:
  state do:
    var itemName = "nothing yet"
    var statusText = p("last action: nothing yet")

    proc syncStatus() =
      setText(statusText, "last action: " & itemName)

    proc showAlertDialog() =
      showAlert("Delete workspace?",
                "All unsaved changes will be lost.", asWarning)
        .addButton("Cancel")
        .addButton("Move to Trash", proc(id: AlertID) =
          itemName = "moved to trash"; syncStatus(); id.close(),
          isDefault = true)
        .open()

    proc showRenameDialog() =
      let nameInput = input("Layer 1")
      showAlert("Rename layer", "Enter a new name.")
        .withContent(nameInput)
        .addButton("Rename", proc(id: AlertID) =
          itemName = "renamed: " & getText(nameInput)
          syncStatus(); id.close(), isDefault = true)
        .open()

  render do:
    let toolbar = attachToolbar(mostRecentWindow())
    discard toolbar.addItem("Alert", "exclamationmark.triangle",
                            showAlertDialog)
    discard toolbar.addItem("Rename", "square.and.pencil",
                            showRenameDialog)

    let popBtn = button("Show popover",
      showPopover(
        p("Anchored NSPopover holding any widget tree."), size(240.0, 130.0)))

    let box = sizedBox(0.0, 64.0, padding(ViewNode(p("animated box")), 12.0))
    setBackgroundColor(box.view, systemIndigo())
    setCornerRadius(box.view, 10.0)

    verticalSplitView(
      padding(
        column(h2("Library"),
          button("Item 1", proc(e: ButtonClickEvent) =
            itemName = "item 1"; syncStatus()),
          button("Item 2", proc(e: ButtonClickEvent) =
            itemName = "item 2"; syncStatus()),
          button("Item 3", proc(e: ButtonClickEvent) =
            itemName = "item 3"; syncStatus())
        ).spacing(10),
        10
      ),
      padding(
        column(
          h1("Native services"),
          box,
          row(button("Fade out", proc(e: ButtonClickEvent) = fadeOut(box.view)),
              button("Fade in", proc(e: ButtonClickEvent) = fadeIn(box.view)),
              button("Slide right", proc(e: ButtonClickEvent) =
                let f = box.view.getFrameRect()
                moveTo(box.view, f.x + 40.0, f.y, 300))).spacing(8),
          ViewNode(popBtn),
          ViewNode(statusText)
        ).spacing(14),
        10
      )
    )
