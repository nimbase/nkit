import std/[locks, tables]
import ../../foundation/dispatcher
import uifunctions

type TaskRef = ref object
  fn: proc()

var
  tasksLock: Lock
  pendingTasks: Table[pointer, TaskRef]

proc initTaskTable() =
  var initialized {.global.} = false
  if not initialized:
    initialized = true
    tasksLock.initLock()

proc taskThunk(userData: pointer) {.cdecl.} =
  initTaskTable()
  var task: TaskRef = nil
  tasksLock.acquire()
  if userData in pendingTasks:
    task = pendingTasks[userData]
    pendingTasks.del(userData)
  tasksLock.release()
  if not task.isNil:
    task.fn()

proc dispatchImpl(fn: proc()) =
  if fn.isNil:
    return
  initTaskTable()
  let task = TaskRef(fn: fn)
  let key = cast[pointer](task)
  tasksLock.acquire()
  pendingTasks[key] = task
  tasksLock.release()
  naDispatchMain(taskThunk, key)

proc predicateImpl(): bool =
  naIsMainThread()

proc loopRunnerImpl(timeoutMs: int): bool =
  naRunLoopFor(cint(timeoutMs))

initTaskTable()
setMainThreadDispatcher(dispatchImpl, predicateImpl)
setMainThreadLoopRunner(loopRunnerImpl)

proc ensurePlatformDispatcher*() =
  discard

proc dispatchAfterMain*(delayMs: int, fn: proc()) =
  if fn.isNil:
    return
  initTaskTable()
  let task = TaskRef(fn: fn)
  let key = cast[pointer](task)
  tasksLock.acquire()
  pendingTasks[key] = task
  tasksLock.release()
  naDispatchMainAfter(cint(delayMs), taskThunk, key)
