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
      age: int
  
  proc newCat(name: string): Cat =
    # Create a new cat.
    result.new()
    result.name = name
    result.age = 1

  var clock = FrameCounter(fps: 60)
  var scrubs = newCat("Scrubs")
  var frank = newCat("Frank")

  # Closure will capture `c`, `scrubs`, and `frank`, 
  # for use in the closure.
  # At 60fps, every(60) means this runs once per second.
  var c = 0
  clock.run every(60) do():
    if c == 10:
      quit(QuitSuccess)
    c += 1
    echo "C: ", c
    echo scrubs.age
    echo scrubs.name
    echo frank.age
    echo frank.name
    echo ""


  proc doStuff(cat: Cat) =
    # Create a closure inside a proc for scheduling code
    # on multiple objects.
    clock.run every(60) do():
      cat.age += 1
    # After 3 seconds (180 frames at 60fps), rename the cat
    clock.run after(180) do():
      cat.name = "Mr. " & cat.name
      echo cat.name, " got a new name!"

  scrubs.doStuff()
  frank.doStuff()

  while true:
    clock.tick()
  
