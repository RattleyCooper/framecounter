import macros


type
  OneShot* = object
    procd*: proc()
    frame*: int
    target*: int

  FrameCounter* = object
    frame*: int
    frameProcs*: seq[proc()]
    oneShots*: seq[OneShot]

  RunKind* = enum
    rEvery, rAfter

proc tick*(f: var FrameCounter) =
  for pr in f.frameProcs:
    pr()
  for i in 0..f.oneShots.high:
    var osh = f.oneShots.pop()
    if osh.frame > osh.target:
      osh.procd()
    else:
      osh.frame += 1
      f.oneShots.insert(osh, 0)

  f.frame += 1
  if f.frame mod 60 == 0:
    f.frame = 1

macro run*(f: FrameCounter, rk: static[RunKind], frames: int, body: untyped): untyped =
  # Create callbacks to run after/every frames.
  if rk == rEvery:
    result = quote do:
      `f`.frameProcs.add do():
        if `f`.frame mod `frames` == 0:
          `body`
  elif rk == rAfter:
    result = quote do:
      let theProc = proc() =
        `body`
      `f`.oneShots.add OneShot(
        frame: 0, target: `frames`,
        procd: theProc
      )

proc fps*(frames: int, dt: float32 = 0f32): int =
  # Calculate frames per second.
  (((1 / frames) - dt) * 1000).int
