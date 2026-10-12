#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#include <string.h>
#include <stdbool.h>
#import "gui_common.h"

// Native NSTableView / NSOutlineView widgets with pushed row stores.
// Nim owns the model; the shims below mirror it into NSArray structures
// the AppKit data sources read back. Events (selection, sort, expand,
// collapse, activate) travel through the two global callbacks.
//
// Event kinds, table:   0 selection, 1 sort(col=a, ascending=b), 2 activate.
// Event kinds, outline: 0 selection, 1 expand(key), 2 collapse(key),
//                       3 activate.

typedef void (*na_table_event_fn)(uint32_t widget_id, int kind, int64_t a,
                                  int64_t b, int64_t c, void* ctx);
typedef void (*na_outline_event_fn)(uint32_t widget_id, int kind, uint64_t key,
                                    int64_t col, void* ctx);

static na_table_event_fn g_table_fn = NULL;
static void* g_table_ctx = NULL;
static na_outline_event_fn g_outline_fn = NULL;
static void* g_outline_ctx = NULL;

void na_table_set_event_callback(na_table_event_fn fn, void* ctx) {
  g_table_fn = fn;
  g_table_ctx = ctx;
}

void na_outline_set_event_callback(na_outline_event_fn fn, void* ctx) {
  g_outline_fn = fn;
  g_outline_ctx = ctx;
}

static void table_emit(uint32_t wid, int kind, int64_t a, int64_t b,
                       int64_t c) {
  if (g_table_fn) {
    g_table_fn(wid, kind, a, b, c, g_table_ctx);
  }
}

static void outline_emit(uint32_t wid, int kind, uint64_t key, int64_t col) {
  if (g_outline_fn) {
    g_outline_fn(wid, kind, key, col, g_outline_ctx);
  }
}

// Cell kinds shared by table + outline columns.
#define NA_CELL_TEXT 0
#define NA_CELL_CHECK 1
#define NA_CELL_IMAGE 2

extern void* na_image_native_ptr(int64_t handle);

static NSString* check_key(int64_t a, int64_t b) {
  return [NSString stringWithFormat:@"%lld:%lld", (long long)a, (long long)b];
}

// ---------------------------------------------------------------------------
// Table
// ---------------------------------------------------------------------------

@interface NATableDelegate : NSObject <NSTableViewDataSource,
                                       NSTableViewDelegate>
@property(nonatomic, assign) uint32_t widgetId;
@property(nonatomic, strong) NSMutableArray<NSArray<NSString*>*>* rows;
@property(nonatomic, strong) NSMutableArray<NSNumber*>* colKinds;
@property(nonatomic, strong) NSMutableDictionary<NSString*, NSNumber*>* checks;
@property(nonatomic, strong) NSMutableDictionary<NSString*, NSImage*>* images;
@property(nonatomic, strong) NSMutableDictionary<NSNumber*, NSNumber*>* rowHeights;
@property(nonatomic, assign) BOOL sortGuard;
@property(nonatomic, assign) BOOL reorderable;
@property(nonatomic, assign) BOOL acceptsFiles;
@property(nonatomic, strong) NSArray<NSNumber*>* pendingDropRows;
@property(nonatomic, strong) NSArray<NSString*>* pendingDropFiles;
- (void)doubleClick:(id)sender;
@end

static NSString* const kTableRowUTI = @"com.nkit.table.rows";
static NSString* const kOutlineKeyUTI = @"com.nkit.outline.keys";

static NSArray<NSString*>* drop_file_paths(id<NSDraggingInfo> sender) {
  NSPasteboard* pb = [sender draggingPasteboard];
  NSArray* urls =
      [pb readObjectsForClasses:@[ [NSURL class] ] options:nil];
  NSMutableArray<NSString*>* paths = [NSMutableArray array];
  for (NSURL* url in urls) {
    if (url.isFileURL) {
      [paths addObject:url.path];
    }
  }
  return paths;
}

@implementation NATableDelegate

- (NSInteger)numberOfRowsInTableView:(NSTableView*)tv {
  (void)tv;
  return (NSInteger)self.rows.count;
}

- (int)kindForColumn:(NSInteger)col {
  if (col < 0 || col >= (NSInteger)self.colKinds.count) {
    return NA_CELL_TEXT;
  }
  return self.colKinds[(NSUInteger)col].intValue;
}

- (id)tableView:(NSTableView*)tv
    objectValueForTableColumn:(NSTableColumn*)tc
                          row:(NSInteger)row {
  (void)tv;
  NSInteger col = tc.identifier.integerValue;
  int kind = [self kindForColumn:col];
  if (kind == NA_CELL_CHECK) {
    NSNumber* v = self.checks[check_key(row, col)];
    return v ? v : @(NO);
  }
  if (kind == NA_CELL_IMAGE) {
    return self.images[check_key(row, col)];
  }
  if (row < 0 || row >= (NSInteger)self.rows.count) {
    return nil;
  }
  NSArray<NSString*>* cells = self.rows[(NSUInteger)row];
  if (col < 0 || col >= (NSInteger)cells.count) {
    return nil;
  }
  return cells[(NSUInteger)col];
}

- (void)tableView:(NSTableView*)tv
    setObjectValue:(id)value
    forTableColumn:(NSTableColumn*)tc
               row:(NSInteger)row {
  (void)tv;
  NSInteger col = tc.identifier.integerValue;
  int kind = [self kindForColumn:col];
  if (kind == NA_CELL_CHECK) {
    BOOL checked = [value boolValue];
    self.checks[check_key(row, col)] = @(checked);
    table_emit(self.widgetId, 3, (int64_t)row, (int64_t)col,
               checked ? 1 : 0);
    return;
  }
  if (kind == NA_CELL_TEXT) {
    NSString* text = [value description] ?: @"";
    if (row >= 0 && row < (NSInteger)self.rows.count &&
        col >= 0 && col < (NSInteger)self.rows[(NSUInteger)row].count) {
      NSMutableArray* cells =
          [self.rows[(NSUInteger)row] mutableCopy];
      cells[(NSUInteger)col] = text;
      self.rows[(NSUInteger)row] = cells;
    }
    table_emit(self.widgetId, 4, (int64_t)row, (int64_t)col, 0);
  }
}

- (CGFloat)tableView:(NSTableView*)tv heightOfRow:(NSInteger)row {
  NSNumber* h = self.rowHeights[@(row)];
  return h ? h.doubleValue : tv.rowHeight;
}

- (NSString*)tableView:(NSTableView*)tv
    typeSelectStringForTableColumn:(NSTableColumn*)tc
                               row:(NSInteger)row {
  (void)tv;
  NSInteger col = tc.identifier.integerValue;
  if (row < 0 || row >= (NSInteger)self.rows.count) {
    return nil;
  }
  NSArray<NSString*>* cells = self.rows[(NSUInteger)row];
  if (col < 0 || col >= (NSInteger)cells.count) {
    return nil;
  }
  return cells[(NSUInteger)col];
}

