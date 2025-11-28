# framecounter
 Schedule code to run after/every X frames.

## Install

`nimble install https://github.com/RattleyCooper/framecounter`

## Example

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
