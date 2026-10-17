{.compile: "widgets/app.m".}
{.compile: "widgets/screen.m".}
{.compile: "widgets/window.m".}
{.compile: "widgets/info.m".}
{.compile: "widgets/storage.m".}
{.compile: "widgets/services.m".}
{.compile: "widgets/menu.m".}
{.compile: "widgets/tray.m".}
{.compile: "widgets/dialog.m".}
{.compile: "widgets/image.m".}
{.compile: "widgets/keyboard.m".}
{.compile: "widgets/hotkey.m".}
{.compile: "widgets/view.m".}
{.compile: "widgets/targets.m".}
{.compile: "widgets/theme.m".}
{.compile: "widgets/button.m".}
{.compile: "widgets/label.m".}
{.compile: "widgets/separator.m".}
{.compile: "widgets/input.m".}
{.compile: "widgets/textarea.m".}
{.compile: "widgets/switch_widget.m".}
{.compile: "widgets/slider.m".}
{.compile: "widgets/progress.m".}
{.compile: "widgets/segmented.m".}
{.compile: "widgets/select.m".}
{.compile: "widgets/datepicker.m".}
{.compile: "widgets/imageview.m".}
{.compile: "widgets/stack.m".}
{.compile: "widgets/scroll.m".}
{.compile: "widgets/webview.m".}
{.compile: "widgets/hover.m".}
{.compile: "widgets/toast.m".}
{.compile: "widgets/dock.m".}
{.compile: "widgets/colorwell.m".}
{.passc: "-fobjc-arc".}
{.passl: "-framework Cocoa".}
{.passl: "-framework ApplicationServices".}
{.passl: "-framework ServiceManagement".}
{.passl: "-framework Carbon".}
{.passl: "-framework QuartzCore".}
{.passl: "-framework WebKit".}

type
  NaAppFn* = proc(ctx: pointer) {.cdecl.}
  NaAppExitFn* = proc(exitCode: cint, ctx: pointer) {.cdecl.}
  NaTaskFn* = proc(ctx: pointer) {.cdecl.}

proc naAppInit*(): bool {.importc: "na_app_init".}
proc naAppRun*(): cint {.importc: "na_app_run".}
proc naAppQuit*() {.importc: "na_app_quit".}
proc naAppStop*() {.importc: "na_app_stop".}
proc naAppSetDockMenu*(menuId: uint32) {.importc: "na_app_set_dock_menu".}
proc naAppDockMenu*(): uint32 {.importc: "na_app_dock_menu".}
proc naAppSetIcon*(utf8Path: cstring): bool {.importc: "na_app_set_icon".}
proc naAppSetDockIconVisible*(visible: bool): bool {.importc: "na_app_set_dock_icon_visible".}
proc naAppSetCallbacks*(ctx: pointer,
                        onStarted: NaAppFn,
                        onActivated: NaAppFn,
                        onDeactivated: NaAppFn,
                        onQuitRequested: NaAppFn,
                        onExiting: NaAppExitFn) {.
  importc: "na_app_set_callbacks".}
proc naAppSetDockReopenCallback*(fn: NaAppFn, ctx: pointer) {.
  importc: "na_app_set_dock_reopen_callback".}

# Dock tile (NSDockTile): badge, attention, progress overlay
proc naDockSetBadge*(label: cstring) {.importc: "na_dock_set_badge".}
proc naDockGetBadge*(): cstring {.importc: "na_dock_get_badge".}
proc naDockRequestAttention*(critical: bool): cint {.
  importc: "na_dock_request_attention".}
proc naDockCancelAttention*(requestId: cint) {.
  importc: "na_dock_cancel_attention".}
proc naDockSetProgress*(fraction: float64) {.
  importc: "na_dock_set_progress".}
proc naDockSetProgressIndeterminate*(on: bool) {.
  importc: "na_dock_set_progress_indeterminate".}
proc naDockClearProgress*() {.importc: "na_dock_clear_progress".}
proc naDockDisplay*() {.importc: "na_dock_display".}

proc naIsMainThread*(): bool {.importc: "na_is_main_thread".}
proc naDispatchMain*(fn: NaTaskFn, ctx: pointer) {.importc: "na_dispatch_main".}
proc naDispatchMainAfter*(delayMs: cint, fn: NaTaskFn, ctx: pointer) {.
  importc: "na_dispatch_main_after".}
proc naRunLoopFor*(timeoutMs: cint): bool {.importc: "na_run_main_loop_for".}

type NaScreensChangedFn* = proc(ctx: pointer) {.cdecl.}

proc naScreenCount*(): cint {.importc: "na_screen_count".}
proc naScreenDisplayId*(index: cint): uint32 {.importc: "na_screen_display_id".}
proc naScreenIsPrimary*(displayId: uint32): bool {.importc: "na_screen_is_primary".}
proc naScreenGetName*(displayId: uint32): cstring {.importc: "na_screen_get_name".}
proc naScreenGetFrame*(displayId: uint32, outX, outY, outW, outH: ptr float64) {.
  importc: "na_screen_get_frame".}
proc naScreenGetWorkArea*(displayId: uint32, outX, outY, outW, outH: ptr float64) {.
  importc: "na_screen_get_work_area".}
proc naScreenGetScaleFactor*(displayId: uint32): float64 {.importc: "na_screen_get_scale_factor".}
proc naScreenGetRefreshRate*(displayId: uint32): cint {.importc: "na_screen_get_refresh_rate".}
proc naScreenGetCursorPosition*(outX, outY: ptr float64) {.importc: "na_screen_get_cursor_position".}
proc naScreenSetChangedCallback*(fn: NaScreensChangedFn, ctx: pointer) {.
  importc: "na_screen_set_changed_callback".}

type NaWindowEventFn* = proc(kind: cint, windowId: uint32, a, b: float64, ctx: pointer) {.cdecl.}

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
proc naWindowIsMinimized*(id: uint32): bool {.importc: "na_window_is_minimized".}
proc naWindowSetFullScreen*(id: uint32, fullScreen: bool) {.importc: "na_window_set_full_screen".}
proc naWindowIsFullScreen*(id: uint32): bool {.importc: "na_window_is_full_screen".}

proc naWindowSetBounds*(id: uint32, x, y, w, h: float64) {.importc: "na_window_set_bounds".}
proc naWindowGetBounds*(id: uint32, outX, outY, outW, outH: ptr float64) {.
  importc: "na_window_get_bounds".}
proc naWindowSetSize*(id: uint32, w, h: float64, animate: bool) {.importc: "na_window_set_size".}
proc naWindowGetSize*(id: uint32, outW, outH: ptr float64) {.importc: "na_window_get_size".}
proc naWindowSetContentSize*(id: uint32, w, h: float64) {.importc: "na_window_set_content_size".}
proc naWindowSetMaxSize*(id: uint32, w, h: float64) {.importc: "na_window_set_max_size".}
proc naWindowSetMinSize*(id: uint32, w, h: float64) {.importc: "na_window_set_min_size".}
proc naWindowGetContentSize*(id: uint32, outW, outH: ptr float64) {.
  importc: "na_window_get_content_size".}
proc naWindowSetContentBounds*(id: uint32, x, y, w, h: float64) {.
  importc: "na_window_set_content_bounds".}
proc naWindowGetContentBounds*(id: uint32, outX, outY, outW, outH: ptr float64) {.
  importc: "na_window_get_content_bounds".}
proc naWindowSetMinimumSize*(id: uint32, w, h: float64) {.importc: "na_window_set_minimum_size".}
proc naWindowGetMinimumSize*(id: uint32, outW, outH: ptr float64) {.
  importc: "na_window_get_minimum_size".}
proc naWindowSetMaximumSize*(id: uint32, w, h: float64) {.importc: "na_window_set_maximum_size".}
proc naWindowGetMaximumSize*(id: uint32, outW, outH: ptr float64) {.
  importc: "na_window_get_maximum_size".}
proc naWindowSetPosition*(id: uint32, x, y: float64) {.importc: "na_window_set_position".}
proc naWindowGetPosition*(id: uint32, outX, outY: ptr float64) {.
  importc: "na_window_get_position".}
proc naWindowCenter*(id: uint32) {.importc: "na_window_center".}

proc naWindowSetTitle*(id: uint32, title: cstring) {.importc: "na_window_set_title".}
proc naWindowGetTitle*(id: uint32): cstring {.importc: "na_window_get_title".}

proc naWindowSetResizable*(id: uint32, resizable: bool) {.importc: "na_window_set_resizable".}
proc naWindowIsResizable*(id: uint32): bool {.importc: "na_window_is_resizable".}
proc naWindowSetMovable*(id: uint32, movable: bool) {.importc: "na_window_set_movable".}
proc naWindowIsMovable*(id: uint32): bool {.importc: "na_window_is_movable".}
proc naWindowSetMinimizable*(id: uint32, minimizable: bool) {.importc: "na_window_set_minimizable".}
proc naWindowIsMinimizable*(id: uint32): bool {.importc: "na_window_is_minimizable".}
proc naWindowSetMaximizable*(id: uint32, maximizable: bool) {.importc: "na_window_set_maximizable".}
proc naWindowIsMaximizable*(id: uint32): bool {.importc: "na_window_is_maximizable".}
proc naWindowSetClosable*(id: uint32, closable: bool) {.importc: "na_window_set_closable".}
proc naWindowIsClosable*(id: uint32): bool {.importc: "na_window_is_closable".}
proc naWindowSetAlwaysOnTop*(id: uint32, alwaysOnTop: bool) {.importc: "na_window_set_always_on_top".}
proc naWindowIsAlwaysOnTop*(id: uint32): bool {.importc: "na_window_is_always_on_top".}
proc naWindowSetVisibleOnAllWorkspaces*(id: uint32, visible: bool) {.
  importc: "na_window_set_visible_on_all_workspaces".}