- (void)tableViewSelectionDidChange:(NSNotification*)note {
  (void)note;
  table_emit(self.widgetId, 0, 0, 0, 0);
}

- (void)tableView:(NSTableView*)tv
    sortDescriptorsDidChange:(NSArray<NSSortDescriptor*>*)oldDescriptors {
  (void)tv;
  (void)oldDescriptors;
  if (self.sortGuard) {
    return;
  }
  NSSortDescriptor* sd = tv.sortDescriptors.firstObject;
  if (!sd) {
    return;
  }
  NSInteger col = sd.key.integerValue;
  table_emit(self.widgetId, 1, (int64_t)col, sd.ascending ? 1 : 0, 0);
}

- (void)doubleClick:(id)sender {
  (void)sender;
  table_emit(self.widgetId, 2, 0, 0, 0);
}

// --- Drag & drop: internal reorder + external file drops ---

- (BOOL)tableView:(NSTableView*)tv
    writeRowsWithIndexes:(NSIndexSet*)rows
            toPasteboard:(NSPasteboard*)pb {
  (void)tv;
  if (!self.reorderable) {
    return NO;
  }
  NSMutableArray<NSNumber*>* list = [NSMutableArray array];
  for (NSUInteger i = rows.firstIndex; i != NSNotFound;
       i = [rows indexGreaterThanIndex:i]) {
    [list addObject:@(i)];
  }
  self.pendingDropRows = list;
  [pb declareTypes:@[ kTableRowUTI ] owner:self];
  [pb setString:@"" forType:kTableRowUTI];
  return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tv
                validateDrop:(id<NSDraggingInfo>)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)op {
  (void)tv;
  (void)row;
  (void)op;
  NSPasteboard* pb = [info draggingPasteboard];
  NSArray* types = [pb types];
  if (self.acceptsFiles && [types containsObject:NSPasteboardTypeFileURL]) {
    return NSDragOperationCopy;
  }
  if (self.reorderable && [types containsObject:kTableRowUTI]) {
    return NSDragOperationMove;
  }
  return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView*)tv
       acceptDrop:(id<NSDraggingInfo>)info
              row:(NSInteger)row
    dropOperation:(NSTableViewDropOperation)op {
  (void)tv;
  (void)op;
  NSPasteboard* pb = [info draggingPasteboard];
  NSArray* types = [pb types];
  if (self.acceptsFiles && [types containsObject:NSPasteboardTypeFileURL]) {
    self.pendingDropFiles = drop_file_paths(info);
    table_emit(self.widgetId, 6, (int64_t)row,
               (int64_t)self.pendingDropFiles.count, 0);
    return YES;
  }
  if (self.reorderable && [types containsObject:kTableRowUTI]) {
    table_emit(self.widgetId, 5, (int64_t)row, 0, 0);
    return YES;
  }
  return NO;
}

@end

static NSTableView* table_for_scroll(void* ptr) {
  NSScrollView* sv = (__bridge NSScrollView*)ptr;
  if (!sv) {
    return nil;
  }
  return (NSTableView*)objc_getAssociatedObject(sv, "na_table_view");
}

static NATableDelegate* table_delegate_for(void* ptr) {
  NSTableView* tv = table_for_scroll(ptr);
  if (!tv) {
    return nil;
  }
  return (NATableDelegate*)objc_getAssociatedObject(tv, "na_table_delegate");
}

void* na_table_create(uint32_t widget_id, bool multi) {
  NSScrollView* sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 300, 200)];
  sv.hasVerticalScroller = YES;
  sv.hasHorizontalScroller = YES;
  NSTableView* tv = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 300, 200)];
  tv.allowsMultipleSelection = multi ? YES : NO;
  tv.allowsEmptySelection = YES;
  tv.allowsColumnSelection = NO;
  NATableDelegate* delegate = [[NATableDelegate alloc] init];
  delegate.widgetId = widget_id;
  delegate.rows = [NSMutableArray array];
  delegate.colKinds = [NSMutableArray array];
  delegate.checks = [NSMutableDictionary dictionary];
  delegate.images = [NSMutableDictionary dictionary];
  delegate.rowHeights = [NSMutableDictionary dictionary];
  tv.dataSource = delegate;
  tv.delegate = delegate;
  tv.target = delegate;
  tv.doubleAction = @selector(doubleClick:);
  [tv registerForDraggedTypes:@[ kTableRowUTI, NSPasteboardTypeFileURL ]];
  objc_setAssociatedObject(tv, "na_table_delegate", delegate,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(sv, "na_table_view", tv,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  sv.documentView = tv;
  na_gui_register_view(sv);
  return (__bridge void*)sv;
}

void na_table_free(uint32_t widget_id, void* ptr) {
  (void)widget_id;
  NSScrollView* sv = (__bridge NSScrollView*)ptr;
  if (sv) {
    [sv removeFromSuperview];
    na_gui_unregister_view(sv);
  }
}

int64_t na_table_add_column(void* ptr, const char* title, double width,
                            bool sortable, int kind) {
  NSTableView* tv = table_for_scroll(ptr);
  NATableDelegate* delegate = table_delegate_for(ptr);
  if (!tv || !delegate) {
    return -1;
  }
  int64_t index = (int64_t)tv.tableColumns.count;
  NSString* ident = [NSString stringWithFormat:@"%lld", (long long)index];
  NSTableColumn* col = [[NSTableColumn alloc] initWithIdentifier:ident];
  col.title = title ? [NSString stringWithUTF8String:title] : @"";
  col.width = width > 0 ? width : 120.0;
  if (kind == NA_CELL_CHECK) {
    NSButtonCell* cell = [[NSButtonCell alloc] init];
    cell.buttonType = NSSwitchButton;
    cell.title = @"";
    col.dataCell = cell;
  } else if (kind == NA_CELL_IMAGE) {
    col.dataCell = [[NSImageCell alloc] init];
  }
  col.editable = NO;
  if (sortable) {
    col.sortDescriptorPrototype =
        [NSSortDescriptor sortDescriptorWithKey:ident ascending:YES];
  }
  [tv addTableColumn:col];
  [delegate.colKinds addObject:@(kind)];
  return index;
}

void na_table_clear_columns(void* ptr) {
  NSTableView* tv = table_for_scroll(ptr);
  NATableDelegate* delegate = table_delegate_for(ptr);
  if (!tv) {
    return;
  }
  for (NSTableColumn* col in [tv.tableColumns copy]) {
    [tv removeTableColumn:col];
  }
  if (delegate) {
    [delegate.colKinds removeAllObjects];
  }
}

int64_t na_table_column_count(void* ptr) {
  NSTableView* tv = table_for_scroll(ptr);
  return tv ? (int64_t)tv.tableColumns.count : 0;
}

void na_table_set_column_width(void* ptr, int64_t col, double width) {
  NSTableView* tv = table_for_scroll(ptr);
  if (!tv || col < 0 || col >= (int64_t)tv.tableColumns.count || width <= 0) {
    return;
  }
  tv.tableColumns[(NSUInteger)col].width = width;
}

void na_table_set_rows(void* ptr, const char** cells, int64_t nrows,
                       int64_t ncols) {
  NATableDelegate* delegate = table_delegate_for(ptr);
  NSTableView* tv = table_for_scroll(ptr);
  if (!delegate || !tv) {
    return;
  }
  NSMutableArray<NSArray<NSString*>*>* rows = [NSMutableArray array];
  for (int64_t r = 0; r < nrows; r++) {
    NSMutableArray<NSString*>* row = [NSMutableArray array];
    for (int64_t c = 0; c < ncols; c++) {
      const char* text = cells ? cells[r * ncols + c] : NULL;
      [row addObject:text ? [NSString stringWithUTF8String:text] : @""];
    }
    [rows addObject:row];
  }
  delegate.rows = rows;
  [delegate.checks removeAllObjects];
  [delegate.images removeAllObjects];
  [delegate.rowHeights removeAllObjects];
  [tv reloadData];
}

int64_t na_table_row_count(void* ptr) {
  NATableDelegate* delegate = table_delegate_for(ptr);
  return delegate ? (int64_t)delegate.rows.count : 0;
}

void na_table_set_sort_indicator(void* ptr, int64_t col, int ascending) {
  NSTableView* tv = table_for_scroll(ptr);
  NATableDelegate* delegate = table_delegate_for(ptr);
  if (!tv || !delegate) {
    return;
  }
  delegate.sortGuard = YES;
  if (col < 0 || col >= (int64_t)tv.tableColumns.count || ascending == 0) {
    tv.sortDescriptors = @[];
  } else {
    NSString* key =
        [NSString stringWithFormat:@"%lld", (long long)col];
    tv.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:key
                                                         ascending:(ascending == 1)] ];
  }
  delegate.sortGuard = NO;
}

