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

var scrubs = Cat(name: "Scrubs")
var cat = FrameCounter[Cat](fps: 60)

cat.run scrubs.after(60) do(c: var Cat):
  c.name = "bobby"

var c = 0
cat.run scrubs.every(30) do(sc: var Cat):
  echo "repeating"
  if c == 10:
    quit(QuitSuccess)
  c += 1
  echo c
  echo scrubs.name

echo scrubs.name
var dt: float32 
# assume our delta time is being updated.
while true:
  # Do stuff like detecting inputs
  
  cat.tick() # tick frame counter.
```
