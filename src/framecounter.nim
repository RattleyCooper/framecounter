import std/[monotimes, times]

export times

type
  OneShot* = ref object
    body*: proc()
    frame*: uint
    target*: uint

  MultiShot* = ref object
    body*: proc()
    target*: uint

  FrameCounter* = object
    frame*: uint
    frameProcs*: seq[MultiShot]
    oneShots*: seq[OneShot]
    last*: MonoTime
    fps*: int

proc fps*(frames: int, dt: float32 = 0f32): int =
  # Calculate frames per second.
  (((1 / frames) - dt) * 1000).int

template ControlFlow*(f: var FrameCounter, dt: float32) =
  if (getMonoTime() - f.last).inMilliseconds < fps(f.fps, dt):
    return

proc tick*(f: var FrameCounter) =
  # MultiShots - every
  for ms in f.frameProcs:
    if f.frame mod ms.target == 0:
      ms.body()

  # OneShots - after
  for i in 0..f.oneShots.high:
    var osh = f.oneShots.pop()
    if osh.frame > osh.target:
      osh.body()
    else:
      osh.frame += 1
      f.oneShots.insert(osh, 0)

  f.frame += 1
  f.last = getMonoTime()

proc after*(frames: int, body: proc()): OneShot =
  OneShot(
    target: frames.uint,
    frame: 0,
    body: body
  )

proc every*(frames: int, body: proc()): MultiShot =
  MultiShot(
    target: frames.uint,
    body: body
  )

proc run*(f: var FrameCounter, a: OneShot) =
  f.oneShots.add a

proc run*(f: var FrameCounter, e: MultiShot) =
  f.frameProcs.add e

if isMainModule:
  var fc = FrameCounter(fps: 60)
  fc.run after(100) do():
    echo "hello"

  var c = 0
  fc.run every(30) do():
    echo "repeating"
    if c == 10:
      quit(QuitSuccess)
    c += 1
    echo c

  while true:
    fc.tick()