int na_table_sort_chain(void* ptr, int64_t* cols, bool* ascending, int max) {
  NSTableView* tv = table_for_scroll(ptr);
  if (!tv || !cols || !ascending || max <= 0) {
    return 0;
  }
  int n = 0;
  for (NSSortDescriptor* sd in tv.sortDescriptors) {
    if (n >= max) {
      break;
    }
    cols[n] = (int64_t)sd.key.integerValue;
    ascending[n] = sd.ascending ? true : false;
    n++;
  }
  return n;
}

void na_table_set_sort_indicators(void* ptr, const int64_t* cols,
                                  const bool* ascending, int n) {
  NSTableView* tv = table_for_scroll(ptr);
  NATableDelegate* delegate = table_delegate_for(ptr);
  if (!tv || !delegate) {
    return;
  }
  delegate.sortGuard = YES;
  NSMutableArray<NSSortDescriptor*>* sds = [NSMutableArray array];
  if (cols && ascending) {
    for (int i = 0; i < n; i++) {
      if (cols[i] < 0 || cols[i] >= (int64_t)tv.tableColumns.count) {
        continue;
      }
      NSString* key =
          [NSString stringWithFormat:@"%lld", (long long)cols[i]];
      [sds addObject:[NSSortDescriptor sortDescriptorWithKey:key
                                                  ascending:ascending[i]]];
    }
  }
  tv.sortDescriptors = sds;
  delegate.sortGuard = NO;
}

void na_table_set_row_height(void* ptr, double height) {
  NSTableView* tv = table_for_scroll(ptr);
  if (tv && height > 0) {
    tv.rowHeight = height;
  }
}

void na_table_set_row_heights(void* ptr, const int64_t* rows,
                              const double* heights, int n) {
  NATableDelegate* delegate = table_delegate_for(ptr);
  NSTableView* tv = table_for_scroll(ptr);
  if (!delegate || !tv || !rows || !heights || n <= 0) {
    return;
  }
  for (int i = 0; i < n; i++) {
    if (rows[i] >= 0 && heights[i] > 0) {
      delegate.rowHeights[@(rows[i])] = @(heights[i]);
    }
  }
  [tv reloadData];
}

void na_table_clear_row_heights(void* ptr) {
  NATableDelegate* delegate = table_delegate_for(ptr);
  NSTableView* tv = table_for_scroll(ptr);
  if (!delegate) {
    return;
  }
  [delegate.rowHeights removeAllObjects];
  if (tv) {
    [tv reloadData];
  }
}

void na_table_set_cell_checked(void* ptr, int64_t row, int64_t col,
                               bool checked) {
  NATableDelegate* delegate = table_delegate_for(ptr);
  NSTableView* tv = table_for_scroll(ptr);
  if (!delegate || !tv) {
    return;
  }
  delegate.checks[check_key(row, col)] = @(checked ? YES : NO);
  [tv reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row]
               columnIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)col]];
}

bool na_table_is_cell_checked(void* ptr, int64_t row, int64_t col) {
  NATableDelegate* delegate = table_delegate_for(ptr);
  if (!delegate) {
    return false;
  }
  NSNumber* v = delegate.checks[check_key(row, col)];
  return v ? v.boolValue : false;
}

void na_table_set_cell_image(void* ptr, int64_t row, int64_t col,
                             int64_t image_handle) {
  NATableDelegate* delegate = table_delegate_for(ptr);
  NSTableView* tv = table_for_scroll(ptr);
  if (!delegate || !tv) {
    return;
  }
  if (image_handle == 0) {
    [delegate.images removeObjectForKey:check_key(row, col)];
  } else {
    NSImage* img = (__bridge NSImage*)na_image_native_ptr(image_handle);
    if (img) {
      delegate.images[check_key(row, col)] = img;
    }
  }
  [tv reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row]
               columnIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)col]];
}

const char* na_table_get_cell(void* ptr, int64_t row, int64_t col) {
  static char table_cell_buffer[8192];
  table_cell_buffer[0] = '\0';
  NATableDelegate* delegate = table_delegate_for(ptr);
  if (!delegate || row < 0 || row >= (int64_t)delegate.rows.count) {
    return table_cell_buffer;
  }
  NSArray<NSString*>* cells = delegate.rows[(NSUInteger)row];
  if (col < 0 || col >= (int64_t)cells.count) {
    return table_cell_buffer;
  }
  const char* utf8 = cells[(NSUInteger)col].UTF8String;
  if (utf8) {
    strncpy(table_cell_buffer, utf8, sizeof(table_cell_buffer) - 1);
    table_cell_buffer[sizeof(table_cell_buffer) - 1] = '\0';
  }
  return table_cell_buffer;
}

void na_table_set_col_editable(void* ptr, int64_t col, bool editable) {
  NSTableView* tv = table_for_scroll(ptr);
  if (!tv || col < 0 || col >= (int64_t)tv.tableColumns.count) {
    return;
  }
  tv.tableColumns[(NSUInteger)col].editable = editable ? YES : NO;
}

