import std/[locks, os, times]

type
  MainThreadDispatchFn* = proc(fn: proc()) {.closure.}
  MainThreadPredicateFn* = proc(): bool {.closure.}

type
  WorkItem* = proc()

var
  customDispatch: MainThreadDispatchFn
  customPredicate: MainThreadPredicateFn
  customLoopRunner: proc(timeoutMs: int): bool {.closure.}
  queueLock: Lock
  pending: seq[WorkItem]
  mainThreadId: int
  mainThreadKnown = false

proc initDispatcher() =
  var initialized {.global.} = false
  if not initialized:
    initialized = true
    queueLock.initLock()

proc isMainThread*(): bool =
  initDispatcher()
  if customPredicate != nil:
    return customPredicate()
  let tid = getThreadId().int
  if not mainThreadKnown:
    mainThreadId = tid
    mainThreadKnown = true
  tid == mainThreadId

proc setMainThread*() =
  initDispatcher()
  let tid = getThreadId().int
  if not mainThreadKnown or mainThreadId != tid:
    mainThreadId = tid
    mainThreadKnown = true

proc isMainThreadDispatchSupported*(): bool =
  true

proc runOnMainThread*(fn: proc()): bool =
  if fn.isNil:
    return true
  initDispatcher()
  if customDispatch != nil:
    customDispatch(fn)
    return true
  queueLock.acquire()
  pending.add(fn)
  queueLock.release()
  true

proc epochMillis(): int64 {.inline.} =
  int64(epochTime() * 1000)

proc popPending(): proc() =
  queueLock.acquire()
  if pending.len > 0:
    result = pending[0]
    pending.delete(0)
  queueLock.release()

proc runMainThreadLoopFor*(timeoutMs: int): bool =
  initDispatcher()
  if customLoopRunner != nil:
    return customLoopRunner(timeoutMs)
  let deadline = epochMillis() + timeoutMs
  while true:
    let fn = popPending()
    if fn != nil:
      fn()
      continue
    let remaining = deadline - epochMillis()
    if remaining <= 0:
      return true
    sleep(int(min(remaining, 5)))

proc setMainThreadDispatcher*(dispatch: MainThreadDispatchFn, predicate: MainThreadPredicateFn) =
  initDispatcher()
  customDispatch = dispatch
  customPredicate = predicate

proc setMainThreadLoopRunner*(runner: proc(timeoutMs: int): bool {.closure.}) =
  initDispatcher()
  customLoopRunner = runner

proc drainMainThreadQueue*() =
  while true:
    let fn = popPending()
    if fn.isNil:
      return
    fn()
