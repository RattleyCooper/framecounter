# ⏱️ framecounter

Deterministic frame-based scheduling for game loops.

framecounter lets you run code **`every` N frames** or **`after` N frames**, without worrying about timers, delta time, or drift.

Perfect for animation updates, AI ticks, cooldowns, spawning, scripted events, or anything tied to a fixed framerate.

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

✔️ Perfect for fixed-step game loops (Nico, SDL, OpenGL, etc.)

You just tell it when and what to run.

## 📦 Install
nimble install https://github.com/RattleyCooper/framecounter

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

This makes your code modular, clean, and expressive.

## 🐈 Full Example

```nim
import framecounter

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
var shadow = newCat("Shadow")

# Closure will capture `c`, `scrubs`, and `shadow`, 
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
  echo shadow.age
  echo shadow.name
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
shadow.doStuff()

while true:
  clock.tick()
```

## 🎯 Why Closures Make This Powerful

Each call like:

```nim
clock.run every(60) do():
```

creates a self-contained task that remembers:

* which cat it belonged to
* which variables existed at creation
* how far along it is in its frame countdown

No global managers. No giant switch statements. No “spaghetti update logic.”

Everything stays local and easy to reason about.

## 🧩 What You Can Schedule

* Animation frame updates
* Entity AI thinking ticks
* Attack cooldowns
* Temporary buffs/debuffs
* Delayed scripted events
* Particle spawner timing
* NPC dialogue pacing
* Cutscene sequencing
* Anything that happens later or periodically becomes trivial.

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