proc naWindowIsVisibleOnAllWorkspaces*(id: uint32): bool {.
  importc: "na_window_is_visible_on_all_workspaces".}
proc naWindowSetIgnoreMouseEvents*(id: uint32, ignore: bool) {.
  importc: "na_window_set_ignore_mouse_events".}
proc naWindowIsIgnoreMouseEvents*(id: uint32): bool {.importc: "na_window_is_ignore_mouse_events".}
proc naWindowIsFocusable*(id: uint32): bool {.importc: "na_window_is_focusable".}

proc naWindowSetHasShadow*(id: uint32, hasShadow: bool) {.importc: "na_window_set_has_shadow".}
proc naWindowHasShadow*(id: uint32): bool {.importc: "na_window_has_shadow".}
proc naWindowSetOpacity*(id: uint32, opacity: cfloat) {.importc: "na_window_set_opacity".}
proc naWindowGetOpacity*(id: uint32): cfloat {.importc: "na_window_get_opacity".}
proc naWindowSetBackgroundColor*(id: uint32, r, g, b, a: uint8) {.
  importc: "na_window_set_background_color".}
proc naWindowGetBackgroundColor*(id: uint32, outR, outG, outB, outA: ptr uint8) {.
  importc: "na_window_get_background_color".}

proc naWindowSetTitleBarStyle*(id: uint32, style: cint) {.importc: "na_window_set_title_bar_style".}
proc naWindowGetTitleBarStyle*(id: uint32): cint {.importc: "na_window_get_title_bar_style".}
proc naWindowSetDragRegion*(id: uint32, height: float64) {.importc: "na_window_set_drag_region".}
proc naWindowGetDragRegion*(id: uint32): float64 {.importc: "na_window_get_drag_region".}
proc naWindowSetVisualEffect*(id: uint32, effect: cint) {.importc: "na_window_set_visual_effect".}
proc naWindowGetVisualEffect*(id: uint32): cint {.importc: "na_window_get_visual_effect".}

proc naWindowStartDragging*(id: uint32) {.importc: "na_window_start_dragging".}
proc naWindowListIds*(outIds: ptr uint32, maxCount: cint): cint {.importc: "na_window_list_ids".}
proc naWindowMainWindowId*(): uint32 {.importc: "na_window_main_window_id".}
proc naWindowSetEventCallback*(fn: NaWindowEventFn, ctx: pointer) {.
  importc: "na_window_set_event_callback".}

proc naWindowContentView*(id: uint32): pointer {.importc: "na_window_content_view".}
proc naWindowSetRootView*(id: uint32, viewPtr: pointer) {.importc: "na_window_set_root_view".}

type
  NaDropEventFn* = proc(widgetId: cuint, paths: ptr cstring, count: cint,
                        ctx: pointer) {.cdecl.}

proc naDropSetEventCallback*(fn: NaDropEventFn, ctx: pointer) {.importc: "na_drop_set_event_callback".}
proc naViewSetDropEnabled*(viewPtr: pointer, enabled: bool, widgetId: cuint) {.importc: "na_view_set_drop_enabled".}
proc naViewCreate*(): pointer {.importc: "na_view_create".}

type NaButtonEventFn* = proc(widgetId: uint32, ctx: pointer) {.cdecl.}

proc naButtonSetEventCallback*(fn: NaButtonEventFn, ctx: pointer) {.
  importc: "na_button_set_event_callback".}
proc naButtonCreate*(widgetId: uint32, style: cint): pointer {.importc: "na_button_create".}
proc naButtonFree*(widgetId: uint32, viewPtr: pointer) {.importc: "na_button_free".}
proc naButtonSetTitle*(viewPtr: pointer, title: cstring) {.importc: "na_button_set_title".}
proc naButtonGetTitle*(viewPtr: pointer): cstring {.importc: "na_button_get_title".}
proc naButtonSetState*(viewPtr: pointer, state: cint) {.importc: "na_button_set_state".}
proc naButtonGetState*(viewPtr: pointer): cint {.importc: "na_button_get_state".}
proc naButtonSetEnabled*(viewPtr: pointer, enabled: bool) {.importc: "na_button_set_enabled".}
proc naButtonIsEnabled*(viewPtr: pointer): bool {.importc: "na_button_is_enabled".}
proc naButtonSetSymbol*(viewPtr: pointer, symbolName: cstring) {.
  importc: "na_button_set_symbol".}
proc naButtonSetBordered*(viewPtr: pointer, bordered: bool) {.
  importc: "na_button_set_bordered".}
proc naButtonIsBordered*(viewPtr: pointer): bool {.
  importc: "na_button_is_bordered".}
proc naButtonFire*(widgetId: uint32) {.importc: "na_button_fire".}

proc naLabelCreate*(): pointer {.importc: "na_label_create".}
proc naLabelFree*(viewPtr: pointer) {.importc: "na_label_free".}
proc naLabelSetText*(viewPtr: pointer, text: cstring) {.importc: "na_label_set_text".}
proc naLabelGetText*(viewPtr: pointer): cstring {.importc: "na_label_get_text".}
proc naLabelSetTextColor*(viewPtr: pointer, r, g, b, a: uint8) {.
  importc: "na_label_set_text_color".}
proc naLabelSetFontSize*(viewPtr: pointer, size: float64) {.importc: "na_label_set_font_size".}
proc naLabelSetFontWeight*(viewPtr: pointer, weight: cint) {.
  importc: "na_label_set_font_weight".}
proc naLabelSetAlignment*(viewPtr: pointer, alignment: cint) {.
  importc: "na_label_set_alignment".}
proc naLabelSetWraps*(viewPtr: pointer, wraps: bool, maxLines: cint) {.
  importc: "na_label_set_wraps".}

proc naSeparatorCreate*(orientation: cint): pointer {.importc: "na_separator_create".}
proc naSeparatorFree*(viewPtr: pointer) {.importc: "na_separator_free".}
proc naSeparatorSetThickness*(viewPtr: pointer, thickness: float64) {.
  importc: "na_separator_set_thickness".}

type NaColorwellEventFn* = proc(widgetId: uint32, ctx: pointer) {.cdecl.}

proc naColorwellSetEventCallback*(fn: NaColorwellEventFn, ctx: pointer) {.
  importc: "na_colorwell_set_event_callback".}
proc naColorwellCreate*(widgetId: uint32): pointer {.
  importc: "na_colorwell_create".}
proc naColorwellFree*(widgetId: uint32, viewPtr: pointer) {.
  importc: "na_colorwell_free".}
proc naColorwellSetColor*(viewPtr: pointer, r, g, b, a: uint8) {.
  importc: "na_colorwell_set_color".}
proc naColorwellGetColor*(viewPtr: pointer, outR, outG, outB, outA: ptr uint8) {.
  importc: "na_colorwell_get_color".}
proc naColorwellSetEnabled*(viewPtr: pointer, enabled: bool) {.
  importc: "na_colorwell_set_enabled".}
proc naColorwellIsEnabled*(viewPtr: pointer): bool {.
  importc: "na_colorwell_is_enabled".}
proc naColorwellFire*(widgetId: uint32) {.importc: "na_colorwell_fire".}

type NaInputEventFn* = proc(widgetId: uint32, ctx: pointer) {.cdecl.}

proc naInputSetEventCallback*(fn: NaInputEventFn, ctx: pointer) {.
  importc: "na_input_set_event_callback".}
proc naInputCreate*(widgetId: uint32, style: cint): pointer {.importc: "na_input_create".}
proc naInputFree*(widgetId: uint32, viewPtr: pointer) {.importc: "na_input_free".}
proc naInputSetText*(viewPtr: pointer, text: cstring) {.importc: "na_input_set_text".}
proc naInputGetText*(viewPtr: pointer): cstring {.importc: "na_input_get_text".}
proc naInputSetPlaceholder*(viewPtr: pointer, placeholder: cstring) {.
  importc: "na_input_set_placeholder".}
proc naInputGetPlaceholder*(viewPtr: pointer): cstring {.
  importc: "na_input_get_placeholder".}
proc naInputSetEditable*(viewPtr: pointer, editable: bool) {.
  importc: "na_input_set_editable".}
proc naInputIsEditable*(viewPtr: pointer): bool {.importc: "na_input_is_editable".}
proc naInputFocus*(widgetId: uint32, viewPtr: pointer) {.importc: "na_input_focus".}
proc naInputFireChange*(widgetId: uint32) {.importc: "na_input_fire_change".}
proc naInputFireSubmit*(widgetId: uint32) {.importc: "na_input_fire_submit".}

# Linux-ported input event channels (focus/hover/key). Modifier bits:
# 0=Shift, 1=Control, 2=Alt, 3=Command.
type NaInputFocusFn* = proc(widgetId: uint32, focused: bool, ctx: pointer) {.cdecl.}
type NaInputHoverFn* = proc(widgetId: uint32, entered: bool, ctx: pointer) {.cdecl.}
type NaInputKeyFn* = proc(widgetId: uint32, keyval, keycode, mods: uint32,
                          pressed: bool, ctx: pointer) {.cdecl.}

proc naInputSetFocusCallback*(fn: NaInputFocusFn, ctx: pointer) {.
  importc: "na_input_set_focus_callback".}
proc naInputSetHoverCallback*(fn: NaInputHoverFn, ctx: pointer) {.
  importc: "na_input_set_hover_callback".}
proc naInputSetKeyCallback*(fn: NaInputKeyFn, ctx: pointer) {.
  importc: "na_input_set_key_callback".}

type NaTextAreaEventFn* = proc(widgetId: uint32, ctx: pointer) {.cdecl.}
type NaTextAreaFocusFn* = proc(widgetId: uint32, focused: bool,
                               ctx: pointer) {.cdecl.}

proc naTextAreaSetEventCallback*(fn: NaTextAreaEventFn, ctx: pointer) {.
  importc: "na_textarea_set_event_callback".}
