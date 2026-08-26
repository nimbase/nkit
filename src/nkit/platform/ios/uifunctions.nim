{.compile: "widgets/app.m".}
{.compile: "widgets/targets.m".}
{.compile: "widgets/window.m".}
{.compile: "widgets/view.m".}
{.compile: "widgets/label.m".}
{.compile: "widgets/theme.m".}
{.compile: "widgets/button.m".}
{.compile: "widgets/screen.m".}
{.compile: "widgets/display_manager.m".}
{.compile: "widgets/info.m".}
{.compile: "widgets/separator.m".}
{.compile: "widgets/progress.m".}
{.compile: "widgets/switch_widget.m".}
{.compile: "widgets/slider.m".}
{.compile: "widgets/segmented.m".}
{.compile: "widgets/stack.m".}
{.compile: "widgets/scroll.m".}
{.compile: "widgets/input.m".}
{.compile: "widgets/textarea.m".}
{.compile: "widgets/imageview.m".}
{.compile: "widgets/select.m".}
{.compile: "widgets/datepicker.m".}
{.compile: "widgets/tabs.m".}
{.compile: "widgets/toast.m".}
{.compile: "widgets/accordion.m".}
{.compile: "widgets/hover_router.m".}
{.compile: "widgets/split_view.m".}
{.compile: "widgets/dispatcher.m".}
{.passc: "-fobjc-arc".}
{.passl: "-framework UIKit".}
{.passl: "-framework Foundation".}
{.passl: "-framework CoreGraphics".}
{.passl: "-framework QuartzCore".}

## UIKit shim declarations for iOS. Proc names and signatures mirror
## nkit/platform/macos/nsfunctions.nim so service modules stay
## platform-blind beyond the conditional import.

type
  NaAppFn* = proc(ctx: pointer) {.cdecl.}
  NaAppExitFn* = proc(exitCode: cint, ctx: pointer) {.cdecl.}
  NaTaskFn* = proc(ctx: pointer) {.cdecl.}

# --- application -----------------------------------------------------------

proc naAppInit*(): bool {.importc: "na_app_init".}
proc naAppRun*(): cint {.importc: "na_app_run".}
proc naAppQuit*() {.importc: "na_app_quit".}
proc naAppStop*() {.importc: "na_app_stop".}
proc naAppSetDockMenu*(menuId: uint32) {.importc: "na_app_set_dock_menu".}
proc naAppDockMenu*(): uint32 {.importc: "na_app_dock_menu".}
proc naAppSetIcon*(utf8Path: cstring): bool {.importc: "na_app_set_icon".}
proc naAppSetDockIconVisible*(visible: bool): bool {.
  importc: "na_app_set_dock_icon_visible".}
proc naAppSetCallbacks*(ctx: pointer,
                        onStarted: NaAppFn,
                        onActivated: NaAppFn,
                        onDeactivated: NaAppFn,
                        onQuitRequested: NaAppFn,
                        onExiting: NaAppExitFn) {.
  importc: "na_app_set_callbacks".}

# --- dispatcher ------------------------------------------------------------

proc naIsMainThread*(): bool {.importc: "na_is_main_thread".}
proc naDispatchMain*(fn: NaTaskFn, ctx: pointer) {.importc: "na_dispatch_main".}
proc naDispatchMainAfter*(delayMs: cint, fn: NaTaskFn, ctx: pointer) {.
  importc: "na_dispatch_main_after".}
proc naRunLoopFor*(timeoutMs: cint): bool {.
  importc: "na_run_main_loop_for".}

# --- screens / displays ------------------------------------------------------

type
  NaScreensChangedFn* = proc(ctx: pointer) {.cdecl.}

proc naScreenCount*(): cint {.importc: "na_screen_count".}
proc naScreenDisplayId*(index: cint): uint32 {.importc: "na_screen_display_id".}
proc naScreenIsPrimary*(displayId: uint32): bool {.
  importc: "na_screen_is_primary".}
proc naScreenGetName*(displayId: uint32): cstring {.
  importc: "na_screen_get_name".}
proc naScreenGetFrame*(displayId: uint32, outX, outY, outW, outH: ptr float64) {.
  importc: "na_screen_get_frame".}
proc naScreenGetWorkArea*(displayId: uint32, outX, outY, outW, outH: ptr float64) {.
  importc: "na_screen_get_work_area".}
proc naScreenGetScaleFactor*(displayId: uint32): float64 {.
  importc: "na_screen_get_scale_factor".}
