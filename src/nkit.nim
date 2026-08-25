# A unified access to native system APIs across multiple
# platforms for Nim language.
# 
# This is an adaptation of the libnativeapi, written by LiJianying
# https://github.com/libnativeapi/nativeapi
#
# (c) 2025 George Lemon, LiJianying | MIT License
#          https://github.com/nimbase/nativeapi 

when isMainModule:
  import pkg/kapsis
  import nkit/cli

  initKapsis do:
    commands:
      -- "Development"
      run ?string(pkg):
        ## Build 
      -- "Bundle & Setup"
      bundle ?string(pkg):
        ## Bundle an NimKit project
else:
  import nkit/foundation/geometry
  import nkit/foundation/color
  import nkit/foundation/keyboard
  import nkit/foundation/event
  import nkit/foundation/dispatcher
  import nkit/foundation/id_allocator
  import nkit/foundation/object_registry
  import nkit/foundation/event_emitter
  import nkit/placement
  import nkit/positioning_strategy
  import nkit/application
  import nkit/window
  import nkit/window_registry
  import nkit/window_manager
  import nkit/display
  import nkit/display_manager
  import nkit/app_info
  import nkit/device_info
  import nkit/url_opener
  import nkit/storage
  import nkit/preferences
  import nkit/secure_storage
  import nkit/accessibility_manager
  import nkit/launch_at_login
  import nkit/dialog
  import nkit/message_dialog
  import nkit/menu
  import nkit/tray_icon
  import nkit/tray_manager
  import nkit/image
  import nkit/keyboard_monitor
  import nkit/mouse_monitor
  import nkit/clipboard
  import nkit/file_dialog
  import nkit/alert
  import nkit/drag_drop
  import nkit/notifications
  import nkit/shortcut
  import nkit/shortcut_manager
  import nkit/gui/view
  import nkit/gui/theme
  import nkit/gui/button
  import nkit/gui/label
  import nkit/gui/separator
  import nkit/gui/input
  import nkit/gui/textarea
  import nkit/gui/switch_widget
  import nkit/gui/slider
  import nkit/gui/progress
  import nkit/gui/segmented
  import nkit/gui/select
  import nkit/gui/datepicker
  import nkit/gui/imageview
  import nkit/gui/stack
  import nkit/gui/scroll
  import nkit/gui/card
  import nkit/gui/badge
  import nkit/gui/tabs
  import nkit/gui/avatar
  import nkit/gui/accordion
  import nkit/gui/appdsl
  import nkit/gui/appdsl_cocoa
  import nkit/gui/hover_router
  import nkit/gui/sidebar
  import nkit/gui/sugar
  import nkit/gui/toast
  import nkit/gui/layout
  import nkit/gui/popover
  import nkit/gui/split_view
  import nkit/gui/toolbar
  import nkit/gui/animate

  export geometry, color, keyboard, event, dispatcher
  export id_allocator, object_registry, event_emitter
  export placement, positioning_strategy
  export application
  export window, window_registry, window_manager
  export display, display_manager
  export app_info, device_info, url_opener
  export storage, preferences, secure_storage
  export accessibility_manager, launch_at_login
  export dialog, message_dialog
  export menu, tray_icon, tray_manager
  export image, keyboard_monitor, mouse_monitor
  export clipboard, file_dialog, drag_drop, notifications, alert
  export shortcut, shortcut_manager
  export view, theme
  export button, label, separator
  export input, textarea, switch_widget, slider
  export progress, segmented, select, datepicker, imageview
  export stack, scroll, card, badge, tabs, avatar
  export accordion
  export hover_router
  export sidebar, sugar, toast
  export popover, split_view, toolbar, animate
  export layout

  when defined(macosx) or defined(ios):
    import nkit/platform/macos/nsfunctions
    import nkit/platform/macos/dispatcher_macos
    export nsfunctions, dispatcher_macos
