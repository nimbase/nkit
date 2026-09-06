## Linux backend contract for nkit.
##
## Proc names/signatures mirror nkit/platform/macos/nsfunctions.nim so service
## modules stay platform-blind beyond the conditional import. Implemented in C
## against GTK (4 preferred, 3 fallback) plus D-Bus for notifications/tray.
{.compile: "widgets/app.c".}
{.compile: "widgets/window.c".}
{.compile: "widgets/view.c".}
{.compile: "widgets/screen.c".}
{.compile: "widgets/controls.c".}
{.compile: "widgets/services.c".}
{.compile: "widgets/theme_info.c".}
{.passc: staticExec("pkg-config --cflags gtk4 2>/dev/null || pkg-config --cflags gtk+-3.0 2>/dev/null").}
{.passl: staticExec("pkg-config --libs gtk4 2>/dev/null || pkg-config --libs gtk+-3.0 2>/dev/null").}

when defined(webkit):
  {.compile: "widgets/webview.c".}
  {.passc: staticExec("pkg-config --cflags webkitgtk-6.0 2>/dev/null || pkg-config --cflags webkit2gtk-4.1 2>/dev/null || pkg-config --cflags webkit2gtk-4.0 2>/dev/null").}
  {.passl: staticExec("pkg-config --libs webkitgtk-6.0 2>/dev/null || pkg-config --libs webkit2gtk-4.1 2>/dev/null || pkg-config --libs webkit2gtk-4.0 2>/dev/null").}
else:
  {.compile: "widgets/webview_stubs.c".}

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

type NaTextAreaEventFn* = proc(widgetId: uint32, ctx: pointer) {.cdecl.}

proc naTextAreaSetEventCallback*(fn: NaTextAreaEventFn, ctx: pointer) {.
  importc: "na_textarea_set_event_callback".}
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
proc naTextAreaFireChange*(widgetId: uint32) {.importc: "na_textarea_fire_change".}

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

# Clipboard (GtkClipboard / GdkClipboard) - implemented in widgets/services.c
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

# File dialogs (GtkFileChooserNative) - implemented in widgets/services.c
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

# Mouse event monitors - implemented in widgets/services.c
type NaMouseEventFn* = proc(kind: cint, x: cdouble, y: cdouble, clicks: cint, ctx: pointer) {.cdecl.}
proc naMouseStartMonitor*(globalOnlyOwnApp: bool, fn: NaMouseEventFn, ctx: pointer): bool {.importc: "na_mouse_start_monitor".}
proc naMouseStopMonitors*() {.importc: "na_mouse_stop_monitors".}

# Local notifications (org.freedesktop.Notifications via D-Bus) - in services.c
type NaNotifAuthFn* = proc(granted: cint, ctx: pointer) {.cdecl.}
type NaNotifResponseFn* = proc(id: cuint, action: cstring, ctx: pointer) {.cdecl.}
proc naNotificationsSupported*(): bool {.importc: "na_notifications_supported".}
proc naNotificationsAuthStatus*(): cint {.importc: "na_notifications_auth_status".}
proc naNotificationsRequestAuth*(fn: NaNotifAuthFn, ctx: pointer) {.importc: "na_notifications_request_auth".}
proc naNotificationsSetResponseCallback*(fn: NaNotifResponseFn, ctx: pointer) {.importc: "na_notifications_set_response_callback".}
proc naNotificationsShow*(title: cstring, subtitle: cstring, body: cstring, defaultSound: bool): cuint {.importc: "na_notifications_show".}
proc naNotificationsCancel*(id: cuint) {.importc: "na_notifications_cancel".}

# Alerts v2 (GtkMessageDialog / GtkAlertDialog) - in services.c
proc naAlertCreate*(title: cstring, message: cstring, style: cint): int64 {.importc: "na_alert_create".}
proc naAlertDestroy*(handle: int64) {.importc: "na_alert_destroy".}
type NaAlertClickFn* = proc(handle: int64, widgetId: cuint, ctx: pointer) {.cdecl.}
proc naAlertSetClickCallback*(fn: NaAlertClickFn) {.importc: "na_alert_set_click_callback".}
proc naAlertAddButton*(handle: int64, label: cstring, isDefault: bool, widgetId: cuint) {.importc: "na_alert_add_button".}
proc naAlertButtonCount*(handle: int64): cint {.importc: "na_alert_button_count".}
proc naAlertSetAccessoryView*(handle: int64, viewPtr: pointer) {.importc: "na_alert_set_accessory_view".}
proc naAlertRunModal*(handle: int64): cint {.importc: "na_alert_run_modal".}
proc naAlertStopModal*(handle: int64) {.importc: "na_alert_stop_modal".}