proc naScreenGetRefreshRate*(displayId: uint32): cint {.
  importc: "na_screen_get_refresh_rate".}
proc naScreenGetCursorPosition*(outX, outY: ptr float64) {.
  importc: "na_screen_get_cursor_position".}
proc naScreenSetChangedCallback*(fn: NaScreensChangedFn, ctx: pointer) {.
  importc: "na_screen_set_changed_callback".}

# --- windows -----------------------------------------------------------------

type
  NaWindowEventFn* = proc(kind: cint, windowId: uint32, a, b: float64,
                          ctx: pointer) {.cdecl.}

proc naWindowCreate*(): uint32 {.importc: "na_window_create".}
proc naWindowFree*(id: uint32) {.importc: "na_window_free".}
proc naWindowExists*(id: uint32): bool {.importc: "na_window_exists".}
proc naWindowFocus*(id: uint32) {.importc: "na_window_focus".}
proc naWindowBlur*(id: uint32) {.importc: "na_window_blur".}
proc naWindowIsFocused*(id: uint32): bool {.importc: "na_window_is_focused".}
proc naWindowShow*(id: uint32) {.importc: "na_window_show".}
proc naWindowShowInactive*(id: uint32) {.importc: "na_window_show_inactive".}
proc naWindowHide*(id: uint32) {.importc: "na_window_hide".}
proc naWindowIsVisible*(id: uint32): bool {.importc: "na_window_is_visible".}
proc naWindowMaximize*(id: uint32) {.importc: "na_window_maximize".}
proc naWindowUnmaximize*(id: uint32) {.importc: "na_window_unmaximize".}
proc naWindowIsMaximized*(id: uint32): bool {.importc: "na_window_is_maximized".}
proc naWindowMinimize*(id: uint32) {.importc: "na_window_minimize".}
proc naWindowRestore*(id: uint32) {.importc: "na_window_restore".}
proc naWindowIsMinimized*(id: uint32): bool {.
  importc: "na_window_is_minimized".}
proc naWindowSetFullScreen*(id: uint32, fullScreen: bool) {.
  importc: "na_window_set_full_screen".}
proc naWindowIsFullScreen*(id: uint32): bool {.
  importc: "na_window_is_full_screen".}
proc naWindowSetBounds*(id: uint32, x, y, w, h: float64) {.
  importc: "na_window_set_bounds".}
proc naWindowGetBounds*(id: uint32, outX, outY, outW, outH: ptr float64) {.
  importc: "na_window_get_bounds".}
proc naWindowSetSize*(id: uint32, w, h: float64, animate: bool) {.
  importc: "na_window_set_size".}
proc naWindowGetSize*(id: uint32, outW, outH: ptr float64) {.
  importc: "na_window_get_size".}
proc naWindowSetContentSize*(id: uint32, w, h: float64) {.
  importc: "na_window_set_content_size".}
proc naWindowSetMaxSize*(id: uint32, w, h: float64) {.
  importc: "na_window_set_max_size".}
proc naWindowSetMinSize*(id: uint32, w, h: float64) {.
  importc: "na_window_set_min_size".}
proc naWindowGetContentSize*(id: uint32, outW, outH: ptr float64) {.
  importc: "na_window_get_content_size".}
proc naWindowSetContentBounds*(id: uint32, x, y, w, h: float64) {.
  importc: "na_window_set_content_bounds".}
proc naWindowGetContentBounds*(id: uint32, outX, outY, outW, outH: ptr float64) {.
  importc: "na_window_get_content_bounds".}
proc naWindowSetMinimumSize*(id: uint32, w, h: float64) {.
  importc: "na_window_set_minimum_size".}
proc naWindowGetMinimumSize*(id: uint32, outW, outH: ptr float64) {.
  importc: "na_window_get_minimum_size".}
proc naWindowSetMaximumSize*(id: uint32, w, h: float64) {.
  importc: "na_window_set_maximum_size".}
proc naWindowGetMaximumSize*(id: uint32, outW, outH: ptr float64) {.
  importc: "na_window_get_maximum_size".}
proc naWindowSetPosition*(id: uint32, x, y: float64) {.
  importc: "na_window_set_position".}
proc naWindowGetPosition*(id: uint32, outX, outY: ptr float64) {.
  importc: "na_window_get_position".}
proc naWindowCenter*(id: uint32) {.importc: "na_window_center".}
proc naWindowSetTitle*(id: uint32, title: cstring) {.
  importc: "na_window_set_title".}