proc naTextAreaSetFocusCallback*(fn: NaTextAreaFocusFn, ctx: pointer) {.
  importc: "na_textarea_set_focus_callback".}
proc naTextAreaCreate*(widgetId: uint32): pointer {.importc: "na_textarea_create".}
proc naTextAreaFree*(widgetId: uint32, viewPtr: pointer) {.importc: "na_textarea_free".}
proc naTextAreaSetText*(widgetId: uint32, viewPtr: pointer, text: cstring) {.
  importc: "na_textarea_set_text".}
proc naTextAreaGetText*(widgetId: uint32, viewPtr: pointer): cstring {.
  importc: "na_textarea_get_text".}
proc naTextAreaSetEditable*(widgetId: uint32, viewPtr: pointer, editable: bool) {.
  importc: "na_textarea_set_editable".}
proc naTextAreaIsEditable*(widgetId: uint32, viewPtr: pointer): bool {.
  importc: "na_textarea_is_editable".}
proc naTextAreaSetAllowsUndo*(widgetId: uint32, viewPtr: pointer,
                              allow: bool) {.
  importc: "na_textarea_set_allows_undo".}
proc naTextAreaFireChange*(widgetId: uint32) {.importc: "na_textarea_fire_change".}
proc naTextAreaFireFocus*(widgetId: uint32,
                          focused: bool) {.importc: "na_textarea_fire_focus".}

type NaSwitchEventFn* = proc(widgetId: uint32, ctx: pointer) {.cdecl.}

proc naSwitchSetEventCallback*(fn: NaSwitchEventFn, ctx: pointer) {.
  importc: "na_switch_set_event_callback".}
proc naSwitchCreate*(widgetId: uint32): pointer {.importc: "na_switch_create".}
proc naSwitchFree*(widgetId: uint32, viewPtr: pointer) {.importc: "na_switch_free".}
proc naSwitchSetState*(viewPtr: pointer, on: bool) {.importc: "na_switch_set_state".}
proc naSwitchGetState*(viewPtr: pointer): bool {.importc: "na_switch_get_state".}
proc naSwitchFire*(widgetId: uint32) {.importc: "na_switch_fire".}

type NaSliderEventFn* = proc(widgetId: uint32, value: float64, released: bool, ctx: pointer) {.cdecl.}

proc naSliderSetEventCallback*(fn: NaSliderEventFn, ctx: pointer) {.
  importc: "na_slider_set_event_callback".}
proc naSliderCreate*(widgetId: uint32): pointer {.importc: "na_slider_create".}
proc naSliderFree*(widgetId: uint32, viewPtr: pointer) {.importc: "na_slider_free".}
proc naSliderSetRange*(viewPtr: pointer, minValue, maxValue: float64) {.
  importc: "na_slider_set_range".}
proc naSliderGetMin*(viewPtr: pointer): float64 {.importc: "na_slider_get_min".}
proc naSliderGetMax*(viewPtr: pointer): float64 {.importc: "na_slider_get_max".}
proc naSliderSetValue*(viewPtr: pointer, value: float64) {.importc: "na_slider_set_value".}
proc naSliderGetValue*(viewPtr: pointer): float64 {.importc: "na_slider_get_value".}

proc naProgressCreate*(style: cint): pointer {.importc: "na_progress_create".}
proc naProgressFree*(viewPtr: pointer) {.importc: "na_progress_free".}
proc naProgressSetValue*(viewPtr: pointer, value: float64) {.importc: "na_progress_set_value".}
proc naProgressGetValue*(viewPtr: pointer): float64 {.importc: "na_progress_get_value".}
proc naProgressSetIndeterminate*(viewPtr: pointer, indeterminate: bool) {.
  importc: "na_progress_set_indeterminate".}
proc naProgressIsIndeterminate*(viewPtr: pointer): bool {.
  importc: "na_progress_is_indeterminate".}

type NaSegmentedEventFn* = proc(widgetId: uint32, index: int64, ctx: pointer) {.cdecl.}

proc naSegmentedSetEventCallback*(fn: NaSegmentedEventFn, ctx: pointer) {.
  importc: "na_segmented_set_event_callback".}
proc naSegmentedCreate*(widgetId: uint32): pointer {.importc: "na_segmented_create".}
proc naSegmentedFree*(widgetId: uint32, viewPtr: pointer) {.importc: "na_segmented_free".}
proc naSegmentedSetLabels*(viewPtr: pointer, labels: ptr cstring, count: cint) {.
  importc: "na_segmented_set_labels".}
proc naSegmentedCount*(viewPtr: pointer): cint {.importc: "na_segmented_count".}
proc naSegmentedSelected*(viewPtr: pointer): int64 {.importc: "na_segmented_selected".}
proc naSegmentedSelect*(viewPtr: pointer, index: int64) {.importc: "na_segmented_select".}
proc naSegmentedFire*(widgetId: uint32, viewPtr: pointer) {.importc: "na_segmented_fire".}

type NaSelectEventFn* = proc(widgetId: uint32, index: int64, ctx: pointer) {.cdecl.}

proc naSelectSetEventCallback*(fn: NaSelectEventFn, ctx: pointer) {.
  importc: "na_select_set_event_callback".}
proc naSelectCreate*(widgetId: uint32): pointer {.importc: "na_select_create".}
proc naSelectFree*(widgetId: uint32, viewPtr: pointer) {.importc: "na_select_free".}
proc naSelectAddItem*(viewPtr: pointer, title: cstring) {.importc: "na_select_add_item".}
proc naSelectClear*(viewPtr: pointer) {.importc: "na_select_clear".}
proc naSelectCount*(viewPtr: pointer): cint {.importc: "na_select_count".}
proc naSelectSelected*(viewPtr: pointer): int64 {.importc: "na_select_selected".}
proc naSelectChoose*(viewPtr: pointer, index: int64) {.importc: "na_select_choose".}
proc naSelectSelectedTitle*(viewPtr: pointer): cstring {.importc: "na_select_selected_title".}

type NaDatePickerEventFn* = proc(widgetId: uint32, unixSeconds: float64, ctx: pointer) {.cdecl.}

proc naDatePickerSetEventCallback*(fn: NaDatePickerEventFn, ctx: pointer) {.
  importc: "na_datepicker_set_event_callback".}
proc naDatePickerCreate*(widgetId: uint32, style: cint): pointer {.
  importc: "na_datepicker_create".}
proc naDatePickerFree*(widgetId: uint32, viewPtr: pointer) {.importc: "na_datepicker_free".}
proc naDatePickerSetUnixSeconds*(viewPtr: pointer, seconds: float64) {.
  importc: "na_datepicker_set_unix_seconds".}
proc naDatePickerGetUnixSeconds*(viewPtr: pointer): float64 {.
  importc: "na_datepicker_get_unix_seconds".}

proc naImageViewCreate*(): pointer {.importc: "na_image_view_create".}
proc naImageViewFree*(viewPtr: pointer) {.importc: "na_image_view_free".}
proc naImageViewSetImagePtr*(viewPtr: pointer, imagePtr: pointer) {.
  importc: "na_image_view_set_image_ptr".}
proc naImageViewSetSymbol*(viewPtr: pointer, symbolName: cstring, pointSize: float64,
                           weight: cint) {.importc: "na_image_view_set_symbol".}
proc naImageViewClear*(viewPtr: pointer) {.importc: "na_image_view_clear".}
proc naImageViewSetScaling*(viewPtr: pointer, scaling: cint) {.
  importc: "na_image_view_set_scaling".}

proc naStackCreate*(orientation: cint): pointer {.importc: "na_stack_create".}
proc naStackFree*(viewPtr: pointer) {.importc: "na_stack_free".}
proc naStackSetSpacing*(viewPtr: pointer, spacing: float64) {.
  importc: "na_stack_set_spacing".}
proc naStackSetPadding*(viewPtr: pointer, left, top, right, bottom: float64) {.
  importc: "na_stack_set_padding".}
proc naStackSetAlignment*(viewPtr: pointer, alignment: cint) {.
  importc: "na_stack_set_alignment".}
proc naStackAddArranged*(stackPtr, childPtr: pointer) {.importc: "na_stack_add_arranged".}
proc naStackInsertArranged*(stackPtr, childPtr: pointer, index: cint) {.
  importc: "na_stack_insert_arranged".}
proc naStackRemoveArranged*(stackPtr, childPtr: pointer) {.
  importc: "na_stack_remove_arranged".}
proc naStackArrangedCount*(stackPtr: pointer): cint {.importc: "na_stack_arranged_count".}
proc naStackSetArrangedFill*(viewPtr: pointer, fill: bool) {.importc: "na_stack_set_arranged_fill".}

proc naScrollCreate*(): pointer {.importc: "na_scroll_create".}
proc naScrollFree*(viewPtr: pointer) {.importc: "na_scroll_free".}
proc naScrollSetDocument*(scrollPtr, docPtr: pointer) {.importc: "na_scroll_set_document".}
proc naScrollFitWidth*(scrollPtr: pointer, leftInset, rightInset: float64) {.
  importc: "na_scroll_fit_width".}
proc naScrollSetHasVerticalBar*(scrollPtr: pointer, has: bool) {.
  importc: "na_scroll_set_has_vertical_bar".}
proc naScrollSetHasHorizontalBar*(scrollPtr: pointer, has: bool) {.
  importc: "na_scroll_set_has_horizontal_bar".}
proc naScrollSetBorder*(scrollPtr: pointer, bordered: bool) {.
  importc: "na_scroll_set_border".}
proc naScrollSetBackground*(scrollPtr: pointer, r, g, b, a: uint8) {.
  importc: "na_scroll_set_background".}

# Web views (WKWebView). Event kinds mirror gui/webview.nim:
# 0 started, 1 finished, 2 failed, 3 progress, 4 message, 5 jsResult,
# 6 navRequested, 7 pdfResult, 8 snapshotResult, 9 cookiesResult,
# 10 jsAlert, 11 jsConfirm, 12 jsPrompt, 13 newWindow, 14 fullscreen.
type NaWebViewEventFn* = proc(widgetId: uint32, kind: cint, arg1, arg2: cstring,
                              num: float64, num2: uint64, ctx: pointer) {.cdecl.}

