#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdlib.h>

typedef void (*na_task_fn)(void* ctx);

bool na_is_main_thread(void) {
  return [NSThread isMainThread];
}

typedef struct {
  na_task_fn fn;
  void* ctx;
} NaTaskPair;

static void task_pair_trampoline(void* opaque) {
  NaTaskPair* pair = (NaTaskPair*)opaque;
  if (pair) {
    na_task_fn fn = pair->fn;
    void* ctx = pair->ctx;
    free(pair);
    if (fn) {
      fn(ctx);
    }
  }
}

void na_dispatch_main(na_task_fn fn, void* ctx) {
  NaTaskPair* pair = (NaTaskPair*)malloc(sizeof(NaTaskPair));
  pair->fn = fn;
  pair->ctx = ctx;
  dispatch_async_f(dispatch_get_main_queue(), pair, task_pair_trampoline);
}

void na_dispatch_main_after(int delay_ms, na_task_fn fn, void* ctx) {
  NaTaskPair* pair = (NaTaskPair*)malloc(sizeof(NaTaskPair));
  pair->fn = fn;
  pair->ctx = ctx;
  dispatch_time_t when =
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)delay_ms * NSEC_PER_MSEC);
  dispatch_after_f(when, dispatch_get_main_queue(), pair,
                   task_pair_trampoline);
}

bool na_run_main_loop_for(int timeout_ms) {
  CFRunLoopRunInMode(kCFRunLoopDefaultMode, timeout_ms / 1000.0, false);
  return true;
}