proc naWindowGetTitle*(id: uint32): cstring {.importc: "na_window_get_title".}
proc naWindowSetResizable*(id: uint32, resizable: bool) {.
  importc: "na_window_set_resizable".}
proc naWindowIsResizable*(id: uint32): bool {.
  importc: "na_window_is_resizable".}
proc naWindowSetMovable*(id: uint32, movable: bool) {.
  importc: "na_window_set_movable".}
proc naWindowIsMovable*(id: uint32): bool {.importc: "na_window_is_movable".}
proc naWindowSetMinimizable*(id: uint32, minimizable: bool) {.
  importc: "na_window_set_minimizable".}
proc naWindowIsMinimizable*(id: uint32): bool {.
  importc: "na_window_is_minimizable".}
proc naWindowSetMaximizable*(id: uint32, maximizable: bool) {.
  importc: "na_window_set_maximizable".}
proc naWindowIsMaximizable*(id: uint32): bool {.
  importc: "na_window_is_maximizable".}
proc naWindowSetClosable*(id: uint32, closable: bool) {.
  importc: "na_window_set_closable".}
proc naWindowIsClosable*(id: uint32): bool {.
  importc: "na_window_is_closable".}
proc naWindowSetAlwaysOnTop*(id: uint32, alwaysOnTop: bool) {.
  importc: "na_window_set_always_on_top".}
proc naWindowIsAlwaysOnTop*(id: uint32): bool {.
  importc: "na_window_is_always_on_top".}
proc naWindowSetVisibleOnAllWorkspaces*(id: uint32, visible: bool) {.
  importc: "na_window_set_visible_on_all_workspaces".}
proc naWindowIsVisibleOnAllWorkspaces*(id: uint32): bool {.
  importc: "na_window_is_visible_on_all_workspaces".}
proc naWindowSetIgnoreMouseEvents*(id: uint32, ignore: bool) {.
  importc: "na_window_set_ignore_mouse_events".}
proc naWindowIsIgnoreMouseEvents*(id: uint32): bool {.
  importc: "na_window_is_ignore_mouse_events".}
proc naWindowIsFocusable*(id: uint32): bool {.
  importc: "na_window_is_focusable".}
proc naWindowSetHasShadow*(id: uint32, hasShadow: bool) {.
  importc: "na_window_set_has_shadow".}
proc naWindowHasShadow*(id: uint32): bool {.importc: "na_window_has_shadow".}
proc naWindowSetOpacity*(id: uint32, opacity: cfloat) {.
  importc: "na_window_set_opacity".}
proc naWindowGetOpacity*(id: uint32): cfloat {.
  importc: "na_window_get_opacity".}
proc naWindowSetBackgroundColor*(id: uint32, r, g, b, a: uint8) {.
  importc: "na_window_set_background_color".}
proc naWindowGetBackgroundColor*(id: uint32, outR, outG, outB, outA: ptr uint8) {.
  importc: "na_window_get_background_color".}
proc naWindowSetTitleBarStyle*(id: uint32, style: cint) {.
  importc: "na_window_set_title_bar_style".}
proc naWindowGetTitleBarStyle*(id: uint32): cint {.
  importc: "na_window_get_title_bar_style".}
proc naWindowSetVisualEffect*(id: uint32, effect: cint) {.
  importc: "na_window_set_visual_effect".}
proc naWindowGetVisualEffect*(id: uint32): cint {.
  importc: "na_window_get_visual_effect".}
proc naWindowStartDragging*(id: uint32) {.
  importc: "na_window_start_dragging".}
proc naWindowListIds*(outIds: ptr uint32, maxCount: cint): cint {.
  importc: "na_window_list_ids".}
proc naWindowMainWindowId*(): uint32 {.
  importc: "na_window_main_window_id".}
proc naWindowSetEventCallback*(fn: NaWindowEventFn, ctx: pointer) {.
  importc: "na_window_set_event_callback".}
proc naWindowNative*(id: uint32): pointer {.importc: "na_window_native".}
proc naWindowContentView*(id: uint32): pointer {.
  importc: "na_window_content_view".}
proc naWindowSetRootView*(id: uint32, viewPtr: pointer) {.
  importc: "na_window_set_root_view".}

# --- app & device info -------------------------------------------------------