int na_table_selected_rows(void* ptr, int64_t* out, int max) {
  NSTableView* tv = table_for_scroll(ptr);
  if (!tv || !out || max <= 0) {
    return 0;
  }
  int n = 0;
  NSIndexSet* set = tv.selectedRowIndexes;
  for (NSUInteger i = set.firstIndex;
       i != NSNotFound && n < max;
       i = [set indexGreaterThanIndex:i]) {
    out[n++] = (int64_t)i;
  }
  return n;
}

void na_table_select_rows(void* ptr, const int64_t* rows, int n, bool extend) {
  NSTableView* tv = table_for_scroll(ptr);
  if (!tv || !rows || n <= 0) {
    return;
  }
  NSMutableIndexSet* set =
      extend ? [tv.selectedRowIndexes mutableCopy] : [NSMutableIndexSet indexSet];
  for (int i = 0; i < n; i++) {
    if (rows[i] >= 0) {
      [set addIndex:(NSUInteger)rows[i]];
    }
  }
  [tv selectRowIndexes:set byExtendingSelection:NO];
}

void na_table_clear_selection(void* ptr) {
  NSTableView* tv = table_for_scroll(ptr);
  if (tv) {
    [tv deselectAll:nil];
  }
}

void na_table_scroll_to_row(void* ptr, int64_t row) {
  NSTableView* tv = table_for_scroll(ptr);
  if (tv && row >= 0) {
    [tv scrollRowToVisible:row];
  }
}

void na_table_set_multi(void* ptr, bool multi) {
  NSTableView* tv = table_for_scroll(ptr);
  if (tv) {
    tv.allowsMultipleSelection = multi ? YES : NO;
  }
}

// Test hooks: drive the same emit paths a live interaction would take.
void na_table_fire_select(uint32_t widget_id) {
  table_emit(widget_id, 0, 0, 0, 0);
}

void na_table_fire_sort(uint32_t widget_id, int64_t col, bool ascending) {
  table_emit(widget_id, 1, col, ascending ? 1 : 0, 0);
}

void na_table_fire_activate(uint32_t widget_id) {
  table_emit(widget_id, 2, 0, 0, 0);
}

void na_table_fire_check(uint32_t widget_id, int64_t row, int64_t col,
                         bool checked) {
  table_emit(widget_id, 3, row, col, checked ? 1 : 0);
}

void na_table_fire_edit(uint32_t widget_id, int64_t row, int64_t col) {
  table_emit(widget_id, 4, row, col, 0);
}

// --- Drag & drop state -----------------------------------------------------

void na_table_set_reorderable(void* ptr, bool reorderable) {
  NATableDelegate* delegate = table_delegate_for(ptr);
  if (delegate) {
    delegate.reorderable = reorderable ? YES : NO;
  }
}

bool na_table_is_reorderable(void* ptr) {
  NATableDelegate* delegate = table_delegate_for(ptr);
  return delegate ? (delegate.reorderable ? true : false) : false;
}

void na_table_set_accepts_files(void* ptr, bool accept) {
  NATableDelegate* delegate = table_delegate_for(ptr);
  if (delegate) {
    delegate.acceptsFiles = accept ? YES : NO;
  }
}

bool na_table_accepts_files(void* ptr) {
  NATableDelegate* delegate = table_delegate_for(ptr);
  return delegate ? (delegate.acceptsFiles ? true : false) : false;
}

int na_table_drop_sources(void* ptr, int64_t* out, int max) {
  NATableDelegate* delegate = table_delegate_for(ptr);
  if (!delegate || !out || max <= 0) {
    return 0;
  }
  int n = 0;
  for (NSNumber* row in delegate.pendingDropRows) {
    if (n >= max) {
      break;
    }
    out[n++] = (int64_t)row.longLongValue;
  }
  return n;
}

int na_table_drop_files(void* ptr, char* buf, int maxLen) {
  NATableDelegate* delegate = table_delegate_for(ptr);
  if (!delegate || !buf || maxLen <= 0) {
    return 0;
  }
  buf[0] = '\0';
  NSString* joined =
      [delegate.pendingDropFiles componentsJoinedByString:@"\n"];
  if (!joined) {
    return 0;
  }
  const char* utf8 = joined.UTF8String;
  if (utf8) {
    strncpy(buf, utf8, (size_t)(maxLen - 1));
    buf[maxLen - 1] = '\0';
  }
  return (int)delegate.pendingDropFiles.count;
}

void na_table_fire_reorder(uint32_t widget_id, void* ptr, int64_t target,
                           const int64_t* sources, int n) {
  NATableDelegate* delegate = table_delegate_for(ptr);
  if (delegate) {
    NSMutableArray<NSNumber*>* list = [NSMutableArray array];
    if (sources) {
      for (int i = 0; i < n; i++) {
        [list addObject:@(sources[i])];
      }
    }
    delegate.pendingDropRows = list;
  }
  table_emit(widget_id, 5, target, 0, 0);
}

void na_table_fire_filedrop(uint32_t widget_id, void* ptr, int64_t target,
                            const char** paths, int n) {
  NATableDelegate* delegate = table_delegate_for(ptr);
  if (delegate) {
    NSMutableArray<NSString*>* list = [NSMutableArray array];
    if (paths) {
      for (int i = 0; i < n; i++) {
        if (paths[i]) {
          [list addObject:[NSString stringWithUTF8String:paths[i]]];
        }
      }
    }
    delegate.pendingDropFiles = list;
  }
  table_emit(widget_id, 6, target, (int64_t)n, 0);
}

// ---------------------------------------------------------------------------
// Outline
// ---------------------------------------------------------------------------

@interface NAOutlineDelegate : NSObject <NSOutlineViewDataSource,
                                        NSOutlineViewDelegate>
@property(nonatomic, assign) uint32_t widgetId;
// key -> @{@"parent": NSNumber, @"expanded": NSNumber}
@property(nonatomic, strong) NSMutableDictionary<NSNumber*, NSDictionary*>* nodes;
// parentKey -> ordered child keys
@property(nonatomic, strong) NSMutableDictionary<NSNumber*, NSMutableArray<NSNumber*>*>* children;
// key -> cell texts per column
@property(nonatomic, strong) NSMutableDictionary<NSNumber*, NSMutableArray<NSString*>*>* texts;
@property(nonatomic, strong) NSMutableArray<NSNumber*>* colKinds;
@property(nonatomic, strong) NSMutableDictionary<NSString*, NSNumber*>* checks;
@property(nonatomic, strong) NSMutableDictionary<NSString*, NSImage*>* images;
@property(nonatomic, strong) NSMutableDictionary<NSNumber*, NSNumber*>* rowHeights;
@property(nonatomic, strong) NSMutableSet<NSNumber*>* moreKeys;
@property(nonatomic, assign) BOOL acceptsMoves;
@property(nonatomic, assign) BOOL acceptsFiles;
@property(nonatomic, strong) NSArray<NSNumber*>* pendingDropKeys;
@property(nonatomic, strong) NSArray<NSString*>* pendingDropFiles;
@property(nonatomic, assign) int64_t ncols;
@property(nonatomic, assign) BOOL changeGuard;
- (void)doubleClick:(id)sender;
@end

