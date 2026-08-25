import std/[atomics, locks, os]
import event, dispatcher

export dispatcher

type ListenerId* = int

type
  RecLock = object
    inner: Lock
    owner: int
    depth: int

proc acquire(l: var RecLock) =
  let tid = getThreadId().int
  while true:
    l.inner.acquire()
    if l.depth == 0 or l.owner == tid:
      l.owner = tid
      inc l.depth
      l.inner.release()
      return
    l.inner.release()
    os.sleep(0)

proc release(l: var RecLock) =
  l.inner.acquire()
  if l.owner == getThreadId().int and l.depth > 0:
    dec l.depth
    if l.depth == 0:
      l.owner = 0
  l.inner.release()

type
  ListenerRecord = ref object
    id: int
    typeIdent: int
    matches: proc(e: Event): bool {.closure.}
    invoke: proc(e: Event) {.closure.}
    removed: Atomic[bool]

  DispatchGuard = ref object
    lock: Lock
    alive: bool

  EventEmitter*[BaseEventType] = ref object of RootObj
    listenersLock: Lock
    listeners: seq[ListenerRecord]
    transitionLock: RecLock
    listeningActive: bool
    guard: DispatchGuard
    nextListenerId: Atomic[int]
    onStartListening*: proc() {.closure.}
    onStopListening*: proc() {.closure.}

var nextTypeId: Atomic[int]

proc typeIdOf*[E](t: typedesc[E]): int =
  var ident {.global.}: Atomic[int]
  var expected = ident.load()
  while expected == 0:
    let fresh = nextTypeId.fetchAdd(1) + 1
    if ident.compareExchange(expected, fresh):
      return fresh
  result = ident.load()

proc initEmitter*[B](em: EventEmitter[B]) =
  initLock(em.listenersLock)
  initLock(em.transitionLock.inner)
  em.guard = DispatchGuard()
  initLock(em.guard.lock)
  em.guard.alive = true

proc updateListeningState[B](em: EventEmitter[B], shouldListen: bool) =
  em.transitionLock.acquire()
  if shouldListen != em.listeningActive:
    em.listeningActive = shouldListen
    if shouldListen:
      if em.onStartListening != nil:
        em.onStartListening()
    else:
      if em.onStopListening != nil:
        em.onStopListening()
  em.transitionLock.release()

proc addListener*[B; E: B](em: EventEmitter[B], callback: proc(e: E)): ListenerId =
  let rec = ListenerRecord(
    id: em.nextListenerId.fetchAdd(1) + 1,
    typeIdent: typeIdOf(E),
    matches: proc(e: Event): bool = e of E,
    invoke: proc(e: Event) = callback(E(e)))
  rec.removed.store(false)
  var wasEmpty: bool
  em.listenersLock.acquire()
  wasEmpty = em.listeners.len == 0
  em.listeners.add(rec)
  em.listenersLock.release()
  if wasEmpty:
    updateListeningState(em, true)
  result = rec.id

proc removeListener*[B](em: EventEmitter[B], listenerId: ListenerId): bool =
  var becameEmpty = false
  em.listenersLock.acquire()
  var idx = -1
  for i, rec in em.listeners:
    if rec.id == listenerId:
      idx = i
      break
  if idx >= 0:
    em.listeners[idx].removed.store(true)
    em.listeners.delete(idx)
    becameEmpty = em.listeners.len == 0
  em.listenersLock.release()
  if becameEmpty:
    updateListeningState(em, false)
  result = idx >= 0

proc removeAllListenersImpl[B](em: EventEmitter[B], typeFilter: int) =
  var removedAny = false
  var becameEmpty = false
  em.listenersLock.acquire()
  var kept = newSeq[ListenerRecord]()
  for rec in em.listeners:
    if typeFilter < 0 or rec.typeIdent == typeFilter:
      rec.removed.store(true)
      removedAny = true
    else:
      kept.add(rec)
  em.listeners = kept
  becameEmpty = removedAny and em.listeners.len == 0
  em.listenersLock.release()
  if becameEmpty:
    updateListeningState(em, false)

proc removeAllListeners*[E: Event; B](em: EventEmitter[B], eventType: typedesc[E]) =
  removeAllListenersImpl(em, typeIdOf(eventType))

proc clearListeners*[B](em: EventEmitter[B]) =
  removeAllListenersImpl(em, -1)

proc totalListenerCount*[B](em: EventEmitter[B]): int =
  em.listenersLock.acquire()
  result = em.listeners.len
  em.listenersLock.release()

proc listenerCount*[E: Event; B](em: EventEmitter[B], eventType: typedesc[E]): int =
  let wanted = typeIdOf(eventType)
  em.listenersLock.acquire()
  for rec in em.listeners:
    if rec.typeIdent == wanted:
      inc result
  em.listenersLock.release()

proc hasListeners*[E: Event; B](em: EventEmitter[B], eventType: typedesc[E]): bool =
  let wanted = typeIdOf(eventType)
  em.listenersLock.acquire()
  for rec in em.listeners:
    if rec.typeIdent == wanted:
      em.listenersLock.release()
      return true
  em.listenersLock.release()
  false

proc emit*[B](em: EventEmitter[B], event: B) =
  em.listenersLock.acquire()
  let snapshot = em.listeners
  em.listenersLock.release()
  for rec in snapshot:
    if not rec.removed.load() and rec.matches(event):
      rec.invoke(event)

proc emitAsync*[B](em: EventEmitter[B], event: B) =
  let guard = em.guard
  let queued = runOnMainThread(proc() =
    guard.lock.acquire()
    let ok = guard.alive
    guard.lock.release()
    if ok:
      emit(em, event))
  if not queued:
    emit(em, event)

proc shutdownEmitter*[B](em: EventEmitter[B]) =
  em.guard.lock.acquire()
  em.guard.alive = false
  em.guard.lock.release()
  clearListeners(em)