proc naAppInfoName*(): cstring {.importc: "na_app_info_name".}
proc naAppInfoIdentifier*(): cstring {.importc: "na_app_info_identifier".}
proc naAppInfoVersion*(): cstring {.importc: "na_app_info_version".}
proc naAppInfoBuildNumber*(): cstring {.importc: "na_app_info_build_number".}
proc naDeviceInfoName*(): cstring {.importc: "na_device_info_name".}
proc naDeviceInfoModel*(): cstring {.importc: "na_device_info_model".}
proc naDeviceInfoOsVersion*(): cstring {.importc: "na_device_info_os_version".}

# --- gui targets (widgets build on these) -----------------------------------

type
  NaGuiActionFn* = proc(widgetId: uint32, ctx: pointer) {.cdecl.}
  NaFrameChangedFn* = proc(width: cdouble, height: cdouble,
                           ctx: pointer) {.cdecl.}

proc naViewCreate*(): pointer {.importc: "na_view_create".}
proc naViewDestroy*(viewPtr: pointer) {.importc: "na_view_destroy".}
proc naViewSetFrame*(viewPtr: pointer, x, y, w, h: float64) {.
  importc: "na_view_set_frame".}
proc naViewGetFrame*(viewPtr: pointer, outX, outY, outW, outH: ptr float64) {.
  importc: "na_view_get_frame".}
proc naViewAddSubview*(parentPtr, childPtr: pointer) {.
  importc: "na_view_add_subview".}
proc naViewRemoveFromParent*(viewPtr: pointer) {.
  importc: "na_view_remove_from_parent".}
proc naViewRemoveAll*(parentPtr: pointer) {.importc: "na_view_remove_all".}
proc naViewSubviewCount*(parentPtr: pointer): cint {.
  importc: "na_view_subview_count".}
proc naViewSetHidden*(viewPtr: pointer, hidden: bool) {.
  importc: "na_view_set_hidden".}
proc naViewIsHidden*(viewPtr: pointer): bool {.importc: "na_view_is_hidden".}
proc naViewLayout*(viewPtr: pointer) {.importc: "na_view_layout".}
proc naViewConstrainFill*(parentPtr, childPtr: pointer,
                          left, top, right, bottom: float64) {.
  importc: "na_view_constrain_fill".}
proc naViewConstrainFillSuperview*(childPtr: pointer,
                                   left, top, right, bottom: float64) {.
  importc: "na_view_constrain_fill_superview".}
proc naViewConstrainSize*(viewPtr: pointer, width, height: float64) {.
  importc: "na_view_constrain_size".}
proc naViewSetContentHugging*(viewPtr: pointer, orientation: cint,
                              priority: float64) {.
  importc: "na_view_set_content_hugging".}
proc naViewMeasure*(viewPtr: pointer, maxWidth: float64,
                    maxHeight: float64, outW: ptr float64,
                    outH: ptr float64) {.importc: "na_view_measure".}
proc naViewSetBackgroundColor*(viewPtr: pointer, r, g, b, a: uint8) {.
  importc: "na_view_set_background_color".}
proc naViewClearBackgroundColor*(viewPtr: pointer) {.
  importc: "na_view_clear_background_color".}
proc naViewSetBorder*(viewPtr: pointer, r, g, b, a: uint8, width: float64) {.
  importc: "na_view_set_border".}
proc naViewSetCornerRadius*(viewPtr: pointer, radius: float64) {.
  importc: "na_view_set_corner_radius".}
proc naViewSetAlpha*(viewPtr: pointer, alpha: float64) {.
  importc: "na_view_set_alpha".}
proc naViewGetAlpha*(viewPtr: pointer): float64 {.
  importc: "na_view_get_alpha".}
proc naViewSetWantsLayer*(viewPtr: pointer, wants: bool) {.
  importc: "na_view_set_wants_layer".}
proc naViewSetTag*(viewPtr: pointer, tag: cint) {.importc: "na_view_set_tag".}
proc naViewGetTag*(viewPtr: pointer): cint {.importc: "na_view_get_tag".}
proc naViewSetTooltip*(viewPtr: pointer, tooltip: cstring) {.
  importc: "na_view_set_tooltip".}
proc naViewGetTooltip*(viewPtr: pointer): cstring {.
  importc: "na_view_get_tooltip".}
proc naViewSetFrameCallback*(viewPtr: pointer, fn: NaFrameChangedFn,
                             ctx: pointer) {.
  importc: "na_view_set_frame_callback".}
proc naViewSetDropEnabled*(viewPtr: pointer, enabled: bool, widgetId: cuint) {.
  importc: "na_view_set_drop_enabled".}

# --- theme ------------------------------------------------------------------