@implementation NAOutlineDelegate

- (NSArray<NSNumber*>*)kidsOf:(id)item {
  NSNumber* parent = item ? (NSNumber*)item : @(0);
  NSArray<NSNumber*>* kids = self.children[parent];
  return kids ? kids : @[];
}

static NSString* outline_check_key(uint64_t key, int64_t col) {
  return [NSString stringWithFormat:@"%llu:%lld", key, (long long)col];
}

- (int)kindForColumn:(NSInteger)col {
  if (col < 0 || col >= (NSInteger)self.colKinds.count) {
    return NA_CELL_TEXT;
  }
  return self.colKinds[(NSUInteger)col].intValue;
}

- (NSInteger)outlineView:(NSOutlineView*)ov numberOfChildrenOfItem:(id)item {
  (void)ov;
  return (NSInteger)[self kidsOf:item].count;
}

- (id)outlineView:(NSOutlineView*)ov child:(NSInteger)index ofItem:(id)item {
  (void)ov;
  NSArray<NSNumber*>* kids = [self kidsOf:item];
  if (index < 0 || index >= (NSInteger)kids.count) {
    return nil;
  }
  return kids[(NSUInteger)index];
}

- (BOOL)outlineView:(NSOutlineView*)ov isItemExpandable:(id)item {
  (void)ov;
  if ([self kidsOf:item].count > 0) {
    return YES;
  }
  return [self.moreKeys containsObject:(NSNumber*)item] ? YES : NO;
}

- (id)outlineView:(NSOutlineView*)ov
    objectValueForTableColumn:(NSTableColumn*)tc
                       byItem:(id)item {
  (void)ov;
  NSInteger col = tc.identifier.integerValue;
  uint64_t key = [(NSNumber*)item unsignedLongLongValue];
  int kind = [self kindForColumn:col];
  if (kind == NA_CELL_CHECK) {
    NSNumber* v = self.checks[outline_check_key(key, col)];
    return v ? v : @(NO);
  }
  if (kind == NA_CELL_IMAGE) {
    return self.images[outline_check_key(key, col)];
  }
  NSArray<NSString*>* texts = self.texts[(NSNumber*)item];
  if (!texts || col < 0 || col >= (NSInteger)texts.count) {
    return nil;
  }
  return texts[(NSUInteger)col];
}

- (void)outlineView:(NSOutlineView*)ov
    setObjectValue:(id)value
    forTableColumn:(NSTableColumn*)tc
            byItem:(id)item {
  (void)ov;
  NSInteger col = tc.identifier.integerValue;
  uint64_t key = [(NSNumber*)item unsignedLongLongValue];
  int kind = [self kindForColumn:col];
  if (kind == NA_CELL_CHECK) {
    BOOL checked = [value boolValue];
    self.checks[outline_check_key(key, col)] = @(checked);
    outline_emit(self.widgetId, 4, key, col);
    return;
  }
  if (kind == NA_CELL_TEXT) {
    NSString* text = [value description] ?: @"";
    NSMutableArray<NSString*>* texts = self.texts[(NSNumber*)item];
    if (!texts) {
      texts = [NSMutableArray array];
      self.texts[(NSNumber*)item] = texts;
    }
    while ((NSInteger)texts.count <= col) {
      [texts addObject:@""];
    }
    if (col >= 0) {
      texts[(NSUInteger)col] = text;
    }
    outline_emit(self.widgetId, 5, key, col);
  }
}

- (CGFloat)outlineView:(NSOutlineView*)ov heightOfRowByItem:(id)item {
  NSNumber* h = self.rowHeights[(NSNumber*)item];
  return h ? h.doubleValue : ov.rowHeight;
}

- (NSString*)outlineView:(NSOutlineView*)ov
    typeSelectStringForTableColumn:(NSTableColumn*)tc
                             item:(id)item {
  (void)ov;
  NSInteger col = tc.identifier.integerValue;
  NSArray<NSString*>* texts = self.texts[(NSNumber*)item];
  if (!texts || col < 0 || col >= (NSInteger)texts.count) {
    return nil;
  }
  return texts[(NSUInteger)col];
}

- (void)outlineViewSelectionDidChange:(NSNotification*)note {
  (void)note;
  outline_emit(self.widgetId, 0, 0, 0);
}

- (void)outlineViewItemDidExpand:(NSNotification*)note {
  if (self.changeGuard) {
    return;
  }
  NSNumber* key = note.userInfo[@"NSObject"];
  outline_emit(self.widgetId, 1, key ? key.unsignedLongLongValue : 0, 0);
}

- (void)outlineViewItemDidCollapse:(NSNotification*)note {
  if (self.changeGuard) {
    return;
  }
  NSNumber* key = note.userInfo[@"NSObject"];
  outline_emit(self.widgetId, 2, key ? key.unsignedLongLongValue : 0, 0);
}

- (void)doubleClick:(id)sender {
  (void)sender;
  outline_emit(self.widgetId, 3, 0, 0);
}

// --- Drag & drop: internal node moves + external file drops ---

- (BOOL)outlineView:(NSOutlineView*)ov
         writeItems:(NSArray*)items
       toPasteboard:(NSPasteboard*)pb {
  (void)ov;
  if (!self.acceptsMoves) {
    return NO;
  }
  NSMutableArray<NSNumber*>* keys = [NSMutableArray array];
  for (id item in items) {
    [keys addObject:(NSNumber*)item];
  }
  self.pendingDropKeys = keys;
  [pb declareTypes:@[ kOutlineKeyUTI ] owner:self];
  [pb setString:@"" forType:kOutlineKeyUTI];
  return YES;
}

- (NSDragOperation)outlineView:(NSOutlineView*)ov
                  validateDrop:(id<NSDraggingInfo>)info
                  proposedItem:(id)item
            proposedChildIndex:(NSInteger)index {
  (void)ov;
  (void)item;
  (void)index;
  NSPasteboard* pb = [info draggingPasteboard];
  NSArray* types = [pb types];
  if (self.acceptsFiles && [types containsObject:NSPasteboardTypeFileURL]) {
    return NSDragOperationCopy;
  }
  if (self.acceptsMoves && [types containsObject:kOutlineKeyUTI]) {
    return NSDragOperationMove;
  }
  return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView*)ov
         acceptDrop:(id<NSDraggingInfo>)info
               item:(id)item
         childIndex:(NSInteger)index {
  (void)ov;
  NSPasteboard* pb = [info draggingPasteboard];
  NSArray* types = [pb types];
  uint64_t parent = item ? [(NSNumber*)item unsignedLongLongValue] : 0;
  if (self.acceptsFiles && [types containsObject:NSPasteboardTypeFileURL]) {
    self.pendingDropFiles = drop_file_paths(info);
    outline_emit(self.widgetId, 7, parent, (int64_t)index);
    return YES;
  }
  if (self.acceptsMoves && [types containsObject:kOutlineKeyUTI]) {
    outline_emit(self.widgetId, 6, parent, (int64_t)index);
    return YES;
  }
  return NO;
}

