--- A module for GPU accelerated particles.
-- @module party

local shaderstring = [[
#ifdef VERTEX

uniform float time;

//Movement etc
  //Position
uniform vec2 minLinearAcceleration = vec2(0.0f);
uniform vec2 maxLinearAcceleration = vec2(0.0f);

uniform float minLinearDamping = 0.0f;
uniform float maxLinearDamping = 0.0f;

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

uniform float particleCount = 0;
uniform vec2 origin = vec2(0);
uniform int radius = 0;
uniform vec4 startColor = vec4(1.0f);
uniform vec4 endColor = vec4(1.0f);
uniform vec2 areaSpread = vec2(0.0f);
uniform float direction = 0.0f;
uniform float spread = 0.0f;

//Pass the color to the fragment shader
varying vec4 vertexColor;

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

  int vertexID = int(position.x);
  int particleIndex = vertexID / 3;
  float triangleIndex = mod(vertexID, 3);

  float particleSeed = rand(particleIndex / particleCount);

  float lifetime = randrange(minLifetime, maxLifetime, particleSeed+56.0f);

  float livedfor = mod(time + particleSeed * lifetime, lifetime);
  float progress = livedfor / lifetime;

  float initialDirection = direction + randrange(0, spread, particleSeed-45.0f);
  float initialSpeed = randrange(minSpeed, maxSpeed, particleSeed-34);
  vec2 linearAcceleration = randrange(minLinearAcceleration, maxLinearAcceleration, particleSeed+21.0f);
  float linearDamping = randrange(minLinearDamping, maxLinearDamping, particleSeed+3.0f);
  position.xy = origin + randrange(-areaSpread, areaSpread, particleSeed-23.0f);

  vec2 initialVelocity = vec2(sin(initialDirection), cos(initialDirection)) * initialSpeed;
  vec2 velocity = initialVelocity + livedfor * linearAcceleration;

  if (linearDamping == 0)
  {
    position.xy += initialVelocity * livedfor + 0.5 * linearAcceleration * pow(livedfor, 2);
  } else {
    position.xy += + linearAcceleration / linearDamping * livedfor + (linearAcceleration
      / linearDamping - initialVelocity) / linearDamping * (exp(-linearDamping * livedfor) - 1);
  }
  //All credit goes to pfirsich for this magic.

  float angle = randrange(minStartAngle, maxStartAngle, particleSeed+29.0f);
  float rotationSpeed = randrange(minRotationSpeed, maxRotationSpeed, particleSeed+38.0f);
  angle += rotationSpeed * livedfor;
  angle += deg120 * triangleIndex;

  float radius = randrange(minRadius, maxRadius, particleSeed-15.0f);

  position.x += cos(angle) * radius;
  position.y += sin(angle) * radius;

  vertexColor = mix(startColor, endColor, progress);

  return transform * position;
}

#endif

#ifdef PIXEL

varying vec4 vertexColor;

vec4 effect(vec4 col, sampler2D tex, vec2 tc, vec2 sc)
{
  return vertexColor * col;
}

#endif
]]