proc naThemeIsDark*(): bool {.importc: "na_theme_is_dark".}
proc naThemeAccentColor*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_accent_color".}
proc naThemeSetChangedCallback*(fn: pointer, ctx: pointer) {.
  importc: "na_theme_set_changed_callback".}
proc naThemeLabelColor*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_label_color".}
proc naThemeSecondaryLabelColor*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_secondary_label_color".}
proc naThemeTertiaryLabelColor*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_tertiary_label_color".}
proc naThemeQuaternaryLabelColor*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_quaternary_label_color".}
proc naThemePlaceholderTextColor*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_placeholder_text_color".}
proc naThemeControlTextColor*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_control_text_color".}
proc naThemeWindowBackgroundColor*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_window_background_color".}
proc naThemeControlBackgroundColor*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_control_background_color".}
proc naThemeTextBackgroundColor*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_text_background_color".}
proc naThemeSeparatorColor*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_separator_color".}
proc naThemeSelectedContentColor*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_selected_content_color".}
proc naThemeSystemRed*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_system_red".}
proc naThemeSystemGreen*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_system_green".}
proc naThemeSystemBlue*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_system_blue".}
proc naThemeSystemOrange*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_system_orange".}
proc naThemeSystemYellow*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_system_yellow".}
proc naThemeSystemPurple*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_system_purple".}
proc naThemeSystemPink*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_system_pink".}
proc naThemeSystemTeal*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_system_teal".}
proc naThemeSystemIndigo*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_system_indigo".}
proc naThemeSystemMint*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_system_mint".}
proc naThemeSystemCyan*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_system_cyan".}
proc naThemeSystemBrown*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_system_brown".}
proc naThemeSystemGray*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_system_gray".}

# --- labels -----------------------------------------------------------------

proc naLabelCreate*(): pointer {.importc: "na_label_create".}
proc naLabelFree*(viewPtr: pointer) {.importc: "na_label_free".}
proc naLabelSetText*(viewPtr: pointer, text: cstring) {.
  importc: "na_label_set_text".}
proc naLabelGetText*(viewPtr: pointer): cstring {.
  importc: "na_label_get_text".}
proc naLabelSetFontSize*(viewPtr: pointer, size: float64) {.
  importc: "na_label_set_font_size".}
proc naLabelSetFontWeight*(viewPtr: pointer, weight: cint) {.
  importc: "na_label_set_font_weight".}
proc naLabelSetAlignment*(viewPtr: pointer, alignment: cint) {.
  importc: "na_label_set_alignment".}
proc naLabelSetTextColor*(viewPtr: pointer, r, g, b, a: uint8) {.
  importc: "na_label_set_text_color".}
proc naLabelSetWraps*(viewPtr: pointer, wraps: bool, maxLines: cint) {.
  importc: "na_label_set_wraps".}

# --- buttons ----------------------------------------------------------------

type
  NaButtonEventFn* = proc(widgetId: uint32, ctx: pointer) {.cdecl.}

proc naButtonSetEventCallback*(fn: NaButtonEventFn, ctx: pointer) {.
  importc: "na_button_set_event_callback".}
proc naButtonCreate*(widgetId: uint32, style: cint): pointer {.
  importc: "na_button_create".}
proc naButtonFree*(widgetId: uint32, viewPtr: pointer) {.
  importc: "na_button_free".}
proc naButtonSetTitle*(viewPtr: pointer, title: cstring) {.
  importc: "na_button_set_title".}
proc naButtonGetTitle*(viewPtr: pointer): cstring {.
  importc: "na_button_get_title".}
proc naButtonSetState*(viewPtr: pointer, state: cint) {.
  importc: "na_button_set_state".}
proc naButtonGetState*(viewPtr: pointer): cint {.
  importc: "na_button_get_state".}
proc naButtonSetEnabled*(viewPtr: pointer, enabled: bool) {.
  importc: "na_button_set_enabled".}
proc naButtonIsEnabled*(viewPtr: pointer): bool {.
  importc: "na_button_is_enabled".}
proc naButtonFire*(widgetId: uint32) {.importc: "na_button_fire".}

# --- separators ------------------------------------------------------------

proc naSeparatorCreate*(orientation: cint): pointer {.
  importc: "na_separator_create".}
proc naSeparatorFree*(viewPtr: pointer) {.importc: "na_separator_free".}
proc naSeparatorSetThickness*(viewPtr: pointer, t: float64) {.
  importc: "na_separator_set_thickness".}

# --- progress ---------------------------------------------------------------

