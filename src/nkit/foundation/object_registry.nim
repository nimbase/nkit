import std/[locks, tables]

type ObjectRegistry*[TObject] = ref object
  lock: Lock
  objects: Table[uint32, TObject]

proc newObjectRegistry*[TObject](): ObjectRegistry[TObject] =
  new(result)
  initLock(result.lock)

proc add*[TObject](reg: ObjectRegistry[TObject], id: uint32, obj: TObject) =
  reg.lock.acquire()
  reg.objects[id] = obj
  reg.lock.release()

proc get*[TObject](reg: ObjectRegistry[TObject], id: uint32): TObject =
  reg.lock.acquire()
  if id in reg.objects:
    result = reg.objects[id]
  reg.lock.release()

proc contains*[TObject](reg: ObjectRegistry[TObject], id: uint32): bool =
  reg.lock.acquire()
  result = id in reg.objects
  reg.lock.release()

proc getAll*[TObject](reg: ObjectRegistry[TObject]): seq[TObject] =
  reg.lock.acquire()
  result = newSeq[TObject](reg.objects.len)
  var i = 0
  for v in reg.objects.values():
    result[i] = v
    inc i
  reg.lock.release()

proc remove*[TObject](reg: ObjectRegistry[TObject], id: uint32): bool =
  reg.lock.acquire()
  if id in reg.objects:
    reg.objects.del(id)
    result = true
  reg.lock.release()

proc clear*[TObject](reg: ObjectRegistry[TObject]) =
  reg.lock.acquire()
  reg.objects.clear()
  reg.lock.release()

proc len*[TObject](reg: ObjectRegistry[TObject]): int =
  reg.lock.acquire()
  result = reg.objects.len
  reg.lock.release()
