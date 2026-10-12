#import <Cocoa/Cocoa.h>
#include <string.h>
#include <stdbool.h>

static char g_dock_badge_buffer[256];

void na_dock_set_badge(const char* utf8_label) {
  NSDockTile* tile = [NSApp dockTile];
  if (!tile) {
    return;
  }
  if (!utf8_label || utf8_label[0] == '\0') {
    tile.badgeLabel = nil;
  } else {
    tile.badgeLabel = [NSString stringWithUTF8String:utf8_label];
  }
  [tile display];
}

const char* na_dock_get_badge(void) {
  g_dock_badge_buffer[0] = '\0';
  NSDockTile* tile = [NSApp dockTile];
  if (tile && tile.badgeLabel) {
    const char* utf8 = tile.badgeLabel.UTF8String;
    if (utf8) {
      strncpy(g_dock_badge_buffer, utf8, sizeof(g_dock_badge_buffer) - 1);
      g_dock_badge_buffer[sizeof(g_dock_badge_buffer) - 1] = '\0';
    }
  }
  return g_dock_badge_buffer;
}

int na_dock_request_attention(bool critical) {
  NSInteger req = [NSApp requestUserAttention:(critical ? NSCriticalRequest
                                                       : NSInformationalRequest)];
  return (int)req;
}

void na_dock_cancel_attention(int request_id) {
  [NSApp cancelUserAttentionRequest:request_id];
}

// --- Dock progress overlay -----------------------------------------------
// NSDockTile has no progress API, so we host a small container view:
// app icon snapshot + thin NSProgressIndicator at the bottom.

static NSView* g_dock_container = nil;
static NSImageView* g_dock_image = nil;
static NSProgressIndicator* g_dock_bar = nil;

static void ensure_dock_progress_view(void) {
  if (g_dock_container) {
    return;
  }
  g_dock_container =
      [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 128, 128)];
  g_dock_image =
      [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 128, 128)];
  g_dock_image.imageScaling = NSImageScaleProportionallyUpOrDown;
  [g_dock_container addSubview:g_dock_image];
  g_dock_bar = [[NSProgressIndicator alloc]
      initWithFrame:NSMakeRect(14, 10, 100, 12)];
  g_dock_bar.style = NSProgressIndicatorStyleBar;
  g_dock_bar.minValue = 0.0;
  g_dock_bar.maxValue = 1.0;
  g_dock_bar.doubleValue = 0.0;
  g_dock_bar.indeterminate = NO;
  [g_dock_container addSubview:g_dock_bar];
}

void na_dock_set_progress(double fraction) {
  NSDockTile* tile = [NSApp dockTile];
  if (!tile) {
    return;
  }
  ensure_dock_progress_view();
  if (fraction < 0.0) {
    fraction = 0.0;
  }
  if (fraction > 1.0) {
    fraction = 1.0;
  }
  NSImage* icon = [NSApp applicationIconImage];
  if (icon) {
    g_dock_image.image = icon;
  }
  g_dock_bar.indeterminate = NO;
  [g_dock_bar stopAnimation:nil];
  g_dock_bar.doubleValue = fraction;
  tile.contentView = g_dock_container;
  [tile display];
}

void na_dock_set_progress_indeterminate(bool on) {
  NSDockTile* tile = [NSApp dockTile];
  if (!tile) {
    return;
  }
  ensure_dock_progress_view();
  NSImage* icon = [NSApp applicationIconImage];
  if (icon) {
    g_dock_image.image = icon;
  }
  if (on) {
    g_dock_bar.indeterminate = YES;
    [g_dock_bar startAnimation:nil];
    tile.contentView = g_dock_container;
  } else {
    g_dock_bar.indeterminate = NO;
    [g_dock_bar stopAnimation:nil];
  }
  [tile display];
}

void na_dock_clear_progress(void) {
  NSDockTile* tile = [NSApp dockTile];
  if (!tile) {
    return;
  }
  if (g_dock_bar && g_dock_bar.isIndeterminate) {
    [g_dock_bar stopAnimation:nil];
  }
  tile.contentView = nil;
  [tile display];
}

void na_dock_display(void) {
  NSDockTile* tile = [NSApp dockTile];
  if (tile) {
    [tile display];
  }
}
