# ⏱️ framecounter

Deterministic frame-based scheduling for games, AI, and simulations.

FrameCounter is a tiny, fast, deterministic scheduler for running closures every `N` frames or after `N` frames, with *reactive scheduling conditions* that execute code when conditions are met.

It gives you:

* Declarative timing
* Reliable sequencing
* Simple cancellation
* AI/state-machine friendly tools (watch, when, cancelable)
* Safe, self-contained closures with captured variables
* Clean logic with no giant update loops or delta-time math

Perfect for:

* Entity AI
* NPC needs and behaviors
* Cooldowns & status effects
* Animation ticks
* Delayed events
* Cutscenes & scripts
* Procedural encounters
* Anything that should happen later, periodically, or based on conditions

framecounter makes reactive temporal logic simple. Here's a simple example. 

If a player is in water, but hasn't learned to swim, they should take water damage
every second (assuming 60fps framecounter). The following code is all you need 
to toggle water damage on a player that's currently in water. Player enters water, they take damage. Player exits water and they stop taking damage. Once they learn
to swim, this watcher and the associated callback will no longer be checked and the player will no longer take damage in water.

```nim
# More on `clock.cancelable` and `watch` later
clock.cancelable:
  clock.watch player.inWater, every(60) do():
    if player.canSwim:
      # Watcher/callback unscheduled here
      clock.cancel()
    else:
      player.takeWaterDamage()
```

## ✨ Why Use Frame-Based Scheduling?

Game timing often gets messy:

* Too many if timer > something checks
* Delta-time drift
* Branches everywhere
* Update order bugs
* Losing track of cooldowns or “run this later” logic

`framecounter` solves this with:

✔️ Clean declarative scheduling

✔️ Deterministic execution

✔️ Zero delta-time math

✔️ Closures that capture state automatically

✔️ Cancellable tasks (Stop events when entities die)

✔️ Perfect for fixed-step game loops (Nico, SDL, OpenGL, etc.)

You just tell it *when* and *what* to run.

## 📦 Install
`nimble install https://github.com/RattleyCooper/framecounter`

## 🚀 Quick Start
```nim
import framecounter

var clock = FrameCounter(fps: 60)

clock.run every(60) do():  # every 1 second at 60fps
  echo "One second passed!"

clock.run after(180) do(): # after 3 seconds
  echo "Three seconds passed!"

while true:
  clock.tick()
```

*Note: `N` must be `>= 1`.*

## 🧠 How Closures Work Here (Important!)

When you write:

```nim
var c = 0
clock.run every(60) do():
  c += 1
```

The `do():` block is a closure, meaning:

* It remembers the variables that were in scope when you created it
* It runs later, but still has access to those variables
* Even if you create many closures, each keeps its own reference of what it captured

That means you can write logic like:

* “Increase this specific cat’s age every second”
* “After 3 seconds rename only this cat”
* “Stop the game after `c` reaches 10”
* “Trigger unique behavior per entity with no global switch statements”

This makes your code *modular*, *clean*, and *expressive*.

Alternatively, you can use a `proc` with the `{.closure.}` pragma.

```nim
var c = 0
proc incC() {.closure.} =
  c += 1

clock.run every(60) incC
```

## 🛠 Core Scheduling Primitives
`run every(N)` Runs every `N` frames forever.

```nim
clock.run every(120) do():
  enemy.think()
```

`run after(N)` Runs *once* after `N` frames.

```nim
clock.run after(30) do():
  player.fireReady = true
```

`schedule` (get a task ID) Useful for cancellation.

```nim
let id = clock.schedule after(300) do(): 
  boss.enrage()
clock.cancel(id)
```

## 🛑 Scheduling & Cancellation (Preventing Crashes)

Sometimes you schedule something to happen later (e.g., "Heal player in 3 seconds"), but the entity dies before that happens.

If you don't cancel the task, the closure will still run and try to heal a dead (or nil) player, often causing a crash.

### 🧟 The "Zombie Cat" Problem (Why you need this)

Imagine we schedule a name change for a `cat`, but we delete the `cat` variable before the schedule fires.

```nim
import framecounter

type Cat = ref object
  name: string

proc newCat(name: string): Cat =
  # Create a new cat.
  result.new()
  result.name = name

var clock = FrameCounter(fps: 60)
var scrubs = newCat("Scrubs")

# Schedule a task for the future
# Use 'schedule' instead of 'run' to get the Task ID
let renameTask = clock.schedule after(60) do():
  # If 'scrubs' is nil when this runs, the game crashes!
  if scrubs != nil:
    scrubs.name = "Ghost Scrubs" 
    echo "Renamed!"
  else:
    echo "Error: Cat does not exist!"

# Simulate the cat dying/being removed from the game
scrubs = nil 

# If we do NOTHING, the closure runs next second and might crash 
#    or perform logic on an invalid object.

# The Solution: Cancel the task!
clock.cancel(renameTask)

# Now, when we tick, nothing bad happens.
clock.tick()
```

Use `schedule` to get an ID, and `cancel` to stop it.

### 🎒 The "Bag of Tasks" Pattern (Recommended)

**For entities with multiple tasks**, store all task IDs in a `seq[int]` and `cancel` them all at once:

```nim
type Enemy = ref object
  name: string
  hp: int
  tasks: seq[int]  # Bag of all scheduled task IDs

proc setupEnemy(enemy: Enemy, clock: var FrameCounter) =
  # Track enemy state changes to cancel later
  enemy.tasks.add clock.schedule after(600) do():
    enemy.nextState()

proc removeEnemy(enemy: Enemy, clock: var FrameCounter) =
  # Cancel ALL tasks with one call and clears their task list.
  clock.cancel(enemy.tasks)
  # Now safe to remove enemy from the game
```

