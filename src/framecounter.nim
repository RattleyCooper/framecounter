import std/[monotimes, times, macros]
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

proc after*(frames: int, body: proc() {.closure}): OneShot =
  OneShot(
    target: frames.uint,
    frame: 0,
    body: body,
    id: -1
  )

proc every*(frames: int, body: proc() {.closure.}): MultiShot =
  MultiShot(
    target: frames.uint,
    body: body,
    id: -1
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
  # Remove from MultiShots
  echo "cancel called with id: ", id
  for i in countdown(f.frameProcs.high, 0):
    if f.frameProcs[i].id == id:
      f.frameProcs.delete(i)
      return
  # Remove from OneShots
  for i in countdown(f.oneShots.high, 0):
    if f.oneShots[i].id == id:
      f.oneShots.delete(i)
      return

proc cancel*(f: FrameCounter, ids: var seq[int]) =
  ## Batch cancellation. Removes all tasks in the list and clears the list.
  ## Usage: clock.cancel(player.tasks)
  for i in countdown(ids.high, 0):
    f.cancel(ids[i])
  ids.setLen(0)

template cancel*(f: FrameCounter) =
  echo "Canceling ", watcherId, " and ", cbId
  f.cancel(watcherId)
  f.cancel(cbId)

proc watch*(f: FrameCounter, cond: proc(): bool {.closure.}, m: MultiShot) =
  var triggered = false
  m.id = f.genId()
  f.run every(1) do():
    if cond() and not triggered:
      f.frameProcs.add m
      triggered = true
    elif not cond() and triggered:
      f.cancel(m.id)
      triggered = false

proc watch*(f: FrameCounter, cond: proc(): bool {.closure.}, o: OneShot) =
  var triggered = false
  o.id = f.genId()
  f.run every(1) do():
    if cond() and not triggered:
      f.oneShots.add o
      triggered = true
    elif not cond() and triggered:
      f.cancel(o.id)
      triggered = false

template watch*(f: FrameCounter, cond: untyped, m: MultiShot): untyped =
  # Waits until condition is true before scheduling multishot. Cancels
  # multishot if the condition isn't true before multishot is called.
  var triggered = false
  let cbId = f.genId()
  f.run every(1) do():  
    if (`cond`) and not triggered:
      # echo "cbId ", cbId
      f.frameProcs.add MultiShot(
        target: m.target,
        body: m.body,
        id: cbId
      )
      triggered = true
    elif not (`cond`) and triggered:
      f.cancel(cbId)
      triggered = false

template watch*(f: FrameCounter, cond: untyped, o: OneShot): untyped =
  # Waits until condition is true before scheduling oneshot. Cancels 
  # oneshot if the condition isn't true before the oneshot is 
  # called.
  var triggered = false
  let cbId = f.genId()
  f.run every(1) do():
    if (`cond`) and not triggered:
      f.oneShots.add OneShot(
        target: o.target,
        body: o.body,
        id: cbId,
        frame: o.frame
      )
      triggered = true
    elif not (`cond`) and triggered:
      f.cancel(cbId)
      triggered = false

# proc watchBlock(f: FrameCounter, cond: untyped, body: untyped)

proc `when`*(f: FrameCounter, cond: proc(): bool {.closure.}, m: MultiShot) =
  # Triggers multishot when the proc evaluates to true. Multishot persists
  # unless canceled explicitly.
  m.id = f.genId()
  f.run every(1) do():
    if cond():
      f.frameProcs.add m
      f.cancel(m.id)

proc `when`*(f: FrameCounter, cond: proc(): bool {.closure.}, o: OneShot) =
  # Triggers oneshot when the proc evaluates to true. Since oneshots terminate
  # themselves, no canceling is required.
  o.id = f.nextId
  f.run every(1) do():
    if cond():
      f.oneShots.add o
      f.cancel(o.id)

template `when`*(f: FrameCounter, cond: untyped, m: MultiShot): untyped =
  # Triggers multishot when the condition is met. Multishot persists
  # unless canceled explicitly.
  var triggered = false
  let cbId = f.genId()
  let nid = cbId + 1
  f.run every(1) do():
    if (`cond`) and not triggered:
      f.frameProcs.add MultiShot(
        target: m.target,
        body: m.body,
        id: cbId
      )
      triggered = true
    # elif triggered:
    #   f.cancel(nid)
    #   f.cancel(cbId)

template `when`*(f: FrameCounter, cond: untyped, o: OneShot): untyped =
  # Triggers oneshot when the condition is met. Since oneshots terminate
  # themselves, no canceling is required.'
  var triggered = false
  let cbId = f.genId()
  var nid = cbId + 1
  f.run every(1) do():
    if (`cond`) and not triggered:
      f.oneShots.add OneShot(
        target: o.target,
        body: o.body,
        id: cbId,
        frame: o.frame
      )
      triggered = true
    elif triggered:
      f.cancel(nid)
      # f.cancel(cbId)

proc newFrameCounter*(fps: int): FrameCounter =
  var f: FrameCounter
  f.new()
  f.fps = fps
  f.frame = 0.uint
  f.frameProcs = newSeq[MultiShot]()
  f.oneShots = newSeq[OneShot]()
  f.last = getMonoTime()
  f.nextId = 1
  return f

template watcherIds*(f: FrameCounter) =
  var watcherId {.inject.} = f.nextId + 1
  var cbId {.inject.} = f.nextId

macro cancelable*(f: FrameCounter, x: untyped): untyped =
  result = newStmtList()
  for statement in x:
    result.add quote do:
      block:
        `f`.watcherIds
        `statement`
  echo result.repr

# === EXAMPLE ===
if isMainModule:
  var clock = FrameCounter(fps: 60)

  type 
    Cat = ref object
      name: string
      health: int
      hunger: int
      energy: int
      eating: bool
      learnedToHunt: bool   # A permanent progression flag
      canSwim: bool

  proc newCat(name: string): Cat =
    new result
    result.name = name
    result.health = 100
    result.hunger = 50
    result.energy = 100
    result.eating = false
    result.learnedToHunt = false
    result.canSwim = false

  proc feed(cat: Cat) =
    cat.hunger = max(cat.hunger - 40, 0)
    cat.eating = true
    echo cat.name, " is eating. Hunger now ", cat.hunger

  proc finishedEating(cat: Cat) =
    cat.eating = false
    echo cat.name, " finished eating."

  proc nap(cat: Cat) =
    cat.energy = min(cat.energy + 10, 100)
    echo cat.name, " naps. Energy: ", cat.energy

  proc learnHunting(cat: Cat) =
    cat.learnedToHunt = true
    echo cat.name, " has learned to hunt! (Permanent skill)"

  proc takeWaterDamage(cat: Cat) =
    cat.health -= 10
    echo "Cat taking water damage! Health: ", cat.health

  proc learnToSwim(cat: Cat) =
    cat.canSwim = true
    echo cat.name, " learned to swim!"

  proc inWater(cat: Cat): bool =
    true

  # Create cats
  var scrubs = newCat("Scrubs")
  var shadow = newCat("Shadow")

  # === BASE NEEDS: These are REVERSIBLE → normal watchers ===

  # Hunger gradually increases
  clock.run every(60) do():
    scrubs.hunger = min(scrubs.hunger + 1, 100)
    shadow.hunger = min(shadow.hunger + 1, 100)
    echo "Scrubs hunger: ", scrubs.hunger
    echo "Shadow hunger: ", shadow.hunger

  # Energy gradually decreases
  clock.run every(120) do():
    scrubs.energy = max(scrubs.energy - 1, 0)
    shadow.energy = max(shadow.energy - 1, 0)
    echo "Scrubs energy: ", scrubs.energy
    echo "Shadow energy: ", shadow.energy

  # === HUNGER RESPONSE: Reversible → NOT cancelable ===

  # Meow until fed
  clock.watch scrubs.hunger >= 70, every(90) do():
    echo scrubs.name, " meows! Hunger: ", scrubs.hunger
    if scrubs.hunger >= 90:
      scrubs.feed()

  clock.watch shadow.hunger >= 70, every(90) do():
    echo shadow.name, " meows! Hunger: ", shadow.hunger
    if shadow.hunger >= 90:
      shadow.feed()

  clock.when scrubs.eating, after(120) do():
    scrubs.finishedEating()
    echo "Scrubs finished eating! Scrubs hunger: ", scrubs.hunger

  clock.when shadow.eating, after(120) do():
    shadow.finishedEating()
    echo "Shadow finished eating! Shadow hunger: ", shadow.hunger

  # === ENERGY RESPONSE: Reversible → NOT cancelable ===

  # Nap until fully rested
  clock.watch scrubs.energy <= 90, every(50) do():
    scrubs.nap()
    echo "Scrubs energy: ", scrubs.energy

  clock.watch shadow.energy <= 90, every(50) do():
    shadow.nap()
    echo "Shadow energy: ", shadow.energy

  # === PERMANENT PROGRESSION: This IS cancelable! ===
  clock.cancelable:
    clock.watch scrubs.inWater, every(60) do():
      if scrubs.canSwim:
        clock.cancel() # removes watcher and callback entirely.
      elif scrubs.health <= 80:
        scrubs.learnToSwim()
      else:
        scrubs.takeWaterDamage()

  # === PERMANENT PROGRESSION: Self-canceling! ===
  # Cats will learn to hunt *once* the first time they reach starving condition
  clock.when scrubs.hunger >= 60, after(60) do():
    scrubs.learnHunting()
  clock.when shadow.hunger >= 60, after(60) do():
    shadow.learnHunting()

  # End simulation after 20 ticks
  var t = 0
  clock.run every(60) do():
    t += 1
    if t == 120:
      quit(QuitSuccess)

  while true:
    clock.tick()
