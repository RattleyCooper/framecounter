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

var cats = FrameCounter[Cat](fps: 60)

var scrubs = Cat(name: "Scrubs")
var shadow = Cat(name: "Shadow")

cats.run scrubs.after(60) do(c: var Cat):
  c.name = "Not Scrubs"

cats.run shadow.after(60) do(c: var Cat):
  c.name = "Not Shadow"

var c = 0
cats.run scrubs.every(30) do(sc: var Cat):
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
  
  cats.tick() # tick frame counter.
```
