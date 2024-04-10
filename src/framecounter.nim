import std/[monotimes, times]

export times

type
  OneShot*[T] = ref object
    body*: proc(thing: var T)
    frame*: uint
    target*: uint
    thing*: T

  MultiShot*[T] = ref object
    body*: proc(thing: var T)
    target*: uint
    thing*: T

  FrameCounter*[T] = ref object
    frame*: uint
    frameProcs*: seq[MultiShot[T]]
    oneShots*: seq[OneShot[T]]
    last*: MonoTime
    fps*: int

proc fps*(frames: int, dt: float32 = 0f32): int =
  # Calculate frames per second.
  (((1 / frames) - dt) * 1000).int

template ControlFlow*(f: var FrameCounter, dt: float32) =
  if (getMonoTime() - f.last).inMilliseconds < fps(f.fps, dt):
    return

proc tick*(f: var FrameCounter, dt: float32, controlFlow: bool = true) =
  if controlFlow:
    f.ControlFlow(dt)

  # MultiShots - every
  for ms in f.frameProcs:
    if f.frame mod ms.target == 0:
      ms.body(ms.thing)

  # OneShots - after
  for i in 0..f.oneShots.high:
    var osh = f.oneShots.pop()
    if osh.frame > osh.target:
      osh.body(osh.thing)
    else:
      osh.frame += 1
      f.oneShots.insert(osh, 0)

  f.frame += 1
  f.last = getMonoTime()

proc after*[T](thing: var T, frames: int, body: proc(thing: var T)): OneShot[T] =
  OneShot[T](
    target: frames.uint,
    frame: 0,
    body: body,
    thing: thing
  )

proc every*[T](thing: var T, frames: int, body: proc(thing: var T)): MultiShot[T] =
  MultiShot[T](
    target: frames.uint,
    body: body,
    thing: thing
  )

proc run*(f: var FrameCounter, a: OneShot) =
  f.oneShots.add a

proc run*(f: var FrameCounter, e: MultiShot) =
  f.frameProcs.add e

if isMainModule:
  type 
    Cat = ref object
      name: string
      clock: FrameCounter[Cat]

  var scrubs = Cat(name: "Scrubs")
  var fc = FrameCounter[scrubs](fps: 60)
  
  fc.run scrubs.after(1) do(c: var Cat):
    c.name = "bobby"

  echo scrubs.name
  var c = 0
  fc.run scrubs.every(30) do(sc: var Cat):
    echo "repeating"
    if c == 10:
      quit(QuitSuccess)
    c += 1
    echo c
    echo scrubs.name

  var delta: float32 = 0.0
  while true:
    fc.tick(delta)
