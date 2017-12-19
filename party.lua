--- A module for GPU accelerated particles.
-- @module party

local shaderstring = [[
#pragma language glsl3

#ifdef VERTEX

uniform float time;

uniform vec2 origin = vec2(0);
uniform int radius = 0;
uniform vec4 startColor = vec4(1.0f);
uniform vec4 endColor = vec4(1.0f);
uniform vec2 areaSpread = vec2(0.0f);
uniform float direction = 0.0f;
uniform float spread = 0.0f;

//Movement etc
  //Position
uniform vec2 minLinearAcceleration = vec2(0.0f);
uniform vec2 maxLinearAcceleration = vec2(0.0f);

uniform float minSpeed = 0.0f;
uniform float maxSpeed = 0.0f;
  //Angle
uniform float minStartAngle = 0.0f;
uniform float maxStartAngle = 0.0f;

uniform float minRotationSpeed = 0.0f;
uniform float maxRotationSpeed = 0.0f;
  //Other
uniform float minLifetime = 1.0f;
uniform float maxLifetime = 1.0f;

uniform float minRadius = 5.0f;
uniform float maxRadius = 5.0f;

//Pass the color to the fragment shader
out vec4 vertexColor;

//Helper vars and functions
const float deg120 = 2.0943951024;

float rand(float n)
{
  return fract(sin(n) * 43758.5453123);
}

float randrange(float min, float max, float n)
{
  return mix(min, max, rand(n));
}

vec2 randrange(vec2 min, vec2 max, float n)
{
  return vec2(mix(min.x, max.x, rand(n)), mix(min.y, max.y, rand(n+125)));
}

vec4 position(mat4 transform, vec4 position)
{
  int particleIndex = gl_VertexID / 3;
  float triangleIndex = mod(gl_VertexID, 3);

  float particleSeed = rand(particleIndex);

  float lifetime = randrange(minLifetime, maxLifetime, particleSeed+567);

  float livedfor = mod(time + particleSeed * lifetime, lifetime);
  float progress = livedfor / lifetime;

  float initialDirection = direction + randrange(0, spread, particleSeed-45);
  float initialSpeed = randrange(minSpeed, maxSpeed, particleSeed-34);
	vec2 initialVelocity = vec2(sin(initialDirection), cos(initialDirection)) * initialSpeed;
  vec2 linearAcceleration = randrange(minLinearAcceleration, maxLinearAcceleration, particleSeed+21);
  vec2 velocity = initialVelocity + livedfor * linearAcceleration;

  position.xy = origin + randrange(-areaSpread, areaSpread, particleSeed-2345);
  position.xy += initialVelocity * livedfor + 0.5 * linearAcceleration * pow(livedfor, 2);

  float angle = randrange(minStartAngle, maxStartAngle, particleSeed+29);
  float rotationSpeed = randrange(minRotationSpeed, maxRotationSpeed, particleSeed+38);
  angle += rotationSpeed * livedfor;
  angle += deg120 * triangleIndex;

  float radius = randrange(minRadius, maxRadius, particleSeed-15);

  position.x += cos(angle) * radius;
  position.y += sin(angle) * radius;

  vertexColor = mix(startColor, endColor, progress);

  return transform * position;
}

#endif

#ifdef PIXEL

in vec4 vertexColor;

vec4 effect(vec4 col, sampler2D tex, vec2 tc, vec2 sc)
{
  return vertexColor;
}

#endif
]]

local party = setmetatable({}, {
  __call = function(self, bufferSize)
    local buffer = {}

    for i = 1, bufferSize * 3 do
      buffer[i] = {0, 0}
    end

    self.mesh = love.graphics.newMesh({
      {"VertexPosition", "float", 2}
    }, buffer, "triangles", "static")

    self.shader = love.graphics.newShader(shaderstring)
    self.time = 0

    return self
  end
})

--Helper function
local function assertIsNumber(num, name)
  assert(type(num) == "number", name .. " must be a number")
end

--- Draws a system.
-- Can take any parameters that love.draw would normally.
-- @param ... any draw parameters
function party:draw(...)
  love.graphics.setShader(self.shader)
  self.shader:send("time", love.timer.getTime())
  love.graphics.draw(self.mesh, ...)
  love.graphics.setShader()