proc naWebviewSetEventCallback*(fn: NaWebViewEventFn, ctx: pointer) {.
  importc: "na_webview_set_event_callback".}
proc naWebviewCreate*(widgetId: uint32, javaScriptEnabled: bool): pointer {.
  importc: "na_webview_create".}
proc naWebviewCreateEx*(widgetId: uint32, javaScriptEnabled: bool,
                        persistent: bool, userAgent: cstring,
                        appName: cstring): pointer {.
  importc: "na_webview_create_ex".}
proc naWebviewFree*(widgetId: uint32, viewPtr: pointer) {.
  importc: "na_webview_free".}
proc naWebviewLoadUrl*(viewPtr: pointer, url: cstring) {.
  importc: "na_webview_load_url".}
proc naWebviewLoadHtml*(viewPtr: pointer, html, baseUrl: cstring) {.
  importc: "na_webview_load_html".}
proc naWebviewReload*(viewPtr: pointer) {.importc: "na_webview_reload".}
proc naWebviewStop*(viewPtr: pointer) {.importc: "na_webview_stop".}
proc naWebviewGoBack*(viewPtr: pointer) {.importc: "na_webview_go_back".}
proc naWebviewGoForward*(viewPtr: pointer) {.importc: "na_webview_go_forward".}
proc naWebviewCanGoBack*(viewPtr: pointer): bool {.
  importc: "na_webview_can_go_back".}
proc naWebviewCanGoForward*(viewPtr: pointer): bool {.
  importc: "na_webview_can_go_forward".}
proc naWebviewGetUrl*(viewPtr: pointer): cstring {.
  importc: "na_webview_get_url".}
proc naWebviewGetTitle*(viewPtr: pointer): cstring {.
  importc: "na_webview_get_title".}
proc naWebviewGetProgress*(viewPtr: pointer): float64 {.
  importc: "na_webview_get_progress".}
proc naWebviewIsLoading*(viewPtr: pointer): bool {.
  importc: "na_webview_is_loading".}
proc naWebviewEvaluateJs*(viewPtr: pointer, script: cstring, requestId: uint64) {.
  importc: "na_webview_evaluate_js".}
proc naWebviewAddMessageHandler*(viewPtr: pointer, name: cstring) {.
  importc: "na_webview_add_message_handler".}
proc naWebviewRemoveMessageHandler*(viewPtr: pointer, name: cstring) {.
  importc: "na_webview_remove_message_handler".}
proc naWebviewRemoveAllMessageHandlers*(viewPtr: pointer) {.
  importc: "na_webview_remove_all_message_handlers".}
proc naWebviewAddUserScript*(viewPtr: pointer, source: cstring, atEnd: bool,
                             mainFrameOnly: bool) {.
  importc: "na_webview_add_user_script".}
proc naWebviewRemoveAllUserScripts*(viewPtr: pointer) {.
  importc: "na_webview_remove_all_user_scripts".}
proc naWebviewAddContentRule*(viewPtr: pointer, json: cstring,
                              identifier: cstring) {.
  importc: "na_webview_add_content_rule".}
proc naWebviewRemoveAllContentRules*(viewPtr: pointer) {.
  importc: "na_webview_remove_all_content_rules".}
proc naWebviewSetUserAgent*(viewPtr: pointer, userAgent: cstring) {.
  importc: "na_webview_set_user_agent".}
proc naWebviewGetUserAgent*(viewPtr: pointer): cstring {.
  importc: "na_webview_get_user_agent".}
proc naWebviewSetBackForwardGestures*(viewPtr: pointer, enabled: bool) {.
  importc: "na_webview_set_backforward_gestures".}
proc naWebviewGetBackForwardGestures*(viewPtr: pointer): bool {.
  importc: "na_webview_get_backforward_gestures".}
proc naWebviewSetMagnification*(viewPtr: pointer, m: float64, cx: float64,
                                cy: float64) {.
  importc: "na_webview_set_magnification".}
proc naWebviewGetMagnification*(viewPtr: pointer): float64 {.
  importc: "na_webview_get_magnification".}
proc naWebviewSetAllowsMagnification*(viewPtr: pointer, allowed: bool) {.
  importc: "na_webview_set_allows_magnification".}
proc naWebviewSetPageZoom*(viewPtr: pointer, zoom: float64) {.
  importc: "na_webview_set_page_zoom".}
proc naWebviewGetPageZoom*(viewPtr: pointer): float64 {.
  importc: "na_webview_get_page_zoom".}
proc naWebviewReloadFromOrigin*(viewPtr: pointer) {.
  importc: "na_webview_reload_from_origin".}
proc naWebviewLoadFileUrl*(viewPtr: pointer, path: cstring,
                           readAccess: cstring) {.
  importc: "na_webview_load_file_url".}
proc naWebviewLoadData*(viewPtr: pointer, data: cstring, mime: cstring,
                        encoding: cstring, baseUrl: cstring) {.
  importc: "na_webview_load_data".}
proc naWebviewBackCount*(viewPtr: pointer): cint {.
  importc: "na_webview_back_count".}
proc naWebviewForwardCount*(viewPtr: pointer): cint {.
  importc: "na_webview_forward_count".}
proc naWebviewHistoryUrl*(viewPtr: pointer, forward: bool,
                          index: cint): cstring {.
  importc: "na_webview_history_url".}
proc naWebviewHistoryTitle*(viewPtr: pointer, forward: bool,
                            index: cint): cstring {.
  importc: "na_webview_history_title".}
proc naWebviewGoToOffset*(viewPtr: pointer, offset: cint): bool {.
  importc: "na_webview_go_to_offset".}
proc naWebviewSetPolicyMode*(viewPtr: pointer, mode: cint) {.
  importc: "na_webview_set_policy_mode".}
proc naWebviewGetPolicyMode*(viewPtr: pointer): cint {.
  importc: "na_webview_get_policy_mode".}
proc naWebviewDecideNavigation*(decisionId: uint64, allow: bool) {.
  importc: "na_webview_decide_navigation".}
proc naWebviewCompleteAlert*(completionId: uint64) {.
  importc: "na_webview_complete_alert".}
proc naWebviewCompleteConfirm*(completionId: uint64, confirmed: bool) {.
  importc: "na_webview_complete_confirm".}
proc naWebviewCompletePrompt*(completionId: uint64, text: cstring,
                              cancelled: bool) {.
  importc: "na_webview_complete_prompt".}
proc naWebviewCreatePdf*(viewPtr: pointer, requestId: uint64) {.
  importc: "na_webview_create_pdf".}
proc naWebviewSnapshot*(viewPtr: pointer, requestId: uint64) {.
  importc: "na_webview_snapshot".}
proc naWebviewGetCookies*(viewPtr: pointer, requestId: uint64) {.
  importc: "na_webview_get_cookies".}
proc naWebviewSetCookie*(viewPtr: pointer, name: cstring, value: cstring,
                         domain: cstring, path: cstring,
                         maxAgeSec: float64) {.
  importc: "na_webview_set_cookie".}
proc naWebviewDeleteCookie*(viewPtr: pointer, name: cstring) {.
  importc: "na_webview_delete_cookie".}
proc naWebviewClearWebsiteData*(viewPtr: pointer, cookies: bool, cache: bool,
                                storage: bool, sinceUnix: float64) {.
  importc: "na_webview_clear_website_data".}
proc naWebviewClearAllWebsiteData*(viewPtr: pointer) {.
  importc: "na_webview_clear_all_website_data".}
proc naWebviewFind*(viewPtr: pointer, text: cstring, backwards: bool,
                    caseSensitive: bool, wraps: bool, requestId: uint64) {.
  importc: "na_webview_find".}
proc naWebviewHideFind*(viewPtr: pointer) {.
  importc: "na_webview_hide_find".}
proc naWebviewPrint*(viewPtr: pointer) {.importc: "na_webview_print".}
proc naWebviewSetContextMenuEnabled*(viewPtr: pointer, enabled: bool) {.
  importc: "na_webview_set_context_menu_enabled".}
proc naWebviewGetContextMenuEnabled*(viewPtr: pointer): bool {.
  importc: "na_webview_get_context_menu_enabled".}
proc naWebviewFire*(widgetId: uint32, kind: cint, arg1, arg2: cstring,
                    num: float64, num2: uint64) {.
  importc: "na_webview_fire".}

type NaHoverEventFn* = proc(widgetId: uint32, ctx: pointer) {.cdecl.}

proc naHoverSetEventCallback*(fn: NaHoverEventFn, ctx: pointer) {.
  importc: "na_hover_set_event_callback".}
proc naHoverViewCreate*(widgetId: uint32): pointer {.importc: "na_hover_view_create".}
proc naHoverViewFree*(widgetId: uint32, viewPtr: pointer) {.importc: "na_hover_view_free".}
proc naHoverViewSetSelected*(viewPtr: pointer, selected: bool) {.
  importc: "na_hover_view_set_selected".}
proc naHoverViewIsSelected*(viewPtr: pointer): bool {.importc: "na_hover_view_is_selected".}
proc naHoverViewFire*(widgetId: uint32) {.importc: "na_hover_view_fire".}

type NaToastDismissFn* = proc(toastId: uint32, ctx: pointer) {.cdecl.}

proc naToastSetDismissCallback*(fn: NaToastDismissFn, ctx: pointer) {.
  importc: "na_toast_set_dismiss_callback".}
proc naToastShow*(title: cstring, message: cstring, durationMs: float64,
                  offsetY: float64, width: float64): uint32 {.importc: "na_toast_show".}