# Popovers (GtkPopover) - in controls.c
proc naPopoverCreate*(): int64 {.importc: "na_popover_create".}
proc naPopoverDestroy*(handle: int64) {.importc: "na_popover_destroy".}
proc naPopoverContentView*(handle: int64): pointer {.importc: "na_popover_content_view".}
proc naPopoverSetSize*(handle: int64, w: float64, h: float64) {.importc: "na_popover_set_size".}
proc naPopoverShow*(handle: int64, anchorView: pointer, edge: cint) {.importc: "na_popover_show".}
proc naPopoverClose*(handle: int64) {.importc: "na_popover_close".}
proc naPopoverIsShown*(handle: int64): bool {.importc: "na_popover_is_shown".}
type NaPopoverCloseFn* = proc(handle: int64, ctx: pointer) {.cdecl.}
proc naPopoverSetCloseCallback*(fn: NaPopoverCloseFn) {.importc: "na_popover_set_close_callback".}

# Split views (GtkPaned) - in controls.c
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

# Window toolbars (GtkHeaderBar) - in controls.c
proc naWindowNative*(id: uint32): pointer {.importc: "na_window_native".}
proc naToolbarAttach*(windowId: uint32): int64 {.importc: "na_toolbar_attach".}
type NaToolbarClickFn* = proc(widgetId: cuint, ctx: pointer) {.cdecl.}
proc naToolbarSetClickCallback*(fn: NaToolbarClickFn) {.importc: "na_toolbar_set_click_callback".}
proc naToolbarAddItem*(handle: int64, label: cstring, symbolName: cstring, widgetId: cuint): cint {.importc: "na_toolbar_add_item".}
proc naToolbarRemoveItem*(handle: int64, widgetId: cuint) {.importc: "na_toolbar_remove_item".}
proc naToolbarItemCount*(handle: int64): cint {.importc: "na_toolbar_item_count".}

# View alpha (for animations)
proc naViewSetAlpha*(viewPtr: pointer, alpha: float64) {.importc: "na_view_set_alpha".}
proc naViewGetAlpha*(viewPtr: pointer): float64 {.importc: "na_view_get_alpha".}

type NaFrameChangedFn* = proc(width: cdouble, height: cdouble,
                              ctx: pointer) {.cdecl.}
proc naViewSetFrameCallback*(viewPtr: pointer, fn: NaFrameChangedFn,
                             ctx: pointer) {.importc: "na_view_set_frame_callback".}

# ── WKWebView / WebKitGTK ─────────────────────────────────────────────
# Isolated by default: each webview owns its WebKitWebContext + UCM +
# WebKitWebsiteDataManager. Shared is opt-in via naWebContext* at the
# high-level gui/webview layer.

# WebContext (WKProcessPool + WKWebsiteDataStore) — isolated or shared
proc naWebContextCreate*(): pointer {.importc: "na_web_context_create".}
proc naWebContextCreateEphemeral*(): pointer {.importc: "na_web_context_create_ephemeral".}
proc naWebContextFree*(ctx: pointer) {.importc: "na_web_context_free".}
proc naWebContextSetCacheEnabled*(ctx: pointer, enabled: bool) {.importc: "na_web_context_set_cache_enabled".}
proc naWebContextSetDiskCacheEnabled*(ctx: pointer, enabled: bool) {.importc: "na_web_context_set_disk_cache_enabled".}
proc naWebContextClearWebsiteData*(ctx: pointer, typesMask: cint) {.importc: "na_web_context_clear_website_data".}
proc naWebContextFetchDataRecords*(ctx: pointer, typesMask: cint, requestId: uint32) {.importc: "na_web_context_fetch_data_records".}
proc naWebContextSetItpEnabled*(ctx: pointer, enabled: bool) {.importc: "na_web_context_set_itp_enabled".}
proc naWebContextSetTlsErrorsPolicy*(ctx: pointer, policy: cint) {.importc: "na_web_context_set_tls_errors_policy".}

