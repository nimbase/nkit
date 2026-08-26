import std/[monotimes, times, math]
import nkit/gui/view
import nkit/foundation/dispatcher
when defined(ios):
  import nkit/platform/ios/dispatcher_ios
elif defined(macosx):
  import nkit/platform/macos/dispatcher_macos
import nkit/foundation/geometry

export view, geometry

type Easing* = proc(t: float64): float64 {.closure.}

proc linear*(t: float64): float64 = t

proc easeInOut*(t: float64): float64 =
  if t < 0.5:
    2.0 * t * t
  else:
    1.0 - 2.0 * (1.0 - t) * (1.0 - t)

proc easeOut*(t: float64): float64 =
  1.0 - (1.0 - t) * (1.0 - t)

const frameIntervalMs = 16  # ~60 fps

proc animate*(durationMs: int, easing: Easing,
              onUpdate: proc(progress: float64)) =
  ## Drives `onUpdate` with eased progress in [0, 1] on the main thread.
  let started = getMonoTime()
  let duration = max(durationMs, 1)
  proc tick() =
    let elapsed = inMilliseconds(getMonoTime() - started).int
    let raw = min(elapsed.float64 / duration.float64, 1.0)
    let progress = if easing != nil: easing(raw) else: raw
    onUpdate(progress)
    if raw < 1.0:
      dispatchAfterMain(frameIntervalMs) do ():
        tick()
  tick()

proc animate*(v: View, durationMs: int, easing: Easing,
              onUpdate: proc(v: View, progress: float64)) =
  animate(durationMs, easing, proc(progress: float64) =
    onUpdate(v, progress))

proc fadeIn*(v: View, durationMs = 220) =
  v.setAlpha(0.0)
  animate(v, durationMs, easeOut, proc(v: View, p: float64) =
    v.setAlpha(p))

proc fadeOut*(v: View, durationMs = 220) =
  animate(v, durationMs, easeOut, proc(v: View, p: float64) =
    v.setAlpha(1.0 - p))

proc moveTo*(v: View, x, y: float64, durationMs = 220,
             easing: Easing = easeInOut) =
  ## Slides a view's frame origin to (x, y), keeping its size.
  let startFrame = v.getFrameRect()
  animate(v, durationMs, easing, proc(v: View, p: float64) =
    let nx = startFrame.x + (x - startFrame.x) * p
    let ny = startFrame.y + (y - startFrame.y) * p
    v.setFrameRect(rectangle(nx, ny, startFrame.width, startFrame.height)))

proc resizeTo*(v: View, width, height: float64, durationMs = 220,
               easing: Easing = easeInOut) =
  let startFrame = v.getFrameRect()
  animate(v, durationMs, easing, proc(v: View, p: float64) =
    let nw = startFrame.width + (width - startFrame.width) * p
    let nh = startFrame.height + (height - startFrame.height) * p
    v.setFrameRect(rectangle(startFrame.x, startFrame.y, nw, nh)))