proc naToastClose*(toastId: uint32) {.importc: "na_toast_close".}
proc naToastActiveCount*(): cint {.importc: "na_toast_active_count".}
proc naViewDestroy*(viewPtr: pointer) {.importc: "na_view_destroy".}
proc naViewSetHidden*(viewPtr: pointer, hidden: bool) {.importc: "na_view_set_hidden".}
proc naViewIsHidden*(viewPtr: pointer): bool {.importc: "na_view_is_hidden".}
proc naViewSetTooltip*(viewPtr: pointer, tooltip: cstring) {.importc: "na_view_set_tooltip".}
proc naViewGetTooltip*(viewPtr: pointer): cstring {.importc: "na_view_get_tooltip".}
proc naViewSetTag*(viewPtr: pointer, tag: cint) {.importc: "na_view_set_tag".}
proc naViewGetTag*(viewPtr: pointer): cint {.importc: "na_view_get_tag".}
proc naViewSetFrame*(viewPtr: pointer, x, y, w, h: float64) {.importc: "na_view_set_frame".}
proc naViewSetFrameNoRequest*(viewPtr: pointer, x, y, w, h: float64) {.
  importc: "na_view_set_frame_no_request".}
proc naViewGetFrame*(viewPtr: pointer, outX, outY, outW, outH: ptr float64) {.
  importc: "na_view_get_frame".}
proc naViewAddSubview*(parentPtr, childPtr: pointer) {.importc: "na_view_add_subview".}
proc naViewRemoveFromParent*(viewPtr: pointer) {.importc: "na_view_remove_from_parent".}
proc naViewRemoveAll*(parentPtr: pointer) {.importc: "na_view_remove_all".}
proc naViewSubviewCount*(parentPtr: pointer): cint {.importc: "na_view_subview_count".}
proc naViewLayout*(viewPtr: pointer) {.importc: "na_view_layout".}
proc naViewConstrainFill*(parentPtr, childPtr: pointer, left, top, right, bottom: float64) {.
  importc: "na_view_constrain_fill".}
proc naViewConstrainFillSuperview*(childPtr: pointer, left, top, right, bottom: float64) {.
  importc: "na_view_constrain_fill_superview".}
proc naViewConstrainSize*(viewPtr: pointer, width, height: float64) {.
  importc: "na_view_constrain_size".}
proc naViewSetContentHugging*(viewPtr: pointer, orientation: cint, priority: float64) {.
  importc: "na_view_set_content_hugging".}
proc naViewMeasure*(viewPtr: pointer, maxWidth: float64, maxHeight: float64,
                    outW: ptr float64, outH: ptr float64) {.importc: "na_view_measure".}
proc naViewSetWantsLayer*(viewPtr: pointer, wants: bool) {.importc: "na_view_set_wants_layer".}
proc naViewSetCornerRadius*(viewPtr: pointer, radius: float64) {.
  importc: "na_view_set_corner_radius".}
proc naViewSetBackgroundColor*(viewPtr: pointer, r, g, b, a: uint8) {.
  importc: "na_view_set_background_color".}
proc naViewClearBackgroundColor*(viewPtr: pointer) {.importc: "na_view_clear_background_color".}
proc naViewSetBorder*(viewPtr: pointer, r, g, b, a: uint8, width: float64) {.
  importc: "na_view_set_border".}

type NaThemeChangedFn* = proc(ctx: pointer) {.cdecl.}

proc naThemeSetChangedCallback*(fn: NaThemeChangedFn, ctx: pointer) {.
  importc: "na_theme_set_changed_callback".}
proc naThemeIsDark*(): bool {.importc: "na_theme_is_dark".}

proc naThemeAccentColor*(outR, outG, outB, outA: ptr uint8) {.importc: "na_theme_accent_color".}
proc naThemeLabelColor*(outR, outG, outB, outA: ptr uint8) {.importc: "na_theme_label_color".}
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
proc naThemeSeparatorColor*(outR, outG, outB, outA: ptr uint8) {.importc: "na_theme_separator_color".}
proc naThemeSelectedContentColor*(outR, outG, outB, outA: ptr uint8) {.
  importc: "na_theme_selected_content_color".}
proc naThemeSystemRed*(outR, outG, outB, outA: ptr uint8) {.importc: "na_theme_system_red".}
proc naThemeSystemGreen*(outR, outG, outB, outA: ptr uint8) {.importc: "na_theme_system_green".}
proc naThemeSystemBlue*(outR, outG, outB, outA: ptr uint8) {.importc: "na_theme_system_blue".}
proc naThemeSystemOrange*(outR, outG, outB, outA: ptr uint8) {.importc: "na_theme_system_orange".}
proc naThemeSystemYellow*(outR, outG, outB, outA: ptr uint8) {.importc: "na_theme_system_yellow".}
proc naThemeSystemPurple*(outR, outG, outB, outA: ptr uint8) {.importc: "na_theme_system_purple".}
proc naThemeSystemPink*(outR, outG, outB, outA: ptr uint8) {.importc: "na_theme_system_pink".}
proc naThemeSystemTeal*(outR, outG, outB, outA: ptr uint8) {.importc: "na_theme_system_teal".}
proc naThemeSystemIndigo*(outR, outG, outB, outA: ptr uint8) {.importc: "na_theme_system_indigo".}
proc naThemeSystemMint*(outR, outG, outB, outA: ptr uint8) {.importc: "na_theme_system_mint".}
proc naThemeSystemCyan*(outR, outG, outB, outA: ptr uint8) {.importc: "na_theme_system_cyan".}
proc naThemeSystemBrown*(outR, outG, outB, outA: ptr uint8) {.importc: "na_theme_system_brown".}
proc naThemeSystemGray*(outR, outG, outB, outA: ptr uint8) {.importc: "na_theme_system_gray".}


proc naAppInfoName*(): cstring {.importc: "na_app_info_name".}
proc naAppInfoIdentifier*(): cstring {.importc: "na_app_info_identifier".}
proc naAppInfoVersion*(): cstring {.importc: "na_app_info_version".}
proc naAppInfoBuildNumber*(): cstring {.importc: "na_app_info_build_number".}
proc naDeviceInfoName*(): cstring {.importc: "na_device_info_name".}
proc naDeviceInfoModel*(): cstring {.importc: "na_device_info_model".}
proc naDeviceInfoOsVersion*(): cstring {.importc: "na_device_info_os_version".}

proc naPrefsOpen*(scope: cstring): pointer {.importc: "na_prefs_open".}
proc naPrefsClose*(handle: pointer) {.importc: "na_prefs_close".}
proc naPrefsSet*(handle: pointer, key, value: cstring): bool {.importc: "na_prefs_set".}
proc naPrefsGet*(handle: pointer, key: cstring, outBuf: cstring, outMax: cint): bool {.
  importc: "na_prefs_get".}
proc naPrefsRemove*(handle: pointer, key: cstring): bool {.importc: "na_prefs_remove".}
proc naPrefsClear*(handle: pointer): bool {.importc: "na_prefs_clear".}
proc naPrefsContains*(handle: pointer, key: cstring): bool {.importc: "na_prefs_contains".}
proc naPrefsSize*(handle: pointer): cint {.importc: "na_prefs_size".}
proc naPrefsRefreshKeys*(handle: pointer) {.importc: "na_prefs_refresh_keys".}
proc naPrefsSnapshotCount*(): cint {.importc: "na_prefs_snapshot_count".}
proc naPrefsSnapshotKey*(index: cint, outBuf: cstring, outMax: cint): bool {.
  importc: "na_prefs_snapshot_key".}

proc naUrlOpen*(url: cstring, errOut: cstring, errMax: cint): bool {.importc: "na_url_open".}
proc naAccessibilityEnable*() {.importc: "na_accessibility_enable".}
proc naAccessibilityIsEnabled*(): bool {.importc: "na_accessibility_is_enabled".}
proc naLalDefaultId*(): cstring {.importc: "na_lal_default_id".}
proc naLalDefaultDisplayName*(): cstring {.importc: "na_lal_default_display_name".}
proc naLalDefaultProgramPath*(): cstring {.importc: "na_lal_default_program_path".}
proc naLalIsSupported*(): bool {.importc: "na_lal_is_supported".}
proc naLalEnable*(id: cstring): bool {.importc: "na_lal_enable".}
proc naLalDisable*(id: cstring): bool {.importc: "na_lal_disable".}
proc naLalIsEnabled*(id: cstring): bool {.importc: "na_lal_is_enabled".}

type NaMenuEventFn* = proc(kind: cint, id: uint32, ctx: pointer) {.cdecl.}

proc naMenuCreate*(): uint32 {.importc: "na_menu_create".}
proc naMenuFree*(id: uint32) {.importc: "na_menu_free".}
proc naMenuItemCreate*(label: cstring, itemType: cint): uint32 {.importc: "na_menu_item_create".}
proc naMenuItemFree*(id: uint32) {.importc: "na_menu_item_free".}
proc naMenuAddItem*(menuId, itemId: uint32) {.importc: "na_menu_add_item".}
proc naMenuInsertItem*(menuId, itemId: uint32, index: cint) {.importc: "na_menu_insert_item".}
proc naMenuRemoveItem*(menuId, itemId: uint32): bool {.importc: "na_menu_remove_item".}
proc naMenuClear*(menuId: uint32) {.importc: "na_menu_clear".}
proc naMenuItemSetLabel*(id: uint32, label: cstring) {.importc: "na_menu_item_set_label".}
proc naMenuItemGetTitle*(id: uint32): cstring {.importc: "na_menu_item_get_title".}
proc naMenuItemSetTooltip*(id: uint32, tooltip: cstring) {.importc: "na_menu_item_set_tooltip".}
proc naMenuItemSetEnabled*(id: uint32, enabled: bool) {.importc: "na_menu_item_set_enabled".}
proc naMenuItemIsEnabled*(id: uint32): bool {.importc: "na_menu_item_is_enabled".}
proc naMenuItemSetState*(id: uint32, state: cint) {.importc: "na_menu_item_set_state".}
proc naMenuItemSetRadioGroup*(id: uint32, group: cint) {.importc: "na_menu_item_set_radio_group".}
proc naMenuItemGetRadioGroup*(id: uint32): cint {.importc: "na_menu_item_get_radio_group".}
proc naMenuItemSetAccelerator*(id: uint32, key: cstring, modifiers: cuint) {.
  importc: "na_menu_item_set_accelerator".}