# WKWebsiteDataStore / WKHTTPCookieStore per-context
type NaWebDataRecordsFn* = proc(requestId: uint32, json: cstring, ctx: pointer) {.cdecl.}
proc naWebContextSetDataRecordsCallback*(fn: NaWebDataRecordsFn, ctx: pointer) {.importc: "na_web_context_set_data_records_callback".}
proc naWebContextCookieSet*(ctx: pointer, url: cstring, cookie: cstring) {.importc: "na_web_context_cookie_set".}
proc naWebContextCookieGet*(ctx: pointer, url: cstring): cstring {.importc: "na_web_context_cookie_get".}
proc naWebContextCookieDelete*(ctx: pointer, url: cstring, cookieName: cstring) {.importc: "na_web_context_cookie_delete".}
proc naWebContextCookieGetAll*(ctx: pointer, requestId: uint32) {.importc: "na_web_context_cookie_get_all".}
type NaWebCookieFn* = proc(requestId: uint32, json: cstring, ctx: pointer) {.cdecl.}
proc naWebContextSetCookieCallback*(fn: NaWebCookieFn, ctx: pointer) {.importc: "na_web_context_set_cookie_callback".}
proc naWebContextSetCookieAcceptPolicy*(ctx: pointer, policy: cint) {.importc: "na_web_context_set_cookie_accept_policy".}
proc naWebContextGetCookieAcceptPolicy*(ctx: pointer): cint {.importc: "na_web_context_get_cookie_accept_policy".}
proc naWebContextSetPersistentStoragePath*(ctx: pointer, path: cstring) {.importc: "na_web_context_set_persistent_storage_path".}

# Lifecycle — isolated (new context) or shared (explicit ctx)
proc naWebViewCreate*(widgetId: uint32): pointer {.importc: "na_webview_create".}
proc naWebViewCreateWithContext*(widgetId: uint32, ctx: pointer): pointer {.importc: "na_webview_create_with_context".}
proc naWebViewFree*(widgetId: uint32, viewPtr: pointer) {.importc: "na_webview_free".}
proc naWebViewGetContext*(viewPtr: pointer): pointer {.importc: "na_webview_get_context".}

# Loading (WKWebView load* + reload)
proc naWebViewLoadUrl*(viewPtr: pointer, url: cstring) {.importc: "na_webview_load_url".}
proc naWebViewLoadHtml*(viewPtr: pointer, html: cstring, baseUri: cstring) {.importc: "na_webview_load_html".}
proc naWebViewLoadData*(viewPtr: pointer, data: cstring, dataLen: cint, mimeType: cstring, encoding: cstring, baseUri: cstring) {.importc: "na_webview_load_data".}
proc naWebViewLoadFileUrl*(viewPtr: pointer, fileUrl: cstring, readAccessUrl: cstring) {.importc: "na_webview_load_file_url".}
proc naWebViewReload*(viewPtr: pointer) {.importc: "na_webview_reload".}
proc naWebViewReloadFromOrigin*(viewPtr: pointer) {.importc: "na_webview_reload_from_origin".}
proc naWebViewStopLoading*(viewPtr: pointer) {.importc: "na_webview_stop_loading".}

# Navigation stack (WKBackForwardList)
proc naWebViewGoBack*(viewPtr: pointer): bool {.importc: "na_webview_go_back".}
proc naWebViewGoForward*(viewPtr: pointer): bool {.importc: "na_webview_go_forward".}
proc naWebViewCanGoBack*(viewPtr: pointer): bool {.importc: "na_webview_can_go_back".}
proc naWebViewCanGoForward*(viewPtr: pointer): bool {.importc: "na_webview_can_go_forward".}
proc naWebViewGoToBackForwardIndex*(viewPtr: pointer, index: cint): bool {.importc: "na_webview_go_to_back_forward_index".}
proc naWebViewBackForwardCount*(viewPtr: pointer): cint {.importc: "na_webview_back_forward_count".}
proc naWebViewBackForwardItemAt*(viewPtr: pointer, index: cint, outUrl: cstring, outTitle: cstring, maxLen: cint): bool {.importc: "na_webview_back_forward_item_at".}
proc naWebViewBackForwardCurrentIndex*(viewPtr: pointer): cint {.importc: "na_webview_back_forward_current_index".}

