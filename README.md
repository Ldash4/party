party.lua (love2d 0.9.0+, tested with 0.10.2 - 0.11.0)
=========

Disclaimer
----------

* This is **not** a replacement for love2d's particlesystem
* party.lua will look bad if you change any of it's parameters while it is emitting particles
* The system can be running or not running, there is nothing in between, and when it is not running, all the particles dissappear instantly

Why?
----
party.lua generates all particles each frame, independant of previous or future states. This means that when it is stopped, it doesn't know how long ago it stopped. It also isn't aware of what parameters it had last frame, so changing the parameters makes it think that the parameters have always been changed.

So why should I use this?
-------------------------

While it obviously isn't good for dynamic systems, it is perfect for static systems. Think a waterfall or a fire.

Tested on a gtx 970, party.lua can easily spawn a few hundred thousand particles without slowing down.

Usage
-----


```lua
local party = require("party")
local system = party(750)
	:origin(50, 50)
	:radius(5, 25)
	:startColor(0, 0.2, 1)
	:areaSpread(100, 60)
	:linearAcceleration(0, 1000)
	:endColor(0, 0.9, 1, 0)
	:lifetime(1, 1.2)
	:startAngle(-math.pi, math.pi)
	:spin(-2, 2)
	:direction(math.pi / 2)
	:speed(250)

function love.update(dt)
  system:update(dt)
end

function love.draw()
  system:draw()
end
```

This will spawn a nice waterfall with 750 particles.

Documentation
-------------

Documentation can be found [here](https://ldash4.github.io/party/)

Potential future features
-------------------------

* Linear interpolation between more than two colors
* Simple texturing
* Getters/attributes for particle system data (such as :getRadius() or system.radius)