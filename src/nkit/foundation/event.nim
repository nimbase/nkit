import std/monotimes

type
  Event* = ref object of RootObj
    timestamp*: MonoTime

method typeName*(e: Event): string {.base.} =
  "Event"

proc stamp*[T: Event](e: T): T {.inline.} =
  e.timestamp = getMonoTime()
  e