# State (WKWebView url/title/progress/loading/secure)
proc naWebViewGetUrl*(viewPtr: pointer): cstring {.importc: "na_webview_get_url".}
proc naWebViewGetTitle*(viewPtr: pointer): cstring {.importc: "na_webview_get_title".}
proc naWebViewGetProgress*(viewPtr: pointer): float64 {.importc: "na_webview_get_progress".}
proc naWebViewIsLoading*(viewPtr: pointer): bool {.importc: "na_webview_is_loading".}
proc naWebViewHasOnlySecureContent*(viewPtr: pointer): bool {.importc: "na_webview_has_only_secure_content".}
proc naWebViewGetEstimatedProgress*(viewPtr: pointer): float64 {.importc: "na_webview_get_estimated_progress".}

# WKWebViewConfiguration / WKPreferences / WKWebpagePreferences — all customisation
proc naWebViewSetCustomUserAgent*(viewPtr: pointer, ua: cstring) {.importc: "na_webview_set_custom_user_agent".}
proc naWebViewGetCustomUserAgent*(viewPtr: pointer): cstring {.importc: "na_webview_get_custom_user_agent".}
proc naWebViewSetApplicationNameForUserAgent*(viewPtr: pointer, appName: cstring) {.importc: "na_webview_set_application_name_for_user_agent".}
proc naWebViewSetAllowsBackForwardGestures*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_allows_back_forward_gestures".}
proc naWebViewGetAllowsBackForwardGestures*(viewPtr: pointer): bool {.importc: "na_webview_get_allows_back_forward_gestures".}
proc naWebViewSetAllowsLinkPreview*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_allows_link_preview".}
proc naWebViewGetAllowsLinkPreview*(viewPtr: pointer): bool {.importc: "na_webview_get_allows_link_preview".}
proc naWebViewSetAllowsMagnification*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_allows_magnification".}
proc naWebViewSetMagnification*(viewPtr: pointer, mag: float64) {.importc: "na_webview_set_magnification".}
proc naWebViewGetMagnification*(viewPtr: pointer): float64 {.importc: "na_webview_get_magnification".}
proc naWebViewSetInspectable*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_inspectable".}
proc naWebViewIsInspectable*(viewPtr: pointer): bool {.importc: "na_webview_is_inspectable".}
proc naWebViewSetJavaScriptEnabled*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_javascript_enabled".}
proc naWebViewIsJavaScriptEnabled*(viewPtr: pointer): bool {.importc: "na_webview_is_javascript_enabled".}
proc naWebViewSetJavaScriptCanOpenWindows*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_javascript_can_open_windows".}
proc naWebViewIsJavaScriptCanOpenWindows*(viewPtr: pointer): bool {.importc: "na_webview_is_javascript_can_open_windows".}
proc naWebViewSetAllowsInlineMediaPlayback*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_allows_inline_media_playback".}
proc naWebViewGetAllowsInlineMediaPlayback*(viewPtr: pointer): bool {.importc: "na_webview_get_allows_inline_media_playback".}
proc naWebViewSetAllowsAirPlay*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_allows_air_play".}
proc naWebViewSetAllowsPictureInPicture*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_allows_picture_in_picture".}
proc naWebViewSetMediaTypesRequiringUserAction*(viewPtr: pointer, mask: cint) {.importc: "na_webview_set_media_types_requiring_user_action".}
proc naWebViewGetMediaTypesRequiringUserAction*(viewPtr: pointer): cint {.importc: "na_webview_get_media_types_requiring_user_action".}
proc naWebViewSetMinimumFontSize*(viewPtr: pointer, sz: cint) {.importc: "na_webview_set_minimum_font_size".}
proc naWebViewGetMinimumFontSize*(viewPtr: pointer): cint {.importc: "na_webview_get_minimum_font_size".}
proc naWebViewSetDefaultFontSize*(viewPtr: pointer, sz: cint) {.importc: "na_webview_set_default_font_size".}
proc naWebViewSetSerifFontFamily*(viewPtr: pointer, family: cstring) {.importc: "na_webview_set_serif_font_family".}
proc naWebViewSetSansSerifFontFamily*(viewPtr: pointer, family: cstring) {.importc: "na_webview_set_sans_serif_font_family".}
proc naWebViewSetMonospaceFontFamily*(viewPtr: pointer, family: cstring) {.importc: "na_webview_set_monospace_font_family".}
proc naWebViewSetDefaultCharset*(viewPtr: pointer, charset: cstring) {.importc: "na_webview_set_default_charset".}
proc naWebViewSetAutoLoadImages*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_auto_load_images".}
proc naWebViewGetAutoLoadImages*(viewPtr: pointer): bool {.importc: "na_webview_get_auto_load_images".}
proc naWebViewSetSuppressesIncrementalRendering*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_suppresses_incremental_rendering".}
proc naWebViewSetTabFocusesLinks*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_tab_focuses_links".}
proc naWebViewSetAllowsContentJavaScript*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_allows_content_javascript".}
proc naWebViewGetAllowsContentJavaScript*(viewPtr: pointer): bool {.importc: "na_webview_get_allows_content_javascript".}
proc naWebViewSetPreferredContentMode*(viewPtr: pointer, mode: cint) {.importc: "na_webview_set_preferred_content_mode".}
proc naWebViewGetPreferredContentMode*(viewPtr: pointer): cint {.importc: "na_webview_get_preferred_content_mode".}
proc naWebViewSetUpgradeKnownHostsToHttps*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_upgrade_known_hosts_to_https".}
proc naWebViewSetLimitsNavigationsToAppBoundDomains*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_limits_navigations_to_app_bound_domains".}
proc naWebViewSetIgnoresViewportScaleLimits*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_ignores_viewport_scale_limits".}
proc naWebViewSetDataDetectorTypes*(viewPtr: pointer, mask: cint) {.importc: "na_webview_set_data_detector_types".}
proc naWebViewGetDataDetectorTypes*(viewPtr: pointer): cint {.importc: "na_webview_get_data_detector_types".}
proc naWebViewSetZoomLevel*(viewPtr: pointer, lvl: float64) {.importc: "na_webview_set_zoom_level".}
proc naWebViewGetZoomLevel*(viewPtr: pointer): float64 {.importc: "na_webview_get_zoom_level".}
proc naWebViewSetBackgroundColor*(viewPtr: pointer, r,g,b,a: uint8) {.importc: "na_webview_set_background_color".}
proc naWebViewSetTransparentBackground*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_transparent_background".}
proc naWebViewSetEnableWriteConsoleMessagesToStdout*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_enable_write_console_messages_to_stdout".}
proc naWebViewSetEnableDeveloperExtras*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_enable_developer_extras".}
proc naWebViewSetEnableCaretBrowsing*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_enable_caret_browsing".}
proc naWebViewSetEnableSmoothScrolling*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_enable_smooth_scrolling".}
proc naWebViewSetEnableSpatialNavigation*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_enable_spatial_navigation".}
proc naWebViewSetEnableMediaStream*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_enable_media_stream".}
proc naWebViewSetEnableMediasource*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_enable_mediasource".}
proc naWebViewSetEnableWebaudio*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_enable_webaudio".}
proc naWebViewSetEnableWebrtc*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_enable_webrtc".}
proc naWebViewSetEnableEncryptedMedia*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_enable_encrypted_media".}
proc naWebViewSetEnableSiteSpecificQuirks*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_enable_site_specific_quirks".}
proc naWebViewSetEnableBackForwardNavGestures*(viewPtr: pointer, v: bool) {.importc: "na_webview_set_enable_back_forward_nav_gestures".}