end

--- Updates a system.
-- @tparam number dt time since last update
function party:update(dt)
  self.time = self.time + dt
  self.shader:send("time", self.time)
end

--- Sets the origin of the system.
-- @tparam number xOrigin X origin of system
-- @tparam number yOrigin Y origin of system
-- @return system edited system
function party:setOrigin(xOrigin, yOrigin)
  assertIsNumber(xOrigin, "x origin")
  assertIsNumber(yOrigin, "y origin")
  self.shader:send("origin", {xOrigin, yOrigin})
  return self
end

--- Sets the starting color of the system.
-- Color is linearly interpolated between the start and end color over it's lifetime.
-- @tparam number r red color component
-- @tparam number g green color component
-- @tparam number b blue color component
-- @tparam[opt] number a alpha color component
-- @return system edited system
function party:setStartColor(r, g, b, a)
  a = a or 1
  assertIsNumber(r, "red")
  assertIsNumber(g, "green")
  assertIsNumber(b, "blue")
  assertIsNumber(a, "alpha")
  self.shader:send("startColor", {r, g, b, a})
  return self
end

--- Sets the ending color of the system.
-- Color is linearly interpolated between the start and end color over it's lifetime.
-- @tparam number r red color component
-- @tparam number g green color component
-- @tparam number b blue color component
-- @tparam[opt] number a alpha color component
-- @return system edited system
function party:setEndColor(r, g, b, a)
  a = a or 1
  assertIsNumber(r, "red")
  assertIsNumber(g, "green")
  assertIsNumber(b, "blue")
  assertIsNumber(a, "alpha")
  self.shader:send("endColor", {r, g, b, a})
  return self
end

--- Sets the spawning area.
-- @tparam number width width of spawn area
-- @tparam number height height of spawn area
-- @return system edited system
function party:setAreaSpread(width, height)
  assertIsNumber(width, "spawn width")
  assertIsNumber(height, "spawn height")
  self.shader:send("areaSpread", {width / 2, height / 2})
  return self
end

--- Sets the spawn direction.
-- @tparam number direction spawn direction (radians)
-- @return system edited system
function party:setDirection(direction)
	assertIsNumber(direction, "direction")
	self.shader:send("direction", direction)
	return self
end

--- Sets the spawn direction spread
-- @tparam number spread direction spread (radians)
-- @return system edited system
function party:setSpread(spread)
	assertIsNumber(spread, "spread")
	self.shader:send("spread", spread)
	return self
end

--- Sets the minimum linear acceleration.
-- @tparam number x linear acceleration on the x axis
-- @tparam number y linear acceleration on the y axis
-- @return system edited system
function party:setMinLinearAcceleration(x, y)
  assertIsNumber(x, "x")
  assertIsNumber(y, "y")
  self.shader:send("minLinearAcceleration", {x, y})
  return self
end

--- Sets the maximum linear acceleration.
-- @tparam number x linear acceleration on the x axis
-- @tparam number y linear acceleration on the y axis
-- @return system edited system
function party:setMaxLinearAcceleration(x, y)
  assertIsNumber(x, "x")
  assertIsNumber(y, "y")
  self.shader:send("maxLinearAcceleration", {x, y})
  return self
end

--- Sets the minimum and maximum linear acceleration.
-- @tparam number minx minimum linear acceleration on the x axis
-- @tparam number miny minimum linear acceleration on the y axis
-- @tparam[opt] number maxx maximum linear acceleration on the x axis
-- @tparam[opt] number maxy maximum linear acceleration on the y axis
-- @return system edited system
function party:setLinearAcceleration(minx, miny, maxx, maxy)
  maxx, maxy = maxx or minx, maxy or miny
  assertIsNumber(minx, "min x")
  assertIsNumber(miny, "min y")
  assertIsNumber(maxx, "max x")
  assertIsNumber(maxy, "max y")
  self.shader:send("minLinearAcceleration", {minx, miny})
  self.shader:send("maxLinearAcceleration", {maxx, maxy})
  return self
end

--- Sets minimum spawn angle.
-- @tparam number angle minimum starting angle
-- @return system edited system
function party:setMinStartAngle(angle)
  assertIsNumber(angle, "angle")
  self.shader:send("minStartAngle", angle)
  return self