local party = setmetatable({}, {
  __call = function(self, bufferSize)
    local buffer = {}

    for i = 1, bufferSize * 3 do
      buffer[i] = {i-1, 0}
    end

    self.mesh = love.graphics.newMesh({
      {"VertexPosition", "float", 2}
    }, buffer, "triangles", "static")

    self.shader = love.graphics.newShader(shaderstring)
    self.time = 0

    self.shader:send("particleCount", bufferSize)

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
  self.shader:send("time", self.time)
  love.graphics.draw(self.mesh, ...)
  love.graphics.setShader()
end

--- Updates a system.
-- @tparam number dt time since last update
function party:update(dt)
  self.time = self.time + dt
end

--- Sets the origin of the system.
-- @tparam number xOrigin X origin of system
-- @tparam number yOrigin Y origin of system
-- @return system edited system
function party:origin(xOrigin, yOrigin)
	xOrigin = xOrigin or self.xOrigin
	yOrigin = yOrigin or self.yOrigin
  assertIsNumber(xOrigin, "x origin")
  assertIsNumber(yOrigin, "y origin")
  if xOrigin ~= self.xOrigin or yOrigin ~= self.yOrigin then
  	self.shader:send("origin", {xOrigin, yOrigin})
  	self.xOrigin, self.yOrigin = xOrigin, yOrigin
  end
  return self
end

--- Sets the starting color of the system.
-- Color is linearly interpolated between the start and end color over it's lifetime.
-- @tparam number r red color component
-- @tparam number g green color component
-- @tparam number b blue color component
-- @tparam[opt] number a alpha color component
-- @return system edited system
function party:startColor(r, g, b, a)
	a = a or 1
  assertIsNumber(r, "red")
  assertIsNumber(g, "green")
  assertIsNumber(b, "blue")
  assertIsNumber(a, "alpha")
  if r ~= self.sr or g ~= self.sg or b ~= self.sb or a ~= self.sa then
  	self.shader:send("startColor", {r, g, b, a})
  	self.sr, self.sg, self.sb, self.sa = r, g, b, a
  end
  return self
end

--- Sets the ending color of the system.
-- Color is linearly interpolated between the start and end color over it's lifetime.
-- @tparam number r red color component
-- @tparam number g green color component
-- @tparam number b blue color component
-- @tparam[opt] number a alpha color component
-- @return system edited system
function party:endColor(r, g, b, a)
  a = a or 1
  assertIsNumber(r, "red")
  assertIsNumber(g, "green")
  assertIsNumber(b, "blue")
  assertIsNumber(a, "alpha")
  if r ~= self.er or g ~= self.eg or b ~= self.eb or a ~= self.ea then
  	self.shader:send("endColor", {r, g, b, a})
  	self.er, self.eg, self.eb, self.ea = r, g, b, a
  end
  return self
end

--- Sets the spawning area.
-- @tparam number spawnWidth width of spawn area
-- @tparam[opt] number spawnHeight height of spawn area
-- @return system edited system
function party:areaSpread(spawnWidth, spawnHeight)
	spawnHeight = spawnHeight or spawnWidth
  assertIsNumber(spawnWidth, "spawn width")
  assertIsNumber(spawnHeight, "spawn height")
  if spawnWidth ~= self.spawnWidth or spawnHeight ~= self.spawnHeight then
  	self.shader:send("areaSpread", {spawnWidth / 2, spawnHeight / 2})
  	self.spawnWidth, self.spawnHeight = spawnWidth, spawnHeight
  end
  return self
end

--- Sets the spawn direction.
-- @tparam number direction spawn direction (radians)
-- @return system edited system
function party:direction(direction)
  assertIsNumber(direction, "direction")
  if direction ~= self.direction then
	  self.shader:send("direction", direction)
	  self.direction = direction
	end
  return self
end

--- Sets the spawn direction spread
-- @tparam number spread direction spread (radians)
-- @return system edited system
function party:spread(spread)
  assertIsNumber(spread, "spread")
  if spread ~= self.spread then
  	self.shader:send("spread", spread)
  	self.spread = spread
  end
  return self
end

--- Sets the minimum and maximum linear acceleration.
-- @tparam number minXLinAcc minimum linear acceleration on the x axis
-- @tparam number minYLinAcc minimum linear acceleration on the y axis
-- @tparam[opt] number maxXLinAcc maximum linear acceleration on the x axis
-- @tparam[opt] number maxYLinAcc maximum linear acceleration on the y axis
-- @return system edited system
function party:linearAcceleration(minXLinAcc, minYLinAcc, maxXLinAcc, maxYLinAcc)
  maxXLinAcc = maxXLinAcc or minXLinAcc
  maxYLinAcc = maxYLinAcc or minYLinAcc
  assertIsNumber(minXLinAcc, "minimum x linear acceleration")
  assertIsNumber(minYLinAcc, "minimum y linear acceleration")
  assertIsNumber(maxXLinAcc, "maximum x linear acceleration")
  assertIsNumber(maxYLinAcc, "maximum y linear acceleration")
  if minXLinAcc ~= self.minXLinAcc or
  		minYLinAcc ~= self.minYLinAcc then
  	self.shader:send("minLinearAcceleration", {minXLinAcc, minYLinAcc})
  	self.minXLinAcc = minXLinAcc
  	self.minYLinAcc = minYLinAcc
  end
  if maxXLinAcc ~= self.maxXLinAcc or
  		maxYLinAcc ~= self.maxYLinAcc then
  	self.shader:send("maxLinearAcceleration", {maxXLinAcc, maxYLinAcc})
  	self.maxXLinAcc = maxXLinAcc
  	self.maxYLinAcc = maxYLinAcc
  end
  return self
end

--- Sets minimum and maximum linear damping
-- @tparam number minLinearDamping minimum linear damping
-- @tparam[opt] number maxLinearDamping maximum linear damping
-- @return system edited system
function party:linearDamping(minLinearDamping, maxLinearDamping)
	maxLinearDamping = maxLinearDamping or minLinearDamping
  assertIsNumber(minLinearDamping, "min damping")
  assertIsNumber(maxLinearDamping, "max damping")
  if minLinearDamping ~= self.minLinearDamping then
  	self.shader:send("minLinearDamping", minLinearDamping)
  	self.minLinearDamping = minLinearDamping
  end
  if maxLinearDamping ~= self.maxLinearDamping then
  	self.shader:send("maxLinearDamping", maxLinearDamping)
  	self.maxLinearDamping = maxLinearDamping
  end
  return self
end

--- Sets the minimum speed
-- @tparam number minSpeed minimum speed
-- @tparam[opt] number maxSpeed maximum speed
-- @return system edited system
function party:speed(minSpeed, maxSpeed)
	maxSpeed = maxSpeed or minSpeed
	assertIsNumber(minSpeed, "minimum speed")
	assertIsNumber(maxSpeed, "maximum speed")
	if minSpeed ~= self.minSpeed then
		self.shader:send("minSpeed", minSpeed)
		self.minSpeed = minSpeed
	end
	if maxSpeed ~= self.maxSpeed then
		self.shader:send("maxSpeed", maxSpeed)
		self.maxSpeed = maxSpeed
	end
	return self
end

--- Sets minimum spawn angle.
-- @tparam number minAngle minimum starting angle
-- @tparam[opt] number maxAngle maximum starting angle
-- @return system edited system
function party:startAngle(minAngle, maxAngle)
  maxAngle = maxAngle or minAngle
  assertIsNumber(minAngle, "minimum angle")
  assertIsNumber(maxAngle, "maximum angle")
  if minAngle ~= self.minAngle then
  	self.shader:send("minStartAngle", minAngle)
  	self.minAngle = minAngle
  end
  if maxAngle ~= self.maxAngle then
  	self.shader:send("maxStartAngle", maxAngle)
  	self.maxAngle = maxAngle
  end
  return self
end

--- Sets the minimum and maximum constant rotation speed.
-- @tparam number minSpin minimum rotation speed
-- @tparam[opt] number maxSpin maximum rotation speed
-- @return system edited system
function party:spin(minSpin, maxSpin)
  maxSpin = maxSpin or minSpin
  assertIsNumber(minSpin, "minimum speed")
  assertIsNumber(maxSpin, "maximum speed")
  if minSpin ~= self.minSpin then
	  self.shader:send("minRotationSpeed", minSpin)
	  self.minSpin = minSpin
	end
  if maxSpin ~= self.maxSpin then
	  self.shader:send("maxRotationSpeed", maxSpin)
	  self.maxSpin = maxSpin
	end
  return self
end

--- Sets the minimum and maximum lifetime of the particles.
-- @tparam number minLifetime minimum lifetime
-- @tparam[opt] number maxLifetime maximum lifetime
-- @return system edited system
function party:lifetime(minLifetime, maxLifetime)
  maxLifetime = maxLifetime or minLifetime
  assertIsNumber(minLifetime, "minimum lifetime")
  assertIsNumber(maxLifetime, "maximum lifetime")
  if minLifetime ~= self.minLifetime then
  	self.shader:send("minLifetime", minLifetime)
  	self.minLifetime = minLifetime
  end
  if maxLifetime ~= self.maxLifetime then
  	self.shader:send("maxLifetime", maxLifetime)
  	self.maxLifetime = maxLifetime
  end
  return self
end

--- Sets the minimum and maximum radius of the particles.
-- @tparam number minRadius minimum radius
-- @tparam[opt] number maxRadius maximum radius
-- @return system edited system
function party:radius(minRadius, maxRadius)
  maxRadius = maxRadius or minRadius
  assertIsNumber(minRadius, "minimum radius")
  assertIsNumber(maxRadius, "maximum radius")
  if minRadius ~= self.minRadius then
	  self.shader:send("minRadius", minRadius)
	  self.minRadius = minRadius
	end
  if maxRadius ~= self.maxRadius then
	  self.shader:send("maxRadius", maxRadius)
	  self.maxRadius = maxRadius
	end
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