# WKUserContentController — scripts + message handlers + style sheets
proc naWebViewAddUserScript*(viewPtr: pointer, source: cstring, injectionTime: cint, forMainFrameOnly: bool): uint32 {.importc: "na_webview_add_user_script".}
proc naWebViewAddUserScriptWithWorld*(viewPtr: pointer, source: cstring, injectionTime: cint, forMainFrameOnly: bool, contentWorld: cstring): uint32 {.importc: "na_webview_add_user_script_with_world".}
proc naWebViewRemoveUserScript*(viewPtr: pointer, scriptId: uint32) {.importc: "na_webview_remove_user_script".}
proc naWebViewRemoveAllUserScripts*(viewPtr: pointer) {.importc: "na_webview_remove_all_user_scripts".}
proc naWebViewAddUserStyleSheet*(viewPtr: pointer, source: cstring, forMainFrameOnly: bool): uint32 {.importc: "na_webview_add_user_style_sheet".}
proc naWebViewRemoveUserStyleSheet*(viewPtr: pointer, sheetId: uint32) {.importc: "na_webview_remove_user_style_sheet".}
proc naWebViewRemoveAllUserStyleSheets*(viewPtr: pointer) {.importc: "na_webview_remove_all_user_style_sheets".}
proc naWebViewAddScriptMessageHandler*(viewPtr: pointer, name: cstring) {.importc: "na_webview_add_script_message_handler".}
proc naWebViewAddScriptMessageHandlerWithReply*(viewPtr: pointer, name: cstring) {.importc: "na_webview_add_script_message_handler_with_reply".}
proc naWebViewRemoveScriptMessageHandler*(viewPtr: pointer, name: cstring) {.importc: "na_webview_remove_script_message_handler".}
proc naWebViewRemoveAllScriptMessageHandlers*(viewPtr: pointer) {.importc: "na_webview_remove_all_script_message_handlers".}

