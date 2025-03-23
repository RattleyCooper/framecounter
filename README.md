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

var clock = FrameCounter(fps: 60)

var scrubs = Cat(name: "Scrubs")
var shadow = Cat(name: "Shadow")

clock.run after(60) do():
  scrubs.name = "Not Scrubs"
  shadow.name = "Not Shadow"

var c = 0
clock.run every(30) do():
  echo "repeating"
  if c == 3:
    echo scrubs.name
    echo shadow.name
    quit(QuitSuccess)
  c += 1
  echo c

echo scrubs.name
echo shadow.name

var dt: float32 
# assume our delta time is being updated.
while true:
  # Do stuff like detecting inputs
  
  clock.tick() # tick frame counter.
```
