#import "gui_common.h"

typedef void (*na_hover_router_event_fn)(uint32_t widget_id, void* ctx);

static void* g_hover_router_dummy = (void*)0x1;

void* na_hover_router_create(uint32_t widget_id) {
  (void)widget_id;
  return g_hover_router_dummy;
}

void na_hover_router_free(uint32_t widget_id, void* ptr) {
  (void)widget_id;
  (void)ptr;
}

void na_hover_router_set_enter(uint32_t widget_id, na_hover_router_event_fn fn,
                               void* ctx) {
  (void)widget_id;
  (void)fn;
  (void)ctx;
}

void na_hover_router_set_leave(uint32_t widget_id, na_hover_router_event_fn fn,
                               void* ctx) {
  (void)widget_id;
  (void)fn;
  (void)ctx;
}