@end

static NSOutlineView* outline_for_scroll(void* ptr) {
  NSScrollView* sv = (__bridge NSScrollView*)ptr;
  if (!sv) {
    return nil;
  }
  return (NSOutlineView*)objc_getAssociatedObject(sv, "na_outline_view");
}

static NAOutlineDelegate* outline_delegate_for(void* ptr) {
  NSOutlineView* ov = outline_for_scroll(ptr);
  if (!ov) {
    return nil;
  }
  return (NAOutlineDelegate*)objc_getAssociatedObject(ov, "na_outline_delegate");
}

void* na_outline_create(uint32_t widget_id, bool multi) {
  NSScrollView* sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 300, 200)];
  sv.hasVerticalScroller = YES;
  sv.hasHorizontalScroller = YES;
  NSOutlineView* ov = [[NSOutlineView alloc] initWithFrame:NSMakeRect(0, 0, 300, 200)];
  ov.allowsMultipleSelection = multi ? YES : NO;
  ov.allowsEmptySelection = YES;
  ov.allowsColumnSelection = NO;
  NAOutlineDelegate* delegate = [[NAOutlineDelegate alloc] init];
  delegate.widgetId = widget_id;
  delegate.nodes = [NSMutableDictionary dictionary];
  delegate.children = [NSMutableDictionary dictionary];
  delegate.texts = [NSMutableDictionary dictionary];
  delegate.colKinds = [NSMutableArray array];
  delegate.checks = [NSMutableDictionary dictionary];
  delegate.images = [NSMutableDictionary dictionary];
  delegate.rowHeights = [NSMutableDictionary dictionary];
  ov.dataSource = delegate;
  ov.delegate = delegate;
  ov.target = delegate;
  ov.doubleAction = @selector(doubleClick:);
  [ov registerForDraggedTypes:@[ kOutlineKeyUTI, NSPasteboardTypeFileURL ]];
  objc_setAssociatedObject(ov, "na_outline_delegate", delegate,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(sv, "na_outline_view", ov,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  sv.documentView = ov;
  na_gui_register_view(sv);
  return (__bridge void*)sv;
}

void na_outline_free(uint32_t widget_id, void* ptr) {
  (void)widget_id;
  NSScrollView* sv = (__bridge NSScrollView*)ptr;
  if (sv) {
    [sv removeFromSuperview];
    na_gui_unregister_view(sv);
  }
}

int64_t na_outline_add_column(void* ptr, const char* title, double width,
                              int kind) {
  NSOutlineView* ov = outline_for_scroll(ptr);
  NAOutlineDelegate* delegate = outline_delegate_for(ptr);
  if (!ov || !delegate) {
    return -1;
  }
  int64_t index = (int64_t)ov.tableColumns.count;
  NSString* ident = [NSString stringWithFormat:@"%lld", (long long)index];
  NSTableColumn* col = [[NSTableColumn alloc] initWithIdentifier:ident];
  col.title = title ? [NSString stringWithUTF8String:title] : @"";
  col.width = width > 0 ? width : 160.0;
  if (kind == NA_CELL_CHECK) {
    NSButtonCell* cell = [[NSButtonCell alloc] init];
    cell.buttonType = NSSwitchButton;
    cell.title = @"";
    col.dataCell = cell;
  } else if (kind == NA_CELL_IMAGE) {
    col.dataCell = [[NSImageCell alloc] init];
  }
  col.editable = NO;
  if (index == 0) {
    col.identifier = @"0";
    ov.outlineTableColumn = col;
  }
  [ov addTableColumn:col];
  delegate.ncols = (int64_t)ov.tableColumns.count;
  [delegate.colKinds addObject:@(kind)];
  return index;
}

void na_outline_clear_columns(void* ptr) {
  NSScrollView* sv = (__bridge NSScrollView*)ptr;
  NSOutlineView* ov = outline_for_scroll(ptr);
  NAOutlineDelegate* delegate = outline_delegate_for(ptr);
  if (!sv || !ov || !delegate) {
    return;
  }
  // NSOutlineView refuses to remove its designated outline column, so a
  // full clear rebuilds the view instead. The data delegate (nodes,
  // expanded flags) is reused; cell texts belonged to the old columns.
  NSOutlineView* fresh =
      [[NSOutlineView alloc] initWithFrame:ov.frame];
  fresh.allowsMultipleSelection = ov.allowsMultipleSelection;
  fresh.allowsEmptySelection = YES;
  fresh.allowsColumnSelection = NO;
  fresh.indentationPerLevel = ov.indentationPerLevel;
  fresh.dataSource = delegate;
  fresh.delegate = delegate;
  fresh.target = delegate;
  fresh.doubleAction = @selector(doubleClick:);
  [fresh registerForDraggedTypes:@[ kOutlineKeyUTI, NSPasteboardTypeFileURL ]];
  objc_setAssociatedObject(fresh, "na_outline_delegate", delegate,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(sv, "na_outline_view", fresh,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  sv.documentView = fresh;
  delegate.ncols = 0;
  delegate.texts = [NSMutableDictionary dictionary];
  [delegate.colKinds removeAllObjects];
  [delegate.checks removeAllObjects];
  [delegate.images removeAllObjects];
  [delegate.rowHeights removeAllObjects];
  NSMutableDictionary<NSNumber*, NSDictionary*>* nodes =
      [NSMutableDictionary dictionary];
  for (NSNumber* key in delegate.nodes) {
    NSDictionary* entry = delegate.nodes[key];
    nodes[key] = @{@"parent": entry[@"parent"], @"expanded": @(NO)};
  }
  delegate.nodes = nodes;
}

int64_t na_outline_column_count(void* ptr) {
  NSOutlineView* ov = outline_for_scroll(ptr);
  return ov ? (int64_t)ov.tableColumns.count : 0;
}

void na_outline_set_column_width(void* ptr, int64_t col, double width) {
  NSOutlineView* ov = outline_for_scroll(ptr);
  if (!ov || col < 0 || col >= (int64_t)ov.tableColumns.count || width <= 0) {
    return;
  }
  ov.tableColumns[(NSUInteger)col].width = width;
}

void na_outline_set_nodes(void* ptr, const uint64_t* keys,
                          const uint64_t* parents, const bool* expanded,
                          int n) {
  NAOutlineDelegate* delegate = outline_delegate_for(ptr);
  NSOutlineView* ov = outline_for_scroll(ptr);
  if (!delegate || !ov || !keys || !parents || n < 0) {
    return;
  }
  NSMutableDictionary<NSNumber*, NSDictionary*>* nodes = [NSMutableDictionary dictionary];
  NSMutableDictionary<NSNumber*, NSMutableArray<NSNumber*>*>* children =
      [NSMutableDictionary dictionary];
  for (int i = 0; i < n; i++) {
    NSNumber* key = @(keys[i]);
    NSNumber* parent = @(parents[i]);
    BOOL exp = expanded ? (expanded[i] ? YES : NO) : NO;
    nodes[key] = @{@"parent": parent, @"expanded": @(exp)};
    NSMutableArray<NSNumber*>* kids = children[parent];
    if (!kids) {
      kids = [NSMutableArray array];
      children[parent] = kids;
    }
    [kids addObject:key];
  }
  delegate.nodes = nodes;
  delegate.children = children;
  // reloadData preserves expansion for equal items, so normalize first:
  // collapse everything, then restore exactly the flagged nodes.
  delegate.changeGuard = YES;
  [ov reloadData];
  for (int i = 0; i < n; i++) {
    [ov collapseItem:@(keys[i])];
  }
  for (int i = 0; i < n; i++) {
    if (expanded && expanded[i]) {
      [ov expandItem:@(keys[i]) expandChildren:NO];
    }
  }
  delegate.changeGuard = NO;
}

void na_outline_set_text(void* ptr, uint64_t key, int64_t col,
                         const char* text) {
  NAOutlineDelegate* delegate = outline_delegate_for(ptr);
  NSOutlineView* ov = outline_for_scroll(ptr);
  if (!delegate || !ov || col < 0) {
    return;
  }
  NSNumber* k = @(key);
  NSMutableArray<NSString*>* texts = delegate.texts[k];
  if (!texts) {
    texts = [NSMutableArray array];
    delegate.texts[k] = texts;
  }
  while ((int64_t)texts.count <= col) {
    [texts addObject:@""];
  }
  texts[(NSUInteger)col] =
      text ? [NSString stringWithUTF8String:text] : @"";
}

void na_outline_reload(void* ptr) {
  NSOutlineView* ov = outline_for_scroll(ptr);
  if (ov) {
    [ov reloadData];
  }
}

void na_outline_reload_key(void* ptr, uint64_t key, bool reloadChildren) {
  NSOutlineView* ov = outline_for_scroll(ptr);
  if (ov) {
    [ov reloadItem:@(key) reloadChildren:(reloadChildren ? YES : NO)];
  }
}

bool na_outline_is_expanded(void* ptr, uint64_t key) {
  NSOutlineView* ov = outline_for_scroll(ptr);
  return ov ? ([ov isItemExpanded:@(key)] ? true : false) : false;
}

void na_outline_set_expanded(void* ptr, uint64_t key, bool expanded) {
  NSOutlineView* ov = outline_for_scroll(ptr);
  NAOutlineDelegate* delegate = outline_delegate_for(ptr);
  if (!ov) {
    return;
  }
  if (delegate) {
    delegate.changeGuard = YES;
  }
  if (expanded) {
    [ov expandItem:@(key)];
  } else {
    [ov collapseItem:@(key)];
  }
  if (delegate) {
    delegate.changeGuard = NO;
  }
}

void na_outline_set_indent(void* ptr, double points) {
  NSOutlineView* ov = outline_for_scroll(ptr);
  if (ov && points >= 0) {
    ov.indentationPerLevel = points;
  }
}

int na_outline_selected_keys(void* ptr, uint64_t* out, int max) {
  NSOutlineView* ov = outline_for_scroll(ptr);
  if (!ov || !out || max <= 0) {
    return 0;
  }
  int n = 0;
  NSIndexSet* rows = ov.selectedRowIndexes;
  for (NSUInteger r = rows.firstIndex;
       r != NSNotFound && n < max;
       r = [rows indexGreaterThanIndex:r]) {
    id item = [ov itemAtRow:(NSInteger)r];
    if (item) {
      out[n++] = [(NSNumber*)item unsignedLongLongValue];
    }
  }
  return n;
}

void na_outline_select_keys(void* ptr, const uint64_t* keys, int n,
                            bool extend) {
  NSOutlineView* ov = outline_for_scroll(ptr);
  if (!ov || !keys || n <= 0) {
    return;
  }
  NSMutableIndexSet* set =
      extend ? [ov.selectedRowIndexes mutableCopy] : [NSMutableIndexSet indexSet];
  for (int i = 0; i < n; i++) {
    NSInteger row = [ov rowForItem:@(keys[i])];
    if (row >= 0) {
      [set addIndex:(NSUInteger)row];
    }
  }
  [ov selectRowIndexes:set byExtendingSelection:NO];
}

void na_outline_clear_selection(void* ptr) {
  NSOutlineView* ov = outline_for_scroll(ptr);
  if (ov) {
    [ov deselectAll:nil];
  }
}

void na_outline_scroll_to_key(void* ptr, uint64_t key) {
  NSOutlineView* ov = outline_for_scroll(ptr);
  if (!ov) {
    return;
  }
  NSInteger row = [ov rowForItem:@(key)];
  if (row >= 0) {
    [ov scrollRowToVisible:row];
  }
}
void na_outline_set_multi(void* ptr, bool multi) {
  NSOutlineView* ov = outline_for_scroll(ptr);
  if (ov) {
    ov.allowsMultipleSelection = multi ? YES : NO;
  }
}

void na_outline_set_has_more(void* ptr, uint64_t key, bool hasMore) {
  NAOutlineDelegate* delegate = outline_delegate_for(ptr);
  NSOutlineView* ov = outline_for_scroll(ptr);
  if (!delegate || !ov) {
    return;
  }
  if (!delegate.moreKeys) {
    delegate.moreKeys = [NSMutableSet set];
  }
  if (hasMore) {
    [delegate.moreKeys addObject:@(key)];
  } else {
    [delegate.moreKeys removeObject:@(key)];
  }
  // Expandability is cached per item; refresh it so the disclosure
  // triangle appears (or disappears) immediately.
  [ov reloadItem:@(key) reloadChildren:NO];
}

bool na_outline_has_more(void* ptr, uint64_t key) {
  NAOutlineDelegate* delegate = outline_delegate_for(ptr);
  return delegate ?
      ([delegate.moreKeys containsObject:@(key)] ? true : false) : false;
}

void na_outline_set_cell_checked(void* ptr, uint64_t key, int64_t col,
                                 bool checked) {
  NAOutlineDelegate* delegate = outline_delegate_for(ptr);
  NSOutlineView* ov = outline_for_scroll(ptr);
  if (!delegate || !ov) {
    return;
  }
  delegate.checks[outline_check_key(key, col)] = @(checked ? YES : NO);
  NSInteger row = [ov rowForItem:@(key)];
  if (row >= 0) {
    [ov reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row]
                 columnIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)col]];
  }
}