## 👀 Reactive Scheduling with Conditions

(The most powerful part of FrameCounter)

`watch condition, every(N)`

Runs every N frames while condition is true.

Perfect for reversible behaviors:

* “meow until fed”
* “nap until rested”
* “take poison damage while poisoned”
* “regen stamina while resting”

```nim
# Regenerate health if health is ever below 50
clock.watch player.hp < 50, every(30) do():
  player.regen(1)
```

Stops *automatically* when the condition becomes false and *continues* when the condition becomes true again.

`when condition, after(N)`

Schedules a one-shot event that triggers `N` frames after the condition becomes true, then cancels itself.

Great for permanent “unlock once” events:

* learn a skill
* trigger a cutscene
* evolve a creature
* apply a debuff once

```nim
clock.when enemy.hp <= 0, after(1) do():
  enemy.die() # presumably canceling tasks in enemy.die()
```

## 🔒 Cancelable Blocks

Sometimes you want a whole block of watchers and tasks to be removed permanently after some condition succeeds.

Use:

```nim
clock.cancelable:
  # all tasks created here can be individually 
  # canceled with `cancel` within their closure.
  clock.watch something, every(30) do():
    if done:
      clock.cancel() # removes everything defined in this block and the watcher

  clock.watch somethingElse, every(30) do():
    if done:
      clock.cancel() # Removes this individual watcher/callback.
```

This is ideal for:

* skill learning
* progression gates
* temporary states
* “burn out” or “fleeing” AI
* multi-step interactions

*Examples in readme.*

## 🧩 Patterns & Usage

### ✔ Reversible Behaviors → `watch`

Use `watch` for things that should repeatedly activate while a condition is true:

* hunger → meow → eat → satisfied
* low stamina → nap → rested
* poisoned → lose health → cured

`watch` *automatically stops* when the condition becomes false, and *continues* when the condition becomes true. This facilitates the creation of complex state transitions with a clean, declarative syntax.

### ✔ One-Shot Triggers → `when`

Use `when` for:

* achievements
* permanent skill unlocks
* “do this once when X becomes true”
* cutscene triggers
* Self-canceling.

`when` is great for non-repeating conditional behavior.

### ✔ Temporary States → `cancelable`:

Use cancelable blocks when you want a state machine step that *eventually* ends forever.

Example: *"learning to swim”*:

* cat enters water
* take damage
* eventually learns
* damage behavior never runs again

## 🐈 Full Example

```nim
if isMainModule:
  # The fps value defines your logical update 
  # rate. every(60) means ‘every 60 logical 
  # frames’, not real-time seconds.
  var clock = FrameCounter(fps: 60)

  type 
    Cat = ref object
      name: string
      health: int
      hunger: int
      energy: int
      eating: bool
      learnedToHunt: bool # A permanent progression flag
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

  # === BASE NEEDS ===
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

  # === HUNGER RESPONSE: NOT cancelable ===
  # Meow until fed
  clock.watch scrubs.hunger >= 70, every(90) do():
    echo scrubs.name, " meows! Hunger: ", scrubs.hunger
    if scrubs.hunger >= 90:
      scrubs.feed()

  clock.watch shadow.hunger >= 70, every(90) do():
    echo shadow.name, " meows! Hunger: ", shadow.hunger
    if shadow.hunger >= 90:
      shadow.feed()

  clock.watch scrubs.eating, after(120) do():
    scrubs.finishedEating()
    echo "Scrubs finished eating! Scrubs hunger: ", scrubs.hunger

  clock.watch shadow.eating, after(120) do():
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

  # === PERMANENT PROGRESSION: This is explicitly cancelable! ===
  clock.cancelable:
    # Is scrubs in water? Let's teach him how to swim.
    clock.watch scrubs.inWater, every(60) do():
      if scrubs.canSwim:
        # removes watcher and callback entirely.
        # this watch block will no longer monitor
        # and it's callback will never fire again.
        # Scrubs is now safe in water!
        clock.cancel() 
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

  # End simulation after 120 seconds
  var t = 0
  clock.run every(60) do():
    t += 1
    if t == 120:
      quit(QuitSuccess)

  while true:
    clock.tick()

```

## ⏱️ About Delta-Time (Do You Need It?)

`FrameCounter` does not use delta-time internally — and it doesn’t need to.

Why?

Because `framecounter` is not a game loop or physics integrator.

It’s simply:

A tiny scheduler that runs closures after or every N frames.

It doesn’t care what you use your frames for:

* Rendering
* Physics
* AI updates
* Scripted events
* Gameplay timers
* Cooldowns
* Cutscenes
* Anything else

Your frame loop could be tied to rendering, but it doesn't have to be.

## ❌ When Delta-Time Is Not Needed

* If you are only using `framecounter` as:
* a scheduler
* a timed-event system
* a frame-based sequencer

then no delta-time math is required at all.

It’s intentionally simple:

```nim
clock.run after(180) do(): # run this after 180 frames
clock.run every(60) do():     # run this every 60 frames
```

That’s it.

## ✔ When Delta-Time Is Useful (Outside This Library)

If your game or program has variable framerate and you want:

* consistent player movement
* physics updates
* interpolation
* velocity-based animations

Then you might want dt in your game loop.

Example:

```nim
let dt = elapsedTimeSeconds()
player.x += player.speed * dt
```

This is completely separate from how you use the scheduler.
