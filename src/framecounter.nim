import std/[monotimes, times]
export times

type
  OneShot* = ref object
    id*: int
    body*: proc() {.closure.}
    frame*: uint
    target*: uint

  MultiShot* = ref object
    id*: int
    body*: proc() {.closure.}
    target*: uint

  FrameCounter* = ref object
    nextId*: int
    frame*: uint
    frameProcs*: seq[MultiShot]
    oneShots*: seq[OneShot]
    last*: MonoTime
    fps*: int

proc clear*(framecounter: FrameCounter) =
  # Clear the closures from the framecounter.
  framecounter.frameProcs.setLen(0)
  framecounter.oneShots.setLen(0)

proc genId*(framecounter: FrameCounter): int =
  # Create an id for the next registered closure.
  result = framecounter.nextId
  inc framecounter.nextId

proc frameTime*(frames: int): int =
  # Calculate frames per second.
  ((1 / frames) * 1000).int

template ControlFlow*(f: FrameCounter) =
  if (getMonoTime() - f.last).inMilliseconds < frameTime(f.fps):
    return

proc tick*(f: FrameCounter, controlFlow: bool = true) =
  if controlFlow:
    f.ControlFlow()

  # MultiShots - every
  for i in 0..f.frameProcs.high: # maintain execution order
    if i > f.frameProcs.high:
      break
    if f.frame mod f.frameProcs[i].target == 0 and f.frame != 0:
      f.frameProcs[i].body()

  # OneShots - after
  var c = 0
  for i in 0..f.oneShots.high: # maintain execution order
    if c > f.oneShots.high:
      break
    var osh = f.oneShots[c]
    if osh.frame mod osh.target == 0 and osh.frame != 0:
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
    frame: 0,
    body: body
  )

proc every*(frames: int, body: proc() {.closure.}): MultiShot =
  MultiShot(
    target: frames.uint,
    body: body
  )

proc run*(f: FrameCounter, a: OneShot) =
  a.id = f.genId()
  f.oneShots.add a

proc run*(f: FrameCounter, e: MultiShot) =
  e.id = f.genId()
  f.frameProcs.add e

proc schedule*(f: FrameCounter, a: OneShot): int =
  # Same as run, but returns the id you can use to cancel the closure.
  a.id = f.genId()
  f.oneShots.add a
  a.id

proc schedule*(f: FrameCounter, e: MultiShot): int =
  # Same as run, but returns the id you can use to cancel the closure.
  e.id = f.genId()
  f.frameProcs.add e
  e.id

proc cancel*(f: FrameCounter, id: int) =
  # Removes closures from the framecounter.
  # Remove from OneShots
  for i in countdown(f.oneShots.high, 0):
    if f.oneShots[i].id == id:
      f.oneShots.del(i)
      return
  # Remove from MultiShots
  for i in countdown(f.frameProcs.high, 0):
    if f.frameProcs[i].id == id:
      f.frameProcs.del(i)
      return

proc cancel*(f: FrameCounter, ids: var seq[int]) =
  ## Batch cancellation. Removes all tasks in the list and clears the list.
  ## Usage: clock.cancel(player.tasks)
  for i in countdown(ids.high, 0):
    f.cancel(ids[i])
  ids.setLen(0)

proc watch*(f: FrameCounter, cond: proc(): bool {.closure.}, m: MultiShot): int =
  var triggered = false
  let id = f.nextId
  f.run every(1) do():
    if cond() and not triggered:
      m.id = f.genId()
      f.frameProcs.add m
      triggered = true
    elif not cond() and triggered:
      f.cancel(m.id)
      triggered = false
  id

proc watch*(f: FrameCounter, cond: proc(): bool {.closure.}, o: OneShot): int =
  var triggered = false
  let id = f.nextId
  f.run every(1) do():
    if cond() and not triggered:
      o.id = f.genId()
      f.oneShots.add o
      triggered = true
    elif not cond() and triggered:
      f.cancel(o.id)
      triggered = false
  id

template watch*(f: FrameCounter, cond: untyped, m: MultiShot): untyped =
  # Waits until condition is true before scheduling multishot. Cancels
  # multishot if the condition isn't true before multishot is called.
  var triggered = false
  f.run every(1) do():
    if (`cond`) and not triggered:
      m.id = f.genId()
      f.frameProcs.add m
      triggered = true
    elif not (`cond`) and triggered:
      f.cancel(m.id)
      triggered = false