bool na_outline_is_cell_checked(void* ptr, uint64_t key, int64_t col) {
  NAOutlineDelegate* delegate = outline_delegate_for(ptr);
  if (!delegate) {
    return false;
  }
  NSNumber* v = delegate.checks[outline_check_key(key, col)];
  return v ? v.boolValue : false;
}

void na_outline_set_cell_image(void* ptr, uint64_t key, int64_t col,
                               int64_t image_handle) {
  NAOutlineDelegate* delegate = outline_delegate_for(ptr);
  NSOutlineView* ov = outline_for_scroll(ptr);
  if (!delegate || !ov) {
    return;
  }
  if (image_handle == 0) {
    [delegate.images removeObjectForKey:outline_check_key(key, col)];
  } else {
    NSImage* img = (__bridge NSImage*)na_image_native_ptr(image_handle);
    if (img) {
      delegate.images[outline_check_key(key, col)] = img;
    }
  }
  NSInteger row = [ov rowForItem:@(key)];
  if (row >= 0) {
    [ov reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row]
                 columnIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)col]];
  }
}

void na_outline_set_row_heights(void* ptr, const uint64_t* keys,
                                const double* heights, int n) {
  NAOutlineDelegate* delegate = outline_delegate_for(ptr);
  NSOutlineView* ov = outline_for_scroll(ptr);
  if (!delegate || !ov || !keys || !heights || n <= 0) {
    return;
  }
  for (int i = 0; i < n; i++) {
    if (heights[i] > 0) {
      delegate.rowHeights[@(keys[i])] = @(heights[i]);
    }
  }
  [ov reloadData];
}