# JavaScript bridge (WKWebView evaluateJavaScript / callAsyncJavaScript)
type NaWebViewScriptResultFn* = proc(widgetId: uint32, requestId: uint32, resultJson: cstring, isError: bool, ctx: pointer) {.cdecl.}
proc naWebViewEvaluateJavaScript*(viewPtr: pointer, script: cstring, requestId: uint32) {.importc: "na_webview_evaluate_javascript".}
proc naWebViewEvaluateJavaScriptWithWorld*(viewPtr: pointer, script: cstring, contentWorld: cstring, requestId: uint32) {.importc: "na_webview_evaluate_javascript_with_world".}
proc naWebViewCallAsyncJavaScript*(viewPtr: pointer, script: cstring, argsJson: cstring, contentWorld: cstring, requestId: uint32) {.importc: "na_webview_call_async_javascript".}
proc naWebViewSetScriptResultCallback*(fn: NaWebViewScriptResultFn, ctx: pointer) {.importc: "na_webview_set_script_result_callback".}

# WKNavigationDelegate + WKUIDelegate callbacks
type NaWebViewNavigationFn* = proc(widgetId: uint32, kind: cint, url: cstring, ctx: pointer) {.cdecl.}
type NaWebViewProgressFn*   = proc(widgetId: uint32, progress: float64, ctx: pointer) {.cdecl.}
type NaWebViewMessageFn*    = proc(widgetId: uint32, handler: cstring, body: cstring, ctx: pointer) {.cdecl.}
type NaWebViewDialogFn*     = proc(widgetId: uint32, kind: cint, message: cstring, defaultText: cstring, ctx: pointer): cstring {.cdecl.}
type NaWebViewPermissionFn* = proc(widgetId: uint32, origin: cstring, permission: cint, ctx: pointer): bool {.cdecl.}
type NaWebViewTerminateFn*  = proc(widgetId: uint32, ctx: pointer) {.cdecl.}
proc naWebViewSetNavigationCallback*(fn: NaWebViewNavigationFn, ctx: pointer) {.importc: "na_webview_set_navigation_callback".}
proc naWebViewSetProgressCallback*(fn: NaWebViewProgressFn, ctx: pointer) {.importc: "na_webview_set_progress_callback".}
proc naWebViewSetMessageCallback*(fn: NaWebViewMessageFn, ctx: pointer) {.importc: "na_webview_set_message_callback".}
proc naWebViewSetDialogCallback*(fn: NaWebViewDialogFn, ctx: pointer) {.importc: "na_webview_set_dialog_callback".}
proc naWebViewSetPermissionCallback*(fn: NaWebViewPermissionFn, ctx: pointer) {.importc: "na_webview_set_permission_callback".}
proc naWebViewSetTerminateCallback*(fn: NaWebViewTerminateFn, ctx: pointer) {.importc: "na_webview_set_terminate_callback".}
proc naWebViewSetDecidePolicyCallback*(fn: NaWebViewNavigationFn, ctx: pointer) {.importc: "na_webview_set_decide_policy_callback".}
proc naWebViewDecidePolicy*(viewPtr: pointer, decisionId: uint32, allow: bool) {.importc: "na_webview_decide_policy".}
proc naWebViewReplyScriptMessage*(viewPtr: pointer, handler: cstring, replyJson: cstring) {.importc: "na_webview_reply_script_message".}

