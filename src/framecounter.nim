import std/[monotimes, times]
export times

type
  OneShot* = ref object
    body*: proc() {.closure.}
    frame*: uint
    target*: uint

  MultiShot* = ref object
    body*: proc() {.closure.}
    target*: uint

  FrameCounter* = ref object
    frame*: uint
    frameProcs*: seq[MultiShot]
    oneShots*: seq[OneShot]
    last*: MonoTime
    fps*: int

proc frameTime*(frames: int): int =
  # Calculate frames per second.
  ((1 / frames) * 1000).int

template ControlFlow*(f: var FrameCounter) =
  if (getMonoTime() - f.last).inMilliseconds < frameTime(f.fps):
    return

proc tick*(f: var FrameCounter, controlFlow: bool = true) =
  if controlFlow:
    f.ControlFlow()

  # MultiShots - every
  for ms in f.frameProcs:
    if f.frame mod ms.target == 0:
      ms.body()

  # OneShots - after
  var c = 0
  for i in 0..f.oneShots.high:
    var osh = f.oneShots[c]
    if osh.frame >= osh.target:
      f.oneShots[c].body()
      f.oneShots.del(c)
    else:
      f.oneShots[c].frame += 1
      c += 1

  if f.frame.int > int.high - 2:
    f.frame = 1
  else:
    f.frame += 1
  f.last = getMonoTime()

proc after*(frames: int, body: proc() {.closure.}): OneShot =
  OneShot(
    target: frames.uint,
    frame: 1,
    body: body
  )

proc every*(frames: int, body: proc() {.closure.}): MultiShot =
  MultiShot(
    target: frames.uint,
    body: body
  )

proc run*(f: var FrameCounter, a: OneShot) =
  f.oneShots.add a

proc run*(f: var FrameCounter, e: MultiShot) =
  f.frameProcs.add e

proc newFrameCounter*(fps: int): FrameCounter =
  var f: FrameCounter
  f.new()
  f.fps = fps
  f.frame = 0.uint
  f.frameProcs = newSeq[MultiShot]()
  f.oneShots = newSeq[OneShot]()
  f.last = getMonoTime()
  return f

if isMainModule:
  type 
    Cat = ref object
      name: string

  var scrubs = Cat(name: "Scrubs")
  var clock = FrameCounter(fps: 60)
  
  clock.run after(60) do():
    scrubs.name = "bobby"
    echo "name changed"

  var c = 0
  clock.run every(30) do():
    if c == 10:
      quit(QuitSuccess)
    c += 1
    echo c
    echo scrubs.name
    echo ""

  while true:
    clock.tick()