proc naProgressCreate*(style: cint): pointer {.
  importc: "na_progress_create".}
proc naProgressFree*(viewPtr: pointer) {.importc: "na_progress_free".}
proc naProgressSetValue*(viewPtr: pointer, value: float64) {.
  importc: "na_progress_set_value".}
proc naProgressGetValue*(viewPtr: pointer): float64 {.
  importc: "na_progress_get_value".}
proc naProgressSetIndeterminate*(viewPtr: pointer, v: bool) {.
  importc: "na_progress_set_indeterminate".}
proc naProgressIsIndeterminate*(viewPtr: pointer): bool {.
  importc: "na_progress_is_indeterminate".}

# --- switch -----------------------------------------------------------------

type
  NaSwitchEventFn* = proc (widgetId: uint32; ctx: pointer) {.cdecl.}

proc naSwitchSetEventCallback*(fn: NaSwitchEventFn; ctx: pointer) {.
  importc: "na_switch_set_event_callback".}
proc naSwitchCreate*(widgetId: uint32): pointer {.
  importc: "na_switch_create".}
proc naSwitchFree*(widgetId: uint32; viewPtr: pointer) {.
  importc: "na_switch_free".}
proc naSwitchSetState*(viewPtr: pointer; state: bool) {.
  importc: "na_switch_set_state".}
proc naSwitchGetState*(viewPtr: pointer): bool {.
  importc: "na_switch_get_state".}
proc naSwitchFire*(widgetId: uint32) {.importc: "na_switch_fire".}

# --- slider -----------------------------------------------------------------

type
  NaSliderEventFn* = proc (widgetId: uint32; value: float64; dragging: bool;
                           ctx: pointer) {.cdecl.}

proc naSliderSetEventCallback*(fn: NaSliderEventFn; ctx: pointer) {.
  importc: "na_slider_set_event_callback".}
proc naSliderCreate*(widgetId: uint32): pointer {.
  importc: "na_slider_create".}
proc naSliderFree*(widgetId: uint32; viewPtr: pointer) {.
  importc: "na_slider_free".}
proc naSliderSetRange*(viewPtr: pointer; min, max: float64) {.
  importc: "na_slider_set_range".}
proc naSliderGetMin*(viewPtr: pointer): float64 {.
  importc: "na_slider_get_min".}
proc naSliderGetMax*(viewPtr: pointer): float64 {.
  importc: "na_slider_get_max".}
proc naSliderSetValue*(viewPtr: pointer; value: float64) {.
  importc: "na_slider_set_value".}
proc naSliderGetValue*(viewPtr: pointer): float64 {.
  importc: "na_slider_get_value".}

# --- segmented --------------------------------------------------------------

type
  NaSegmentedEventFn* = proc (widgetId: uint32; index: int64;
                              ctx: pointer) {.cdecl.}

proc naSegmentedSetEventCallback*(fn: NaSegmentedEventFn; ctx: pointer) {.
  importc: "na_segmented_set_event_callback".}
proc naSegmentedCreate*(widgetId: uint32): pointer {.
  importc: "na_segmented_create".}
proc naSegmentedFree*(widgetId: uint32; viewPtr: pointer) {.
  importc: "na_segmented_free".}
proc naSegmentedSetLabels*(viewPtr: pointer; labels: ptr cstring;
                           count: cint) {.importc: "na_segmented_set_labels".}
proc naSegmentedCount*(viewPtr: pointer): cint {.
  importc: "na_segmented_count".}
proc naSegmentedSelected*(viewPtr: pointer): int64 {.
  importc: "na_segmented_selected".}
proc naSegmentedSelect*(viewPtr: pointer; index: int64) {.
  importc: "na_segmented_select".}
proc naSegmentedFire*(widgetId: uint32; viewPtr: pointer) {.
  importc: "na_segmented_fire".}

# --- stack ------------------------------------------------------------------

proc naStackCreate*(orientation: cint): pointer {.
  importc: "na_stack_create".}
proc naStackFree*(viewPtr: pointer) {.importc: "na_stack_free".}
proc naStackSetSpacing*(viewPtr: pointer; spacing: float64) {.
  importc: "na_stack_set_spacing".}
proc naStackSetPadding*(viewPtr: pointer; left, top, right, bottom: float64) {.
  importc: "na_stack_set_padding".}
proc naStackSetAlignment*(viewPtr: pointer; alignment: cint) {.
  importc: "na_stack_set_alignment".}