template watch*(f: FrameCounter, cond: untyped, o: OneShot): untyped =
  # Waits until condition is true before scheduling oneshot. Cancels 
  # oneshot if the condition isn't true before the oneshot is 
  # called.
  var triggered = false
  f.run every(1) do():
    if (`cond`) and not triggered:
      o.id = f.genId()
      f.oneShots.add o
      triggered = true
    elif not (`cond`) and triggered:
      f.cancel(o.id)
      triggered = false

proc `when`*(f: FrameCounter, cond: proc(): bool {.closure.}, m: MultiShot) =
  # Triggers multishot when the proc evaluates to true. Multishot persists
  # unless canceled explicitly.  
  let id = f.nextId
  f.run every(1) do():
    if cond():
      m.id = f.genId()
      f.frameProcs.add m
      f.cancel(id)

proc `when`*(f: FrameCounter, cond: proc(): bool {.closure.}, o: OneShot) =
  # Triggers oneshot when the proc evaluates to true. Since oneshots terminate
  # themselves, no canceling is required.
  let id = f.nextId
  f.run every(1) do():
    if cond():
      o.id = f.genId()
      f.oneShots.add o
      f.cancel(id)

template `when`*(f: FrameCounter, cond: untyped, m: MultiShot): untyped =
  # Triggers multishot when the condition is met. Multishot persists
  # unless canceled explicitly.
  let id = f.nextId
  f.run every(1) do():
    if (`cond`):
      m.id = f.genId()
      f.frameProcs.add m
      f.cancel(id)

template `when`*(f: FrameCounter, cond: untyped, o: OneShot): untyped =
  # Triggers oneshot when the condition is met. Since oneshots terminate
  # themselves, no canceling is required.
  let id = f.nextId
  f.run every(1) do():
    if (`cond`):
      o.id = f.genId()
      f.oneShots.add o
      f.cancel(id)

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
  var clock = FrameCounter(fps:60)

  type 
    Cat = ref object
      name: string
      age: int
      tasks: seq[int] # Our bag of tasks
  
  proc newCat(name: string): Cat =
    # Create a new cat.
    result.new()
    result.name = name
    result.age = 1

  # var clock = FrameCounter(fps: 60)
  var scrubs = newCat("Scrubs")
  var shadow = newCat("Shadow")

  # Closure will capture `c`, `scrubs`, and `shadow`, for use in the closure.
  # At 60fps, every(60) means this runs once per second.
  var c = 0
  clock.run every(60) do():
    if c == 5:
      # Cancel scrubs' rapid aging
      clock.cancel(scrubs.tasks)
    if c == 10:
      quit(QuitSuccess)
    c += 1
    echo "C: ", c
    echo scrubs.age
    echo scrubs.name
    echo shadow.age
    echo shadow.name
    echo ""

  proc ageInc(cat: Cat) =
    # Testable without framecounter
    cat.age += 1

  proc nameChange(cat: Cat, name: string) =
    # Testable without framecounter
    cat.name = name
    echo cat.name, " got a new name!"

  proc setupCat(cat: Cat) =
    # Create a closure inside a proc for scheduling code
    # on multiple objects.
    clock.run every(60) do(): 
      cat.ageInc()
    # After 3 seconds (180 frames at 60fps), rename the cat
    clock.run after(180) do():
      cat.nameChange("Mr. " & cat.name)

  scrubs.setupCat()
  shadow.setupCat()

  # Scrubs will age rapidly until task is canceled
  scrubs.tasks.add clock.schedule every(60) do():
    scrubs.age += 1

  # Our next watcher can only be canceled by determining
  # The next 2 framecounter ids and canceling explicitely
  var watcherId = clock.nextId
  var watcherCbId = clock.nextId + 1
  clock.watch scrubs.age < 10, every(60) do():
    echo "Scrubs is less than 10"

  # Our when trigger will auto-cancel itself after the
  # condition is met
  clock.when scrubs.age >= 11, after(1) do():
    echo "Scrubs is old! Changing age!"
    scrubs.age = 6
    clock.cancel(watcherId)
    clock.cancel(watcherCbId)

  while true:
    clock.tick()
  