proc naMenuItemSetSubmenu*(itemId, submenuMenuId: uint32) {.
  importc: "na_menu_item_set_submenu".}
proc naMenuPopup*(menuId: uint32, x, y: float64, placement: cint) {.importc: "na_menu_popup".}
proc naMenuCancelTracking*(menuId: uint32) {.importc: "na_menu_cancel_tracking".}
proc naMenuSetEventCallback*(fn: NaMenuEventFn, ctx: pointer) {.
  importc: "na_menu_set_event_callback".}

# Main menu bar (NSApp.mainMenu) + standard responder-chain selectors.
proc naAppSetMainMenu*(menuId: uint32) {.importc: "na_app_set_main_menu".}
proc naAppGetMainMenu*(): uint32 {.importc: "na_app_get_main_menu".}
proc naMenuItemSetSelector*(id: uint32, selectorName: cstring): bool {.
  importc: "na_menu_item_set_selector".}
proc naMenuSetAsServices*(menuId: uint32) {.importc: "na_menu_set_as_services".}
proc naMenuSetAsWindows*(menuId: uint32) {.importc: "na_menu_set_as_windows".}
proc naMenuSetAsHelp*(menuId: uint32) {.importc: "na_menu_set_as_help".}

type NaTrayEventFn* = proc(kind: cint, id: uint32, ctx: pointer) {.cdecl.}

proc naTrayCreate*(): uint32 {.importc: "na_tray_create".}
proc naTrayFree*(id: uint32) {.importc: "na_tray_free".}
proc naTraySetupHandlers*(id: uint32) {.importc: "na_tray_setup_handlers".}
proc naTrayTeardownHandlers*(id: uint32) {.importc: "na_tray_teardown_handlers".}
proc naTrayExists*(id: uint32): bool {.importc: "na_tray_exists".}
proc naTraySetIconPath*(id: uint32, path: cstring) {.importc: "na_tray_set_icon_path".}
proc naTrayClearIcon*(id: uint32) {.importc: "na_tray_clear_icon".}
proc naTraySetTitle*(id: uint32, title: cstring) {.importc: "na_tray_set_title".}
proc naTrayGetTitle*(id: uint32): cstring {.importc: "na_tray_get_title".}
proc naTraySetTooltip*(id: uint32, tooltip: cstring) {.importc: "na_tray_set_tooltip".}
proc naTrayGetTooltip*(id: uint32): cstring {.importc: "na_tray_get_tooltip".}
proc naTraySetContextMenu*(id, menuId: uint32) {.importc: "na_tray_set_context_menu".}
proc naTrayGetContextMenu*(id: uint32): uint32 {.importc: "na_tray_get_context_menu".}
proc naTrayGetBounds*(id: uint32, outX, outY, outW, outH: ptr float64) {.
  importc: "na_tray_get_bounds".}
proc naTraySetVisible*(id: uint32, visible: bool): bool {.importc: "na_tray_set_visible".}
proc naTrayIsVisible*(id: uint32): bool {.importc: "na_tray_is_visible".}
proc naTrayOpenContextMenu*(id: uint32): bool {.importc: "na_tray_open_context_menu".}
proc naTrayCloseContextMenu*(id: uint32): bool {.importc: "na_tray_close_context_menu".}
proc naTraySetEventCallback*(fn: NaTrayEventFn, ctx: pointer) {.
  importc: "na_tray_set_event_callback".}

proc naDialogCreate*(title, message: cstring): int64 {.importc: "na_dialog_create".}
proc naDialogDestroy*(handle: int64) {.importc: "na_dialog_destroy".}
proc naDialogSetTitle*(handle: int64, title: cstring) {.importc: "na_dialog_set_title".}
proc naDialogSetMessage*(handle: int64, message: cstring) {.importc: "na_dialog_set_message".}
proc naDialogIsOpen*(handle: int64): bool {.importc: "na_dialog_is_open".}
proc naDialogRunModal*(handle: int64) {.importc: "na_dialog_run_modal".}
proc naDialogClose*(handle: int64): bool {.importc: "na_dialog_close".}

proc naImageFromFile*(path: cstring): int64 {.importc: "na_image_from_file".}
proc naImageFromBase64*(data: cstring): int64 {.importc: "na_image_from_base64".}
proc naImageDestroy*(handle: int64) {.importc: "na_image_destroy".}
proc naImageExists*(handle: int64): bool {.importc: "na_image_exists".}
proc naImageGetSize*(handle: int64, outW, outH: ptr float64) {.importc: "na_image_get_size".}
proc naImageGetSource*(handle: int64, outBuf: cstring, outMax: cint) {.
  importc: "na_image_get_source".}
proc naImageGetFormat*(handle: int64): cstring {.importc: "na_image_get_format".}
proc naImageToBase64*(handle: int64): cstring {.importc: "na_image_to_base64".}
proc naImageSaveToFile*(handle: int64, path: cstring): bool {.importc: "na_image_save_to_file".}
proc naImageNativePtr*(handle: int64): pointer {.importc: "na_image_native_ptr".}

proc naMenuItemSetIconPtr*(id: uint32, nsImagePtr: pointer) {.
  importc: "na_menu_item_set_icon_ptr".}
proc naTraySetIconPtr*(id: uint32, nsImagePtr: pointer) {.
  importc: "na_tray_set_icon_ptr".}

type NaKeyboardEventFn* = proc(kind: cint, keycode: cint, modifiers: cuint, ctx: pointer) {.cdecl.}

proc naKeyboardStart*(fn: NaKeyboardEventFn, ctx: pointer): bool {.importc: "na_keyboard_start".}
proc naKeyboardStop*() {.importc: "na_keyboard_stop".}
proc naKeyboardIsRunning*(): bool {.importc: "na_keyboard_is_running".}

type NaHotkeyFn* = proc(id: cuint, ctx: pointer) {.cdecl.}

proc naHotkeyRegister*(id: cuint, accelerator: cstring): bool {.importc: "na_hotkey_register".}
proc naHotkeyUnregister*(id: cuint): bool {.importc: "na_hotkey_unregister".}
proc naHotkeySetCallback*(fn: NaHotkeyFn, ctx: pointer) {.importc: "na_hotkey_set_callback".}

# Clipboard (NSPasteboard)
{.compile: "widgets/clipboard.m".}
proc naClipboardSetText*(text: cstring) {.importc: "na_clipboard_set_text".}
proc naClipboardGetText*(): cstring {.importc: "na_clipboard_get_text".}
proc naClipboardClear*() {.importc: "na_clipboard_clear".}
proc naClipboardChangeCount*(): cint {.importc: "na_clipboard_change_count".}
proc naClipboardSetImageHandle*(handle: int64) {.importc: "na_clipboard_set_image_handle".}
proc naClipboardGetImageHandle*(): int64 {.importc: "na_clipboard_get_image_handle".}
proc naClipboardSetFilePaths*(paths: ptr cstring, count: cint) {.importc: "na_clipboard_set_file_paths".}
proc naClipboardGetFilePaths*(outCount: ptr cint): ptr cstring {.importc: "na_clipboard_get_file_paths".}
proc naClipboardFreeString*(text: cstring) {.importc: "na_clipboard_free_string".}
proc naClipboardFreeStringList*(list: ptr cstring, count: cint) {.importc: "na_clipboard_free_string_list".}

# File dialogs (NSOpenPanel / NSSavePanel)
{.compile: "widgets/filedialog.m".}
proc naOpenPanelCreate*(title: cstring): pointer {.importc: "na_open_panel_create".}
proc naOpenPanelSetCanChooseDirectories*(p: pointer, value: bool) {.importc: "na_open_panel_set_can_choose_directories".}
proc naOpenPanelSetAllowsMultiple*(p: pointer, value: bool) {.importc: "na_open_panel_set_allows_multiple".}
proc naOpenPanelSetFilters*(p: pointer, extensions: ptr cstring, count: cint) {.importc: "na_open_panel_set_filters".}
proc naOpenPanelSetInitialDirectory*(p: pointer, path: cstring) {.importc: "na_open_panel_set_initial_directory".}
proc naOpenPanelRunModal*(p: pointer, outPaths: ptr ptr cstring): cint {.importc: "na_open_panel_run_modal".}
proc naSavePanelCreate*(title: cstring, defaultName: cstring): pointer {.importc: "na_save_panel_create".}
proc naSavePanelSetNameField*(p: pointer, name: cstring) {.importc: "na_save_panel_set_name_field".}
proc naSavePanelSetFilters*(p: pointer, extensions: ptr cstring, count: cint) {.importc: "na_save_panel_set_filters".}
proc naSavePanelRunModal*(p: pointer): cstring {.importc: "na_save_panel_run_modal".}

# Mouse event monitors (NSEvent)
{.compile: "widgets/mouse_monitor.m".}
type NaMouseEventFn* = proc(kind: cint, x: cdouble, y: cdouble, clicks: cint, ctx: pointer) {.cdecl.}
proc naMouseStartMonitor*(globalOnlyOwnApp: bool, fn: NaMouseEventFn, ctx: pointer): bool {.importc: "na_mouse_start_monitor".}
proc naMouseStopMonitors*() {.importc: "na_mouse_stop_monitors".}