void na_outline_clear_row_heights(void* ptr) {
  NAOutlineDelegate* delegate = outline_delegate_for(ptr);
  NSOutlineView* ov = outline_for_scroll(ptr);
  if (!delegate) {
    return;
  }
  [delegate.rowHeights removeAllObjects];
  if (ov) {
    [ov reloadData];
  }
}

void na_outline_set_row_height(void* ptr, double height) {
  NSOutlineView* ov = outline_for_scroll(ptr);
  if (ov && height > 0) {
    ov.rowHeight = height;
  }
}

const char* na_outline_get_text(void* ptr, uint64_t key, int64_t col) {
  static char outline_cell_buffer[8192];
  outline_cell_buffer[0] = '\0';
  NAOutlineDelegate* delegate = outline_delegate_for(ptr);
  if (!delegate || col < 0) {
    return outline_cell_buffer;
  }
  NSArray<NSString*>* texts = delegate.texts[@(key)];
  if (!texts || col >= (int64_t)texts.count) {
    return outline_cell_buffer;
  }
  const char* utf8 = texts[(NSUInteger)col].UTF8String;
  if (utf8) {
    strncpy(outline_cell_buffer, utf8, sizeof(outline_cell_buffer) - 1);
    outline_cell_buffer[sizeof(outline_cell_buffer) - 1] = '\0';
  }
  return outline_cell_buffer;
}

void na_outline_set_col_editable(void* ptr, int64_t col, bool editable) {
  NSOutlineView* ov = outline_for_scroll(ptr);
  if (!ov || col < 0 || col >= (int64_t)ov.tableColumns.count) {
    return;
  }
  ov.tableColumns[(NSUInteger)col].editable = editable ? YES : NO;
}

// Test hooks: drive the same emit paths a live interaction would take.
void na_outline_fire_select(uint32_t widget_id) {
  outline_emit(widget_id, 0, 0, 0);
}

void na_outline_fire_expand(uint32_t widget_id, uint64_t key) {
  outline_emit(widget_id, 1, key, 0);
}

void na_outline_fire_collapse(uint32_t widget_id, uint64_t key) {
  outline_emit(widget_id, 2, key, 0);
}

void na_outline_fire_activate(uint32_t widget_id) {
  outline_emit(widget_id, 3, 0, 0);
}

void na_outline_fire_check(uint32_t widget_id, uint64_t key, int64_t col) {
  outline_emit(widget_id, 4, key, col);
}

void na_outline_fire_edit(uint32_t widget_id, uint64_t key, int64_t col) {
  outline_emit(widget_id, 5, key, col);
}

// --- Drag & drop state -----------------------------------------------------

void na_outline_set_accepts_moves(void* ptr, bool accept) {
  NAOutlineDelegate* delegate = outline_delegate_for(ptr);
  if (delegate) {
    delegate.acceptsMoves = accept ? YES : NO;
  }
}

bool na_outline_accepts_moves(void* ptr) {
  NAOutlineDelegate* delegate = outline_delegate_for(ptr);
  return delegate ? (delegate.acceptsMoves ? true : false) : false;
}

void na_outline_set_accepts_files(void* ptr, bool accept) {
  NAOutlineDelegate* delegate = outline_delegate_for(ptr);
  if (delegate) {
    delegate.acceptsFiles = accept ? YES : NO;
  }
}

bool na_outline_accepts_files(void* ptr) {
  NAOutlineDelegate* delegate = outline_delegate_for(ptr);
  return delegate ? (delegate.acceptsFiles ? true : false) : false;
}

int na_outline_drop_keys(void* ptr, uint64_t* out, int max) {
  NAOutlineDelegate* delegate = outline_delegate_for(ptr);
  if (!delegate || !out || max <= 0) {
    return 0;
  }
  int n = 0;
  for (NSNumber* key in delegate.pendingDropKeys) {
    if (n >= max) {
      break;
    }
    out[n++] = key.unsignedLongLongValue;
  }
  return n;
}

int na_outline_drop_files(void* ptr, char* buf, int maxLen) {
  NAOutlineDelegate* delegate = outline_delegate_for(ptr);
  if (!delegate || !buf || maxLen <= 0) {
    return 0;
  }
  buf[0] = '\0';
  NSString* joined =
      [delegate.pendingDropFiles componentsJoinedByString:@"\n"];
  if (!joined) {
    return 0;
  }
  const char* utf8 = joined.UTF8String;
  if (utf8) {
    strncpy(buf, utf8, (size_t)(maxLen - 1));
    buf[maxLen - 1] = '\0';
  }
  return (int)delegate.pendingDropFiles.count;
}

void na_outline_fire_move(uint32_t widget_id, void* ptr, uint64_t parent,
                          int64_t index, const uint64_t* keys, int n) {
  NAOutlineDelegate* delegate = outline_delegate_for(ptr);
  if (delegate) {
    NSMutableArray<NSNumber*>* list = [NSMutableArray array];
    if (keys) {
      for (int i = 0; i < n; i++) {
        [list addObject:@(keys[i])];
      }
    }
    delegate.pendingDropKeys = list;
  }
  outline_emit(widget_id, 6, parent, index);
}

void na_outline_fire_filedrop(uint32_t widget_id, void* ptr, uint64_t parent,
                              int64_t index, const char** paths, int n) {
  NAOutlineDelegate* delegate = outline_delegate_for(ptr);
  if (delegate) {
    NSMutableArray<NSString*>* list = [NSMutableArray array];
    if (paths) {
      for (int i = 0; i < n; i++) {
        if (paths[i]) {
          [list addObject:[NSString stringWithUTF8String:paths[i]]];
        }
      }
    }
    delegate.pendingDropFiles = list;
  }
  outline_emit(widget_id, 7, parent, index);
}