# Custom schemes (WKURLSchemeHandler)
type NaWebViewSchemeFn* = proc(widgetId: uint32, scheme: cstring, url: cstring, requestId: uint32, ctx: pointer) {.cdecl.}
proc naWebViewRegisterUriScheme*(viewPtr: pointer, scheme: cstring) {.importc: "na_webview_register_uri_scheme".}
proc naWebViewUnregisterUriScheme*(viewPtr: pointer, scheme: cstring) {.importc: "na_webview_unregister_uri_scheme".}
proc naWebViewSetSchemeCallback*(fn: NaWebViewSchemeFn, ctx: pointer) {.importc: "na_webview_set_scheme_callback".}
proc naWebViewSchemeFinish*(requestId: uint32, mimeType: cstring, data: cstring, dataLen: cint) {.importc: "na_webview_scheme_finish".}
proc naWebViewSchemeFinishWithHeaders*(requestId: uint32, mimeType: cstring, data: cstring, dataLen: cint, headersJson: cstring, statusCode: cint) {.importc: "na_webview_scheme_finish_with_headers".}
proc naWebViewSchemeError*(requestId: uint32, errorMsg: cstring) {.importc: "na_webview_scheme_error".}
proc naWebViewSchemeRedirect*(requestId: uint32, url: cstring) {.importc: "na_webview_scheme_redirect".}

# Find / print / snapshot / download (WKFindConfiguration, WKSnapshotConfiguration, WKDownload)
proc naWebViewFindText*(viewPtr: pointer, text: cstring, caseSensitive: bool, backwards: bool, wrap: bool): bool {.importc: "na_webview_find_text".}
proc naWebViewFindNext*(viewPtr: pointer, forward: bool): bool {.importc: "na_webview_find_next".}
proc naWebViewHideFindHighlight*(viewPtr: pointer) {.importc: "na_webview_hide_find_highlight".}
proc naWebViewPrint*(viewPtr: pointer) {.importc: "na_webview_print".}
proc naWebViewPrintToPdf*(viewPtr: pointer, path: cstring, requestId: uint32) {.importc: "na_webview_print_to_pdf".}
type NaWebViewPdfFn* = proc(widgetId: uint32, requestId: uint32, success: bool, ctx: pointer) {.cdecl.}
proc naWebViewSetPdfCallback*(fn: NaWebViewPdfFn, ctx: pointer) {.importc: "na_webview_set_pdf_callback".}
proc naWebViewSnapshot*(viewPtr: pointer, requestId: uint32) {.importc: "na_webview_snapshot".}
proc naWebViewSnapshotRect*(viewPtr: pointer, x,y,w,h: float64, requestId: uint32) {.importc: "na_webview_snapshot_rect".}
type NaWebViewSnapshotFn* = proc(widgetId: uint32, requestId: uint32, imageHandle: int64, ctx: pointer) {.cdecl.}
proc naWebViewSetSnapshotCallback*(fn: NaWebViewSnapshotFn, ctx: pointer) {.importc: "na_webview_set_snapshot_callback".}
proc naWebViewCloseAllMediaPresentations*(viewPtr: pointer) {.importc: "na_webview_close_all_media_presentations".}
proc naWebViewSetMuted*(viewPtr: pointer, muted: bool) {.importc: "na_webview_set_muted".}
proc naWebViewIsMuted*(viewPtr: pointer): bool {.importc: "na_webview_is_muted".}