proc naStackAddArranged*(stackPtr, childPtr: pointer) {.
  importc: "na_stack_add_arranged".}
proc naStackInsertArranged*(stackPtr, childPtr: pointer; index: cint) {.
  importc: "na_stack_insert_arranged".}
proc naStackSetArrangedFill*(viewPtr: pointer; fill: bool) {.
  importc: "na_stack_set_arranged_fill".}
proc naStackRemoveArranged*(stackPtr, childPtr: pointer) {.
  importc: "na_stack_remove_arranged".}
proc naStackArrangedCount*(stackPtr: pointer): cint {.
  importc: "na_stack_arranged_count".}

# --- scroll -----------------------------------------------------------------

proc naScrollCreate*(): pointer {.importc: "na_scroll_create".}
proc naScrollFree*(viewPtr: pointer) {.importc: "na_scroll_free".}
proc naScrollSetDocument*(scrollPtr, docPtr: pointer) {.
  importc: "na_scroll_set_document".}
proc naScrollFitWidth*(scrollPtr: pointer; leftInset, rightInset: float64) {.
  importc: "na_scroll_fit_width".}
proc naScrollSetHasVerticalBar*(scrollPtr: pointer; has: bool) {.
  importc: "na_scroll_set_has_vertical_bar".}
proc naScrollSetHasHorizontalBar*(scrollPtr: pointer; has: bool) {.
  importc: "na_scroll_set_has_horizontal_bar".}
proc naScrollSetBorder*(scrollPtr: pointer; bordered: bool) {.
  importc: "na_scroll_set_border".}
proc naScrollSetBackground*(scrollPtr: pointer; r, g, b, a: uint8) {.
  importc: "na_scroll_set_background".}

# --- input ------------------------------------------------------------------

type
  NaInputEventFn* = proc (widgetId: uint32; ctx: pointer) {.cdecl.}

proc naInputSetEventCallback*(fn: NaInputEventFn; ctx: pointer) {.
  importc: "na_input_set_event_callback".}
proc naInputCreate*(widgetId: uint32; style: cint): pointer {.
  importc: "na_input_create".}
proc naInputFree*(widgetId: uint32; viewPtr: pointer) {.
  importc: "na_input_free".}
proc naInputSetText*(viewPtr: pointer; text: cstring) {.
  importc: "na_input_set_text".}
proc naInputGetText*(viewPtr: pointer): cstring {.
  importc: "na_input_get_text".}
proc naInputSetPlaceholder*(viewPtr: pointer; placeholder: cstring) {.
  importc: "na_input_set_placeholder".}
proc naInputGetPlaceholder*(viewPtr: pointer): cstring {.
  importc: "na_input_get_placeholder".}
proc naInputSetEditable*(viewPtr: pointer; editable: bool) {.
  importc: "na_input_set_editable".}
proc naInputIsEditable*(viewPtr: pointer): bool {.
  importc: "na_input_is_editable".}
proc naInputFocus*(widgetId: uint32; viewPtr: pointer) {.
  importc: "na_input_focus".}
proc naInputFireChange*(widgetId: uint32) {.importc: "na_input_fire_change".}

# --- textarea ---------------------------------------------------------------

type
  NaTextAreaEventFn* = proc (widgetId: uint32; ctx: pointer) {.cdecl.}

proc naTextAreaSetEventCallback*(fn: NaTextAreaEventFn; ctx: pointer) {.
  importc: "na_textarea_set_event_callback".}
proc naTextAreaCreate*(widgetId: uint32): pointer {.
  importc: "na_textarea_create".}
proc naTextAreaFree*(widgetId: uint32; viewPtr: pointer) {.
  importc: "na_textarea_free".}
proc naTextAreaSetText*(widgetId: uint32; viewPtr: pointer; text: cstring) {.
  importc: "na_textarea_set_text".}
proc naTextAreaGetText*(widgetId: uint32; viewPtr: pointer): cstring {.
  importc: "na_textarea_get_text".}
proc naTextAreaSetEditable*(widgetId: uint32; viewPtr: pointer;
                            editable: bool) {.
  importc: "na_textarea_set_editable".}
proc naTextAreaIsEditable*(widgetId: uint32; viewPtr: pointer): bool {.
  importc: "na_textarea_is_editable".}
proc naTextAreaFireChange*(widgetId: uint32) {.
  importc: "na_textarea_fire_change".}

# --- imageview --------------------------------------------------------------