end

--- Sets maximum spawn angle.
-- @tparam number angle maximum starting angle
-- @return system edited system
function party:setMaxStartAngle(angle)
  assertIsNumber(angle, "angle")
  self.shader:send("maxStartAngle", angle)
  return self
end

--- Sets minimum spawn angle.
-- @tparam number minAngle minimum starting angle
-- @tparam[opt] number maxAngle maximum starting angle
-- @return system edited system
function party:setStartAngle(minAngle, maxAngle)
  maxAngle = maxAngle or minAngle
  assertIsNumber(minAngle, "minimum angle")
  assertIsNumber(maxAngle, "maximum angle")
  self.shader:send("minStartAngle", minAngle)
  self.shader:send("maxStartAngle", maxAngle)
  return self
end

--- Sets the minimum constant rotation speed.
-- @tparam number speed minimum rotation speed
-- @return system edited system
function party:setMinRotationSpeed(speed)
  assertIsNumber(speed, "speed")
  self.shader:send("minRotationSpeed", speed)
  return self
end

--- Sets the maximum constant rotation speed.
-- @tparam number speed maximum rotation speed
-- @return system edited system
function party:setMaxRotationSpeed(speed)
  assertIsNumber(speed, "speed")
  self.shader:send("maxRotationSpeed", speed)
  return self
end

--- Sets the minimum and maximum constant rotation speed.
-- @tparam number minspeed minimum rotation speed
-- @tparam[opt] number maxspeed maximum rotation speed
-- @return system edited system
function party:setRotationSpeed(minspeed, maxspeed)
  maxspeed = maxspeed or minspeed
  assertIsNumber(minspeed, "minimum speed")
  assertIsNumber(maxspeed, "maximum speed")
  self.shader:send("minRotationSpeed", minspeed)
  self.shader:send("maxRotationSpeed", maxspeed)
  return self
end

--- Sets the minimum lifetime of the particles.
-- @tparam number lifetime minimum lifetime
-- @return system edited system
function party:setMinLifetime(lifetime)
  assertIsNumber(lifetime, "lifetime")
  self.shader:send("minLifetime", lifetime)
  return self
end

--- Sets the maximum lifetime of the particles.
-- @tparam number lifetime maximum lifetime
-- @return system edited system
function party:setMaxLifetime(lifetime)
  assertIsNumber(lifetime, "lifetime")
  self.shader:send("maxLifetime", lifetime)
  return self
end

--- Sets the minimum and maximum lifetime of the particles.
-- @tparam number minlifetime minimum lifetime
-- @tparam[opt] number maxlifetime maximum lifetime
-- @return system edited system
function party:setLifetime(minlifetime, maxlifetime)
  maxlifetime = maxlifetime or minlifetime
  assertIsNumber(minlifetime, "minimum lifetime")
  assertIsNumber(maxlifetime, "maximum lifetime")
  self.shader:send("minLifetime", minlifetime)
  self.shader:send("maxLifetime", maxlifetime)
  return self
end

--- Sets the minimum radius of the particles.
-- @tparam number radius minimum radius
-- @return system edited system
function party:setMinRadius(radius)
  assertIsNumber(radius, "radius")
  self.shader:send("minRadius", radius)
  return self
end

--- Sets the maximum radius of the particles.
-- @tparam number radius minimum radius
-- @return system edited system
function party:setMaxRadius(radius)
  assertIsNumber(radius, "radius")
  self.shader:send("maxRadius", radius)
  return self
end

--- Sets the minimum and maximum radius of the particles.
-- @tparam number minradius minimum radius
-- @tparam[opt] number maxradius maximum radius
-- @return system edited system
function party:setRadius(minradius, maxradius)
  maxradius = maxradius or minradius
  assertIsNumber(minradius, "minimum radius")
  assertIsNumber(maxradius, "maximum radius")
  self.shader:send("minRadius", minradius)
  self.shader:send("maxRadius", maxradius)
  return self
end

--- Sets the time used for vertex calculations.
-- @tparam number time time
-- @return system edited system
function party:setTime(time)
	assertIsNumber(time, "time")
	self.time = time
	return self
end

return party