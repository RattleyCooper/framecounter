# framecounter
 Schedule code to run after/every X frames.

## Install

`nimble install `

## Example

```nim
import framecounter


var fc = FrameCounter(fps:30)

fc.run(rAfter, 30):
  echo "30 frames have passed!"

var frameCount = 0
fc.run(rEvery, 1):
  frameCount += 1
  echo "on frame ", $frameCount

var dt: float32 
# assume our delta time is being updated.
while true:
  # Do stuff like detecting inputs
  
  # Inserts control flow statements to limit FPS!
  # Everything after this line is FPS limited.
  fc.ControlFlow(dt)

  # Do stuff here.

  fc.tick() # don't forget to tick.
```