# Local notifications (UNUserNotificationCenter)
{.passl: "-framework UserNotifications".}
{.compile: "widgets/notifications.m".}
type NaNotifAuthFn* = proc(granted: cint, ctx: pointer) {.cdecl.}
type NaNotifResponseFn* = proc(id: cuint, action: cstring, ctx: pointer) {.cdecl.}
proc naNotificationsSupported*(): bool {.importc: "na_notifications_supported".}
proc naNotificationsAuthStatus*(): cint {.importc: "na_notifications_auth_status".}
proc naNotificationsRequestAuth*(fn: NaNotifAuthFn, ctx: pointer) {.importc: "na_notifications_request_auth".}
proc naNotificationsSetResponseCallback*(fn: NaNotifResponseFn, ctx: pointer) {.importc: "na_notifications_set_response_callback".}
proc naNotificationsShow*(title: cstring, subtitle: cstring, body: cstring, defaultSound: bool): cuint {.importc: "na_notifications_show".}
proc naNotificationsCancel*(id: cuint) {.importc: "na_notifications_cancel".}

# Alerts v2 (NSAlert with buttons + input accessory)
{.compile: "widgets/alert.m".}
proc naAlertCreate*(title: cstring, message: cstring, style: cint): int64 {.importc: "na_alert_create".}
proc naAlertDestroy*(handle: int64) {.importc: "na_alert_destroy".}
type NaAlertClickFn* = proc(handle: int64, widgetId: cuint, ctx: pointer) {.cdecl.}
proc naAlertSetClickCallback*(fn: NaAlertClickFn) {.importc: "na_alert_set_click_callback".}
proc naAlertAddButton*(handle: int64, label: cstring, isDefault: bool, widgetId: cuint) {.importc: "na_alert_add_button".}
proc naAlertButtonCount*(handle: int64): cint {.importc: "na_alert_button_count".}
proc naAlertSetAccessoryView*(handle: int64, viewPtr: pointer) {.importc: "na_alert_set_accessory_view".}
proc naAlertRunModal*(handle: int64): cint {.importc: "na_alert_run_modal".}
proc naAlertStopModal*(handle: int64) {.importc: "na_alert_stop_modal".}

# Popovers (NSPopover)
{.compile: "widgets/popover.m".}
proc naPopoverCreate*(): int64 {.importc: "na_popover_create".}
proc naPopoverDestroy*(handle: int64) {.importc: "na_popover_destroy".}
proc naPopoverContentView*(handle: int64): pointer {.importc: "na_popover_content_view".}
proc naPopoverSetSize*(handle: int64, w: float64, h: float64) {.importc: "na_popover_set_size".}
proc naPopoverShow*(handle: int64, anchorView: pointer, edge: cint) {.importc: "na_popover_show".}
proc naPopoverClose*(handle: int64) {.importc: "na_popover_close".}
proc naPopoverIsShown*(handle: int64): bool {.importc: "na_popover_is_shown".}
type NaPopoverCloseFn* = proc(handle: int64, ctx: pointer) {.cdecl.}
proc naPopoverSetCloseCallback*(fn: NaPopoverCloseFn) {.importc: "na_popover_set_close_callback".}

# Split views (NSSplitView)
{.compile: "widgets/splitview.m".}
proc naSplitViewCreate*(vertical: bool): pointer {.importc: "na_split_view_create".}
proc naSplitViewAddPane*(viewPtr: pointer, child: pointer) {.importc: "na_split_view_add_pane".}
proc naSplitViewSetDividerThickness*(viewPtr: pointer, thickness: float64) {.importc: "na_split_view_set_divider_thickness".}
proc naSplitViewSetPosition*(viewPtr: pointer, index: cint, position: float64): bool {.importc: "na_split_view_set_position".}
proc naSplitViewGetPosition*(viewPtr: pointer, index: cint): float64 {.importc: "na_split_view_get_position".}
proc naSplitViewPaneCount*(viewPtr: pointer): cint {.importc: "na_split_view_pane_count".}
proc naSplitViewSetHoldingPriority*(viewPtr: pointer, index: cint, priority: float64) {.importc: "na_split_view_set_holding_priority".}
proc naSplitViewConstrainPane*(viewPtr: pointer, index: cint,
                               minWidth: float64, maxWidth: float64,
                               minHeight: float64, maxHeight: float64) {.
    importc: "na_split_view_constrain_pane".}

# Window toolbars (NSToolbar)
{.compile: "widgets/toolbar.m".}
proc naWindowNative*(id: uint32): pointer {.importc: "na_window_native".}
proc naToolbarAttach*(windowId: uint32): int64 {.importc: "na_toolbar_attach".}
type NaToolbarClickFn* = proc(widgetId: cuint, ctx: pointer) {.cdecl.}
proc naToolbarSetClickCallback*(fn: NaToolbarClickFn) {.importc: "na_toolbar_set_click_callback".}
proc naToolbarAddItem*(handle: int64, label: cstring, symbolName: cstring, widgetId: cuint): cint {.importc: "na_toolbar_add_item".}
proc naToolbarAddSpace*(handle: int64, flexible: bool, widgetId: cuint): cint {.importc: "na_toolbar_add_space".}
proc naToolbarAddSearch*(handle: int64, placeholder: cstring, widgetId: cuint): cint {.importc: "na_toolbar_add_search".}
proc naToolbarRemoveItem*(handle: int64, widgetId: cuint) {.importc: "na_toolbar_remove_item".}
proc naToolbarItemCount*(handle: int64): cint {.importc: "na_toolbar_item_count".}
proc naToolbarSetItemTooltip*(handle: int64, widgetId: cuint, tooltip: cstring) {.importc: "na_toolbar_set_item_tooltip".}
proc naToolbarSetItemEnabled*(handle: int64, widgetId: cuint, enabled: bool) {.importc: "na_toolbar_set_item_enabled".}
proc naToolbarIsItemEnabled*(handle: int64, widgetId: cuint): bool {.importc: "na_toolbar_is_item_enabled".}
proc naToolbarSetDisplayMode*(handle: int64, mode: cint) {.importc: "na_toolbar_set_display_mode".}
proc naToolbarSetSizeMode*(handle: int64, small: bool) {.importc: "na_toolbar_set_size_mode".}
proc naToolbarSetAllowsCustomization*(handle: int64, allowed: bool) {.importc: "na_toolbar_set_allows_customization".}
proc naToolbarSetShowsBaselineSeparator*(handle: int64, show: bool) {.importc: "na_toolbar_set_shows_baseline_separator".}
proc naToolbarSetSelectedItem*(handle: int64, widgetId: cuint) {.importc: "na_toolbar_set_selected_item".}
proc naToolbarGetSearchText*(handle: int64, widgetId: cuint): cstring {.importc: "na_toolbar_get_search_text".}
type NaToolbarSearchFn* = proc(widgetId: cuint, submitted: bool, text: cstring) {.cdecl.}
proc naToolbarSetSearchCallback*(fn: NaToolbarSearchFn) {.importc: "na_toolbar_set_search_callback".}
proc naToolbarFireSearch*(widgetId: cuint, submitted: bool, text: cstring) {.importc: "na_toolbar_fire_search".}

# View alpha (for animations)
proc naViewSetAlpha*(viewPtr: pointer, alpha: float64) {.importc: "na_view_set_alpha".}
proc naViewGetAlpha*(viewPtr: pointer): float64 {.importc: "na_view_get_alpha".}

type NaFrameChangedFn* = proc(width: cdouble, height: cdouble,
                              ctx: pointer) {.cdecl.}
proc naViewSetFrameCallback*(viewPtr: pointer, fn: NaFrameChangedFn,
                             ctx: pointer) {.importc: "na_view_set_frame_callback".}

# View context menus (right-click via NSView.menu)
proc naViewSetContextMenu*(viewPtr: pointer, menuId: uint32) {.
  importc: "na_view_set_context_menu".}
proc naViewGetContextMenu*(viewPtr: pointer): uint32 {.
  importc: "na_view_get_context_menu".}
proc naViewOpenContextMenu*(viewPtr: pointer): bool {.
  importc: "na_view_open_context_menu".}

# Tables (NSTableView) and outlines (NSOutlineView). Event kinds, table:
# 0 selection, 1 sort(col=a, ascending=b), 2 activate. Outline:
# 0 selection, 1 expand(key), 2 collapse(key), 3 activate.
{.compile: "widgets/tableview.m".}
type NaTableEventFn* = proc(widgetId: uint32, kind: cint, a: int64,
                            b: int64, c: int64, ctx: pointer) {.cdecl.}
type NaOutlineEventFn* = proc(widgetId: uint32, kind: cint, key: uint64,
                               col: int64, ctx: pointer) {.cdecl.}
proc naTableSetEventCallback*(fn: NaTableEventFn, ctx: pointer) {.
  importc: "na_table_set_event_callback".}
proc naOutlineSetEventCallback*(fn: NaOutlineEventFn, ctx: pointer) {.
  importc: "na_outline_set_event_callback".}
proc naTableCreate*(widgetId: uint32, multi: bool): pointer {.
  importc: "na_table_create".}
proc naTableFree*(widgetId: uint32, viewPtr: pointer) {.
  importc: "na_table_free".}
proc naTableAddColumn*(viewPtr: pointer, title: cstring, width: float64,
                       sortable: bool, kind: cint): int64 {.
  importc: "na_table_add_column".}
proc naTableClearColumns*(viewPtr: pointer) {.
  importc: "na_table_clear_columns".}
proc naTableColumnCount*(viewPtr: pointer): int64 {.
  importc: "na_table_column_count".}
proc naTableSetColumnWidth*(viewPtr: pointer, col: int64, width: float64) {.
  importc: "na_table_set_column_width".}
proc naTableSetRows*(viewPtr: pointer, cells: ptr cstring, nrows: int64,
                     ncols: int64) {.importc: "na_table_set_rows".}
proc naTableRowCount*(viewPtr: pointer): int64 {.
  importc: "na_table_row_count".}
proc naTableSetSortIndicator*(viewPtr: pointer, col: int64, ascending: cint) {.
  importc: "na_table_set_sort_indicator".}