proc naImageViewCreate*(): pointer {.importc: "na_image_view_create".}
proc naImageViewFree*(viewPtr: pointer) {.importc: "na_image_view_free".}
proc naImageViewSetImagePtr*(viewPtr, imagePtr: pointer) {.
  importc: "na_image_view_set_image_ptr".}
proc naImageViewSetSymbol*(viewPtr: pointer; symbolName: cstring;
                           pointSize: float64; weight: cint) {.
  importc: "na_image_view_set_symbol".}
proc naImageViewClear*(viewPtr: pointer) {.importc: "na_image_view_clear".}
proc naImageViewSetScaling*(viewPtr: pointer; scaling: cint) {.
  importc: "na_image_view_set_scaling".}

# --- select -----------------------------------------------------------------

type
  NaSelectEventFn* = proc (widgetId: uint32; index: int64;
                           ctx: pointer) {.cdecl.}

proc naSelectSetEventCallback*(fn: NaSelectEventFn; ctx: pointer) {.
  importc: "na_select_set_event_callback".}
proc naSelectCreate*(widgetId: uint32): pointer {.
  importc: "na_select_create".}
proc naSelectFree*(widgetId: uint32; viewPtr: pointer) {.
  importc: "na_select_free".}
proc naSelectAddItem*(viewPtr: pointer; title: cstring) {.
  importc: "na_select_add_item".}
proc naSelectClear*(viewPtr: pointer) {.importc: "na_select_clear".}
proc naSelectCount*(viewPtr: pointer): cint {.importc: "na_select_count".}
proc naSelectSelected*(viewPtr: pointer): int64 {.
  importc: "na_select_selected".}
proc naSelectChoose*(viewPtr: pointer; index: int64) {.
  importc: "na_select_choose".}
proc naSelectSelectedTitle*(viewPtr: pointer): cstring {.
  importc: "na_select_selected_title".}

# --- datepicker -------------------------------------------------------------

type
  NaDatePickerEventFn* = proc (widgetId: uint32; unixSeconds: float64;
                               ctx: pointer) {.cdecl.}

proc naDatePickerSetEventCallback*(fn: NaDatePickerEventFn; ctx: pointer) {.
  importc: "na_datepicker_set_event_callback".}
proc naDatePickerCreate*(widgetId: uint32; style: cint): pointer {.
  importc: "na_datepicker_create".}
proc naDatePickerFree*(widgetId: uint32; viewPtr: pointer) {.
  importc: "na_datepicker_free".}
proc naDatePickerSetUnixSeconds*(viewPtr: pointer; seconds: float64) {.
  importc: "na_datepicker_set_unix_seconds".}
proc naDatePickerGetUnixSeconds*(viewPtr: pointer): float64 {.
  importc: "na_datepicker_get_unix_seconds".}

# --- split_view (stubs) ----------------------------------------------------

proc naSplitViewCreate*(vertical: bool): pointer {.
  importc: "na_split_view_create".}
proc naSplitViewAddPane*(svPtr, childPtr: pointer) {.
  importc: "na_split_view_add_pane".}
proc naSplitViewSetDividerThickness*(svPtr: pointer; thickness: float64) {.
  importc: "na_split_view_set_divider_thickness".}
proc naSplitViewSetPosition*(svPtr: pointer; index: cint;
                             position: float64): bool {.
  importc: "na_split_view_set_position".}
proc naSplitViewGetPosition*(svPtr: pointer; index: cint): float64 {.
  importc: "na_split_view_get_position".}
proc naSplitViewPaneCount*(svPtr: pointer): cint {.
  importc: "na_split_view_pane_count".}
proc naSplitViewSetHoldingPriority*(svPtr: pointer; index: cint;
                                    priority: float64) {.
  importc: "na_split_view_set_holding_priority".}
proc naSplitViewConstrainPane*(svPtr: pointer; index: cint;
                               minWidth, maxWidth, minHeight, maxHeight: float64) {.
  importc: "na_split_view_constrain_pane".}

# --- toast ------------------------------------------------------------------

type
  NaToastDismissFn* = proc (toastId: uint32; ctx: pointer) {.cdecl.}

proc naToastSetDismissCallback*(fn: NaToastDismissFn; ctx: pointer) {.
  importc: "na_toast_set_dismiss_callback".}
proc naToastShow*(title, message: cstring; durationMs, offsetY,
                  width: float64): uint32 {.
  importc: "na_toast_show".}
proc naToastClose*(toastId: uint32) {.importc: "na_toast_close".}
proc naToastActiveCount*(): cint {.importc: "na_toast_active_count".}
