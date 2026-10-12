## macOS main menu bar: App/Edit/Window/Help menus with standard
## responder-chain actions.
##
## macOS-only by design. Guard call sites with `when defined(macosx)`.
## Plain items (About, Preferences, custom entries) report clicks through
## the usual `MenuItemClickedEvent`; items carrying a `StandardSelector`
## are handled natively by AppKit and never emit Nim events.

when defined(macosx):
  import ./menu
  import ./application
  import ./foundation/keyboard
  import ./platform/macos/nsfunctions

  export menu

  type StandardSelector* = enum
    ssAboutPanel = "orderFrontStandardAboutPanel:"
    ssHide = "hide:"
    ssHideOthers = "hideOtherApplications:"
    ssUnhideAll = "unhideAllApplications:"
    ssTerminate = "terminate:"
    ssUndo = "undo:"
    ssRedo = "redo:"
    ssCut = "cut:"
    ssCopy = "copy:"
    ssPaste = "paste:"
    ssDelete = "delete:"
    ssSelectAll = "selectAll:"
    ssClose = "close:"
    ssMiniaturize = "performMiniaturize:"
    ssZoom = "performZoom:"
    ssToggleFullscreen = "toggleFullScreen:"
    ssBringAllToFront = "arrangeInFront:"
    ssPageLayout = "runPageLayout:"
    ssPrint = "print:"
    ssShowHelp = "showHelp:"
    ssToggleSidebar = "toggleSidebar:"
    ssToggleToolbar = "toggleToolbarShown:"

  proc setStandardSelectorName*(mi: MenuItem, name: string): bool =
    ## Hands the item to AppKit under an explicit selector name.
    ## Unknown names are rejected (false); known ones run natively via
    ## the responder chain and stop emitting `MenuItemClickedEvent`.
    result = naMenuItemSetSelector(mi.nativeKey, name.cstring)
    if result:
      mi.selectorValue = name
      mi.hasSelector = true

  proc setStandardSelector*(mi: MenuItem, selector: StandardSelector): bool =
    ## Hands the item to AppKit: it sends `selector` up the responder
    ## chain instead of emitting `MenuItemClickedEvent`. Returns false
    ## when the native side rejects the selector.
    mi.setStandardSelectorName($selector)

  proc getStandardSelector*(mi: MenuItem): string =
    if mi.hasSelector:
      mi.selectorValue
    else:
      ""

  proc topLevelItem*(submenu: Menu, title = ""): MenuItem =
    ## Holder entry for one menu-bar menu (App, File, Edit, …).
    ## The title shows in the bar except for the first (application) menu.
    result = newMenuItem(title, mitSubmenu)
    result.setSubmenu(submenu)

  proc addTopMenu*(bar: Menu, title: string, menu: Menu,
                   at = -1): MenuItem =
    ## Appends (or inserts at `at`) a top-level menu. Returns the holder.
    result = topLevelItem(menu, title)
    if at >= 0:
      bar.insertItem(at, result)
    else:
      bar.addItem(result)

  proc designateServicesMenu*(m: Menu) =
    ## Marks `m` as the Services submenu (`NSApp.servicesMenu`).
    naMenuSetAsServices(m.nativeKey)

  proc designateWindowsMenu*(m: Menu) =
    ## Marks `m` as the Window menu (`NSApp.windowsMenu`), enabling the
    ## automatic open-window list.
    naMenuSetAsWindows(m.nativeKey)

  proc designateHelpMenu*(m: Menu) =
    ## Marks `m` as the Help menu (`NSApp.helpMenu`), enabling
    ## Spotlight menu search.
    naMenuSetAsHelp(m.nativeKey)

  type AppMenu* = object
    menu*: Menu
    aboutItem*: MenuItem
    prefsItem*: MenuItem

  proc buildAppMenu*(appName: string): AppMenu =
    ## Standard application menu. Wire `aboutItem`/`prefsItem` clicks in
    ## Nim; everything else (Services, Hide, Quit) works natively.
    let m = newMenu()
    let about = newMenuItem("About " & appName)
    m.addItem(about)
    m.addSeparator()
    let prefs = newMenuItem("Preferences…")
    prefs.setAccelerator(keyboardAccelerator(",", modMeta))
    m.addItem(prefs)
    m.addSeparator()
    let services = newMenu()
    let servicesHolder = newMenuItem("Services", mitSubmenu)
    servicesHolder.setSubmenu(services)
    m.addItem(servicesHolder)
    designateServicesMenu(services)
    m.addSeparator()
    let hide = newMenuItem("Hide " & appName)
    hide.setAccelerator(keyboardAccelerator("H", modMeta))
    discard hide.setStandardSelector(ssHide)
    m.addItem(hide)
    let hideOthers = newMenuItem("Hide Others")
    hideOthers.setAccelerator(keyboardAccelerator("H", modMeta or modAlt))
    discard hideOthers.setStandardSelector(ssHideOthers)
    m.addItem(hideOthers)
    let showAll = newMenuItem("Show All")
    discard showAll.setStandardSelector(ssUnhideAll)
    m.addItem(showAll)
    m.addSeparator()
    let quit = newMenuItem("Quit " & appName)
    quit.setAccelerator(keyboardAccelerator("Q", modMeta))
    discard quit.setStandardSelector(ssTerminate)
    m.addItem(quit)
    AppMenu(menu: m, aboutItem: about, prefsItem: prefs)

  proc buildEditMenu*(): Menu =
    ## Standard Edit menu. All items act through the responder chain,
    ## so Cut/Copy/Paste/… work in any focused text field with no code.
    result = newMenu()
    let undo = newMenuItem("Undo")
    undo.setAccelerator(keyboardAccelerator("Z", modMeta))
    discard undo.setStandardSelector(ssUndo)
    result.addItem(undo)
    let redo = newMenuItem("Redo")
    redo.setAccelerator(keyboardAccelerator("Z", modMeta or modShift))
    discard redo.setStandardSelector(ssRedo)
    result.addItem(redo)
    result.addSeparator()
    let cut = newMenuItem("Cut")
    cut.setAccelerator(keyboardAccelerator("X", modMeta))
    discard cut.setStandardSelector(ssCut)
    result.addItem(cut)
    let copy = newMenuItem("Copy")
    copy.setAccelerator(keyboardAccelerator("C", modMeta))
    discard copy.setStandardSelector(ssCopy)
    result.addItem(copy)
    let paste = newMenuItem("Paste")
    paste.setAccelerator(keyboardAccelerator("V", modMeta))
    discard paste.setStandardSelector(ssPaste)
    result.addItem(paste)
    let delete = newMenuItem("Delete")
    discard delete.setStandardSelector(ssDelete)
    result.addItem(delete)
    let selectAll = newMenuItem("Select All")
    selectAll.setAccelerator(keyboardAccelerator("A", modMeta))
    discard selectAll.setStandardSelector(ssSelectAll)
    result.addItem(selectAll)

  proc buildWindowMenu*(): Menu =
    ## Standard Window menu, designated for the automatic window list.
    result = newMenu()
    let mini = newMenuItem("Minimize")
    mini.setAccelerator(keyboardAccelerator("M", modMeta))
    discard mini.setStandardSelector(ssMiniaturize)
    result.addItem(mini)
    let zoom = newMenuItem("Zoom")
    discard zoom.setStandardSelector(ssZoom)
    result.addItem(zoom)
    result.addSeparator()
    let full = newMenuItem("Enter Full Screen")
    full.setAccelerator(keyboardAccelerator("F", modMeta or modCtrl))
    discard full.setStandardSelector(ssToggleFullscreen)
    result.addItem(full)
    result.addSeparator()
    let front = newMenuItem("Bring All to Front")
    discard front.setStandardSelector(ssBringAllToFront)
    result.addItem(front)
    designateWindowsMenu(result)

  proc buildHelpMenu*(): Menu =
    ## Empty menu designated as Help, enabling Spotlight menu search.
    ## Add `Search`-style items with `addItem` as usual.
    result = newMenu()
    designateHelpMenu(result)

  type StandardMenuBar* = object
    bar*: Menu
    app*: AppMenu
    edit*: Menu
    window*: Menu
    help*: Menu

  proc standardMenuBar*(appName: string): StandardMenuBar =
    ## Canonical App/Edit/Window/Help bar. Insert custom top menus
    ## (File, View, …) with `addTopMenu` afterwards.
    let bar = newMenu()
    let app = buildAppMenu(appName)
    let edit = buildEditMenu()
    let window = buildWindowMenu()
    let help = buildHelpMenu()
    discard bar.addTopMenu("", app.menu)
    discard bar.addTopMenu("Edit", edit)
    discard bar.addTopMenu("Window", window)
    discard bar.addTopMenu("Help", help)
    StandardMenuBar(bar: bar, app: app, edit: edit, window: window,
                    help: help)

  proc getMainMenu*(app: Application): Menu =
    ## Returns the installed menu bar object, or nil when none.
    let key = app.getMainMenuKey()
    if key == 0:
      return nil
    findMenuByKey(key)