proc naTableSortChain*(viewPtr: pointer, cols: ptr int64, ascending: ptr bool,
                       max: cint): cint {.importc: "na_table_sort_chain".}
proc naTableSetSortIndicators*(viewPtr: pointer, cols: ptr int64,
                               ascending: ptr bool, n: cint) {.
  importc: "na_table_set_sort_indicators".}
proc naTableSetRowHeight*(viewPtr: pointer, height: float64) {.
  importc: "na_table_set_row_height".}
proc naTableSelectedRows*(viewPtr: pointer, outRows: ptr int64,
                          max: cint): cint {.
  importc: "na_table_selected_rows".}
proc naTableSelectRows*(viewPtr: pointer, rows: ptr int64, n: cint,
                        extend: bool) {.importc: "na_table_select_rows".}
proc naTableClearSelection*(viewPtr: pointer) {.
  importc: "na_table_clear_selection".}
proc naTableScrollToRow*(viewPtr: pointer, row: int64) {.
  importc: "na_table_scroll_to_row".}
proc naTableSetMulti*(viewPtr: pointer, multi: bool) {.
  importc: "na_table_set_multi".}
proc naTableFireSelect*(widgetId: uint32) {.importc: "na_table_fire_select".}
proc naTableFireSort*(widgetId: uint32, col: int64, ascending: bool) {.
  importc: "na_table_fire_sort".}
proc naTableFireActivate*(widgetId: uint32) {.
  importc: "na_table_fire_activate".}
proc naTableSetCellChecked*(viewPtr: pointer, row: int64, col: int64,
                            checked: bool) {.
  importc: "na_table_set_cell_checked".}
proc naTableIsCellChecked*(viewPtr: pointer, row: int64, col: int64): bool {.
  importc: "na_table_is_cell_checked".}
proc naTableSetCellImage*(viewPtr: pointer, row: int64, col: int64,
                          imageHandle: int64) {.
  importc: "na_table_set_cell_image".}
proc naTableSetRowHeights*(viewPtr: pointer, rows: ptr int64,
                           heights: ptr float64, n: cint) {.
  importc: "na_table_set_row_heights".}
proc naTableClearRowHeights*(viewPtr: pointer) {.
  importc: "na_table_clear_row_heights".}
proc naTableGetCell*(viewPtr: pointer, row: int64, col: int64): cstring {.
  importc: "na_table_get_cell".}
proc naTableSetColEditable*(viewPtr: pointer, col: int64, editable: bool) {.
  importc: "na_table_set_col_editable".}
proc naTableFireCheck*(widgetId: uint32, row: int64, col: int64) {.
  importc: "na_table_fire_check".}
proc naTableFireEdit*(widgetId: uint32, row: int64, col: int64) {.
  importc: "na_table_fire_edit".}
proc naTableSetReorderable*(viewPtr: pointer, reorderable: bool) {.
  importc: "na_table_set_reorderable".}
proc naTableIsReorderable*(viewPtr: pointer): bool {.
  importc: "na_table_is_reorderable".}
proc naTableSetAcceptsFiles*(viewPtr: pointer, accept: bool) {.
  importc: "na_table_set_accepts_files".}
proc naTableAcceptsFiles*(viewPtr: pointer): bool {.
  importc: "na_table_accepts_files".}
proc naTableDropSources*(viewPtr: pointer, outRows: ptr int64,
                         max: cint): cint {.
  importc: "na_table_drop_sources".}
proc naTableDropFiles*(viewPtr: pointer, buf: cstring, maxLen: cint): cint {.
  importc: "na_table_drop_files".}
proc naTableFireReorder*(widgetId: uint32, viewPtr: pointer, target: int64,
                         sources: ptr int64, n: cint) {.
  importc: "na_table_fire_reorder".}
proc naTableFireFileDrop*(widgetId: uint32, viewPtr: pointer, target: int64,
                          paths: ptr cstring, n: cint) {.
  importc: "na_table_fire_filedrop".}
proc naOutlineCreate*(widgetId: uint32, multi: bool): pointer {.
  importc: "na_outline_create".}
proc naOutlineFree*(widgetId: uint32, viewPtr: pointer) {.
  importc: "na_outline_free".}
proc naOutlineAddColumn*(viewPtr: pointer, title: cstring,
                         width: float64, kind: cint): int64 {.
  importc: "na_outline_add_column".}
proc naOutlineClearColumns*(viewPtr: pointer) {.
  importc: "na_outline_clear_columns".}
proc naOutlineColumnCount*(viewPtr: pointer): int64 {.
  importc: "na_outline_column_count".}
proc naOutlineSetColumnWidth*(viewPtr: pointer, col: int64, width: float64) {.
  importc: "na_outline_set_column_width".}
proc naOutlineSetNodes*(viewPtr: pointer, keys: ptr uint64,
                        parents: ptr uint64, expanded: ptr bool,
                        n: cint) {.importc: "na_outline_set_nodes".}
proc naOutlineSetText*(viewPtr: pointer, key: uint64, col: int64,
                       text: cstring) {.importc: "na_outline_set_text".}
proc naOutlineReload*(viewPtr: pointer) {.importc: "na_outline_reload".}
proc naOutlineReloadKey*(viewPtr: pointer, key: uint64,
                         reloadChildren: bool) {.
  importc: "na_outline_reload_key".}
proc naOutlineIsExpanded*(viewPtr: pointer, key: uint64): bool {.
  importc: "na_outline_is_expanded".}
proc naOutlineSetExpanded*(viewPtr: pointer, key: uint64, expanded: bool) {.
  importc: "na_outline_set_expanded".}
proc naOutlineSetIndent*(viewPtr: pointer, points: float64) {.
  importc: "na_outline_set_indent".}
proc naOutlineSelectedKeys*(viewPtr: pointer, outKeys: ptr uint64,
                            max: cint): cint {.
  importc: "na_outline_selected_keys".}
proc naOutlineSelectKeys*(viewPtr: pointer, keys: ptr uint64, n: cint,
                          extend: bool) {.importc: "na_outline_select_keys".}
proc naOutlineClearSelection*(viewPtr: pointer) {.
  importc: "na_outline_clear_selection".}
proc naOutlineScrollToKey*(viewPtr: pointer, key: uint64) {.
  importc: "na_outline_scroll_to_key".}
proc naOutlineSetMulti*(viewPtr: pointer, multi: bool) {.
  importc: "na_outline_set_multi".}
proc naOutlineSetHasMore*(viewPtr: pointer, key: uint64, hasMore: bool) {.
  importc: "na_outline_set_has_more".}
proc naOutlineHasMore*(viewPtr: pointer, key: uint64): bool {.
  importc: "na_outline_has_more".}
proc naOutlineFireSelect*(widgetId: uint32) {.
  importc: "na_outline_fire_select".}
proc naOutlineFireExpand*(widgetId: uint32, key: uint64) {.
  importc: "na_outline_fire_expand".}
proc naOutlineFireCollapse*(widgetId: uint32, key: uint64) {.
  importc: "na_outline_fire_collapse".}
proc naOutlineFireActivate*(widgetId: uint32) {.
  importc: "na_outline_fire_activate".}
proc naOutlineSetCellChecked*(viewPtr: pointer, key: uint64, col: int64,
                              checked: bool) {.
  importc: "na_outline_set_cell_checked".}
proc naOutlineIsCellChecked*(viewPtr: pointer, key: uint64,
                             col: int64): bool {.
  importc: "na_outline_is_cell_checked".}
proc naOutlineSetCellImage*(viewPtr: pointer, key: uint64, col: int64,
                            imageHandle: int64) {.
  importc: "na_outline_set_cell_image".}
proc naOutlineSetRowHeights*(viewPtr: pointer, keys: ptr uint64,
                             heights: ptr float64, n: cint) {.
  importc: "na_outline_set_row_heights".}
proc naOutlineClearRowHeights*(viewPtr: pointer) {.
  importc: "na_outline_clear_row_heights".}
proc naOutlineSetRowHeight*(viewPtr: pointer, height: float64) {.
  importc: "na_outline_set_row_height".}
proc naOutlineGetText*(viewPtr: pointer, key: uint64, col: int64): cstring {.
  importc: "na_outline_get_text".}
proc naOutlineSetColEditable*(viewPtr: pointer, col: int64, editable: bool) {.
  importc: "na_outline_set_col_editable".}
proc naOutlineFireCheck*(widgetId: uint32, key: uint64, col: int64) {.
  importc: "na_outline_fire_check".}
proc naOutlineFireEdit*(widgetId: uint32, key: uint64, col: int64) {.
  importc: "na_outline_fire_edit".}
proc naOutlineSetAcceptsMoves*(viewPtr: pointer, accept: bool) {.
  importc: "na_outline_set_accepts_moves".}
proc naOutlineAcceptsMoves*(viewPtr: pointer): bool {.
  importc: "na_outline_accepts_moves".}
proc naOutlineSetAcceptsFiles*(viewPtr: pointer, accept: bool) {.
  importc: "na_outline_set_accepts_files".}
proc naOutlineAcceptsFiles*(viewPtr: pointer): bool {.
  importc: "na_outline_accepts_files".}
proc naOutlineDropKeys*(viewPtr: pointer, outKeys: ptr uint64,
                        max: cint): cint {.
  importc: "na_outline_drop_keys".}
proc naOutlineDropFiles*(viewPtr: pointer, buf: cstring, maxLen: cint): cint {.
  importc: "na_outline_drop_files".}
proc naOutlineFireMove*(widgetId: uint32, viewPtr: pointer, parent: uint64,
                        index: int64, keys: ptr uint64, n: cint) {.
  importc: "na_outline_fire_move".}
proc naOutlineFireFileDrop*(widgetId: uint32, viewPtr: pointer, parent: uint64,
                            index: int64, paths: ptr cstring, n: cint) {.
  importc: "na_outline_fire_filedrop".}
