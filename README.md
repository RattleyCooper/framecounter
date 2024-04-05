# framecounter
 Schedule code to run after/every X frames.

## Install

`nimble install https://github.com/RattleyCooper/framecounter`

## Example

```nim
import framecounter


var fc = FrameCounter(fps:30)

fc.run after(30) do():
  echo "30 frames have passed!"

var frameCount = 0
fc.run every(1) do:
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
