-- @file bturtle.lua
--
-------------------------------------------------------------------------------

-- ============================================================================
-- Constants ------------------------------------------------------------------

-- Public - Available X,Z direction constants.
DIRECTION_NORTH = 'north'
DIRECTION_SOUTH = 'south'
DIRECTION_WEST  = 'west'
DIRECTION_EAST  = 'east'

-- Available Y direction constants.
DIRECTION_UP   = 'up'
DIRECTION_DOWN = 'down'

-- Available severity of logs.
local LOG_NOTICE  = 21
local LOG_WARNING = 22
local LOG_ERROR   = 23
local LOG_DEBUG   = 24

-- Initial inventory mapping.
local UNBREAKABLE_BLOCKS = {
  "computecraft:turtle"
  "computecraft:advanced_turtle"
  "chickenchunks:chunk_loader"
  "enderstorage:ender_chest"
}

-- State saving file.
local FILE_STATE = "bturtle.json"

-- ============================================================================
-- Variables ------------------------------------------------------------------

-- Initial inventory mapping.
local inventory = {
  1 = "fuel"
  2 = "unload"
  3 = "free"
}

-- Direction the turtle is facing.
local direction = nil

-- The turtle position initially set by GPS.
local position = nil

-- Use of GPS?
local haveGPS = false

-- Turtle was initialized?
local haveInit = false

-- ============================================================================
-- SET/GET --------------------------------------------------------------------

-------------------------------------------------------------------------------
-- @function public getInventory()
--
-- Get inventory map array.

getInventory = function ()
  checkInit()
  return inventory
end

-------------------------------------------------------------------------------
-- @function public getDirection()
--
-- Get direction turtle is facing.

getDirection = function ()
  checkInit()
  return direction
end

-------------------------------------------------------------------------------
-- @function public getPosX()
--
-- Get the X position.

getPosX = function ()
  checkInit()
  return position.x
end

-------------------------------------------------------------------------------
-- @function public getPosY()
--
-- Get the Y position (height).

getPosY = function ()
  checkInit()
  return position.y
end

-------------------------------------------------------------------------------
-- @function public getPosZ()
--
-- Get the Z position.

getPosZ = function ()
  checkInit()
  return position.z
end

-------------------------------------------------------------------------------
-- @function public getPosition()
--
-- Get the position vector.

getPosition = function ()
  checkInit()
  return position
end

-- ============================================================================
-- PRIVATE functions ----------------------------------------------------------

-------------------------------------------------------------------------------
-- @function private log()
--
-- Log system with severity.
-- This function makes easier to change how turtles print messages. We change
-- the color based on the severity argument.
--
-- @arg String message
--   Message to be logged.
-- @arg Integer severity
--   One of the log constants that tells the severity of the message.

local function log(message, severity)
  local severity = severity or LOG_NOTICE
  local colorOld = term.getTextColor()
  local color

  if severity == LOG_NOTICE then
    color = colors.white
  elseif severity == LOG_WARNING then
    color = colors.yellow
  elseif severity == LOG_ERROR then
    color = colors.red
  elseif severity == LOG_DEBUG then
    color = colors.green
  end

  term.setTextColor(color)
  print(message)
  term.setTextColor(colorOld)
end

-------------------------------------------------------------------------------
-- @function private saveState()
--
-- Saving state.

local function saveState()
  local f, data
  f = fs.open(FILE_STATE , "w")
  data = {
    "position" = position
    "direction" = direction
    "inventory" = inventory
  }
  f.write(textutils.serializeJSON(data))
  f.close()
end

-------------------------------------------------------------------------------
-- @function private loadState()
--
-- Loading state.

local function loadState()
  local f, x, y, z, data
  if not fs.exists(FILE_STATE) then
    return false
  end
  f = fs.open(FILE_STATE, "r")
  data = textutils.unserializeJSON(f.readAll())
  position = data["position"]
  direction = data["direction"]
  inventory = data["inventory"]
  f.close()
  return true
end

-------------------------------------------------------------------------------
-- @function private updateLocation()
--
-- After every sideways (x,y) move, we update the location track variables.

local function updateLocation()
  if direction == DIRECTION_NORTH then
    -- z = z - 1
    position:add(vector.new(0, 0, -1))
  elseif direction == DIRECTION_SOUTH then
    -- z = z + 1
    position:add(vector.new(0, 0, 1))
  elseif direction == DIRECTION_EAST then
    -- x = x + 1
    position:add(vector.new(1, 0, 0))
  elseif direction == DIRECTION_WEST then
    -- x = x - 1
    position:add(vector.new(-1, 0, 0))
  else
    log("updateLocation() Invalid facing direction (" .. facing .. ")", LOG_ERROR)
  end
end

-------------------------------------------------------------------------------
-- @function private updateHeight()
--
-- After every height change, we update the location track variable.

local function updateHeight(str)
  if str == DIRECTION_DOWN then
    -- y = y - 1
    position:add(vector.new(0, -1, 0))
  elseif str == DIRECTION_UP then
    -- y = y + 1
    position:add(vector.new(0, 1, 0))
  else
    log("updateHeight() Invalid height direction (" .. str .. ")", LOG_ERROR)
  end
end

-------------------------------------------------------------------------------
-- @function private checkInit()
--
-- Check if turtle was initialized.

local function checkInit()
  if not haveInit then
    log("checkInit() - Turtle not initialized", LOG_ERROR)
    error()
    return false
  end
  return true
end

-- ============================================================================
-- PUBLIC functions -----------------------------------------------------------

-------------------------------------------------------------------------------
-- @function refuel()
--
-- Perform the refuel action using the enderchest. We check if there is space
-- for the chest to be placed and use the last inventory slot to suck the fuel.

refuel = function ()
  checkInit()

  -- Check if position in front is free for the fuel chest.
  if turtle.detect() then
    while not isBreakable("front") do
      sleep(2)
    end
    if not turtle.dig() then
      log('Bedrock stop - refuel()', LOG_ERROR)
    return
    end
  end

  turtle.select(inventory[1])
  turtle.place()
  turtle.select(16)
  turtle.suck(64)
  turtle.refuel(64)
  log('Fuel level: ' .. turtle.getFuelLevel(), LOG_NOTICE)
  turtle.select(TURTLE_SLOT_FUEL)
  turtle.dig()
  turtle.select(TURTLE_SLOT_INVENTORY)

  if turtle.getFuelLevel() == 0 then
    log("Could NOT refuel.", LOG_ERROR)
    error()
    return false
  end
  return true
end

-------------------------------------------------------------------------------
-- @function checkFuel()
--
-- Check fuel levels.
checkFuel = function ()
  checkInit()

  if turtle.getFuelLevel() < 20 then
    log("Fuel is almost over. Refueling!", LOG_NOTICE)
    refuel()
  end
end

-------------------------------------------------------------------------------
-- @function public registerInventory()
--
-- Register an inventory slot for restricted use.

registerInventory = function (label)
  checkInit()

  if getn(inventory) >= 15 then
    log("registerInventory() No available free slots.", LOG_ERROR)
    return false
  end
  for index, name in pairs(inventory) do
    if name == "free" then
      inventory[index] = label
      inventory[index + 1] = "free"
      return true
    end
  end
  log("registerInventory() Free slot not found", LOG_ERROR)
  return false
end

-------------------------------------------------------------------------------
-- @function public selectInventory()
--
-- Select the slot of a registed inventory.
selectInventory = function (label)
  checkInit()

  for index, name in pairs(inventory) do
    if name == label then
      turtle.select(index)
      return true
    end
  end
  log("selectInventory() Free slot not found", LOG_ERROR)
  return false
end

-------------------------------------------------------------------------------
-- @function public selectFreeInventory()
--
-- Select the slot of the free inventory beginning.
selectFreeInventory = function ()
  checkInit()
  return selectInventory("free")
end

-------------------------------------------------------------------------------
-- @function unloadInventory()
--
-- Unload free inventory slots to an enderchest.
unloadInventory = function ()
  local freeInventory = selectFreeInventory()
  local unloadInventory = selectInventory("unload")

  checkInit()

  -- If we have a turtle or unpermitted block, wait.
  while not isBreakable do
    log("unloadInventory() Top blocked. Waiting 2 sec to try again.")
    sleep(2)
  end

  -- Place enderchest.
  turtle.select(unloadInventory)
  turtle.digUp()
  turtle.placeUp()

  -- Unload free inventory slots.
  for i = freeInventory, 16 do
    turtle.select(i)
    turtle.dropUp()
  end

  -- Retrieve enderchest.
  turtle.select(unloadInventory)
  turtle.digUp()
  turtle.select(freeInventory)
end

-------------------------------------------------------------------------------
-- @function checkInventory()
--
-- Check if inventory is full.
-- 
-- This will check all inventory slots after the free slot. Any empty slot will
-- result in "not full". This will unload if all slots have at least 1 item.
-- Since we have a lot of slot check, this function is slow. Refer to function
-- quickCheckInventory() for faster check.

checkInventory = function ()
  local freeInventory = selectFreeInventory()
  local result = true

  checkInit()

  -- Check all free slots.
  for i = freeInventory, 16 do
    turtle.select(i)
    item = turtle.getItemCount(i)
    if item == 0 then
      result = false
      break
    end
  end

  -- If all slots have items, unload.
  if result then
    unloadInventory()
  end

  turtle.select(freeInventory)
  return result
end

-------------------------------------------------------------------------------
-- @function quickCheckInventory()
--
-- Check inventory status by only checking the last slot. If empty the inventory
-- is not full. When last slot have at least 1 item, it is full and unload.

quickCheckInventory = function ()
  local result = true

  checkInit()

  turtle.select(16)
  item = turtle.getItemCount(16)

  if item == 0 then
    result = false
  else
    unloadInventory()
  end

  turtle.select(TURTLE_SLOT_INVENTORY)
  return result
end

-------------------------------------------------------------------------------
-- @function isBreakable()
--
-- Check if block on a specific side is breakable to prevent destruction of
-- important blocks.

isBreakable = function (side)
  local success, data

  checkInit()

  -- Check the requested side.
  if side == "up" then
    success, data = turtle.inspectUp()quickCheckInventory                               
  elseif side == "down" then
    success, data = turtle.inspectDown()
  else
    success, data = turtle.inspect()
  end

  -- If no block, is breakable.
  if success == false then
    return true
  end

  -- Unbleakable blocks.
  if data.name == "computercraft:turtle" or
      data.name == "computercraft:turtle_advanced" or
      data.name == "enderstorage:ender_chest" or
      data.name == "chickenchunks:chunk_loader" then
    return false
  end

  -- If not any registered unbreakable blocks, is breakable.
  return true
end

-------------------------------------------------------------------------------
-- MOVING FUNCTIONS -----------------------------------------------------------

-------------------------------------------------------------------------------
-- @function public forward()
--
-- Move the turtle forward breaking blocks, attacking entities and refuel if 
-- needed. If there is an unbreakable block the move fails.
--
-- @return Boolean
--   False if reached unbreakable block, true otherwise.

forward = function ()
  local max = 50
  local success

  checkInit()

  success = turtle.forward()

  while not success do
    -- Fuel low.
    if turtle.getFuelLevel() < 20 then
      log("Fuel is almost over. Refueling!", LOG_NOTICE)
      refuel()
  
    -- Mob on the way.
    elseif turtle.attack() then
      log("Mob on my way. Die!", LOG_NOTICE)
      repeat
        sleep(1)
      until not turtle.attack()

    -- Unbreakable blocks.
    elseif not isBreakable("front") then
      log("Unbreakable block in front!", LOG_WARNING)
      return false

    -- Block on the way.
    else
      log("Block on the way. Dig!", LOG_NOTICE)
      if not turtle.dig() then
        log("Hit bedrock", LOG_ERROR)
        return false
      end
    end

    success = turtle.forward()
  
    -- Timeout limit on the loops.
    max = max - 1
    if max <= 0 then
      log("Timeout on forward()", LOG_ERROR)
      return false
    end
  end

  updateLocation()
  return true  
end

-- Alias - forward()
f = forward

-------------------------------------------------------------------------------
-- @function public down()
--
-- Move the turtle down, digging if block is bellow, attacking if entity,
-- refuel if needed and checking for bedrock.
--
-- @return Boolean
--   False if bedrock is reached, true otherwise.

down = function ()
  local max = 30
  local success

  checkInit()

  success = turtle.down()

  while not success do
    -- Fuel low.
    if turtle.getFuelLevel() < 20 then
      log("up() - Fuel is almost over. Refueling!", LOG_NOTICE)
      refuel()

    -- Mob on the way.
    elseif turtle.attackDown() then
      log("up() - Mob on my way. Die!", LOG_NOTICE)
      local isAttacking
      repeat
        sleep(1)
      until not turtle.attackDown()

    -- Unbleakable on the way.
    elseif not isBreakable("down") then
      log("Unbreakable block in front!", LOG_WARNING)
      return false

    -- Block on the way.
    elseif turtle.detectDown() then
      log("Block on the way. Dig!", LOG_NOTICE)
      if not turtle.digDown() then
        log("Hit bedrock", LOG_ERROR)
        return false
      end
    end

    success = turtle.down()
  
    -- Timeout limit on the loops.
    max = max - 1
    if max <= 0 then
      log("Timeout on down()", LOG_ERROR)
      return false
    end
  end

  updateHeight(DIRECTION_DOWN)
  return true
end

-------------------------------------------------------------------------------
-- @function public up()
--
-- Move the turtle up, digging if any block above, attacking if entity,
-- refuel if needed and checking for bedrock.
--
-- @return Boolean
--   False if bedrock is reached, true otherwise.

up = function ()
  local max = 30
  local success

  checkInit()

  success = turtle.up()

  while not success do
    -- Fuel low.
    if turtle.getFuelLevel() < 20 then
      log("up() - Fuel is almost over. Refueling!")
      refuel()

    -- Mob on the way.
    elseif turtle.attackUp() then
      log("up() - Mob on my way. Die!")
      local isAttacking
      repeat
        sleep(1)
      until not turtle.attackUp()

    -- Unbleakable on the way.
    elseif not isBreakable("up") then
      log("Unbreakable block in front!", LOG_WARNING)
      return false

    -- Block on the way.
    elseif turtle.detectUp() then
      log("Block on the way. Dig!")
      if not turtle.digUp() then
        log("Hit bedrock", LOG_ERROR)
        return false
      end
    end

    success = turtle.up()

    -- Timeout limit on the loops.
    max = max - 1
    if max <= 0 then
      log("Timeout on up()", LOG_ERROR)
      return false
    end
  end

  updateHeight(DIRECTION_UP)
  return true
end

-------------------------------------------------------------------------------
-- @function public left()
--
-- Turn turtle to the left.

left = function ()
  local success
  --print("turnLeft() facing=", facing," direction")

  checkInit()

  success = turtle.turnLeft()

  -- If could NOT turn.
  if not success then
    return false
  end
 
  -- Update facing direction.
  if direction == DIRECTION_NORTH then
    direction = DIRECTION_WEST
  elseif direction == DIRECTION_SOUTH then
    direction = DIRECTION_EAST
  elseif direction == DIRECTION_EAST then
    direction = DIRECTION_NORTH
  elseif direction == DIRECTION_WEST then
    direction = DIRECTION_SOUTH
  else
    -- Invalid facing direction.
    log("left() - Invalid facing direction (" .. direction .. ")", LOG_ERROR)
    error()
  end

  return true
end

-------------------------------------------------------------------------------
-- @function public right()
--
-- Turn turtle to the right.

right = function ()
  local success
  --print("turnRight() facing=", facing," direction")

  checkInit()

  success = turtle.turnRight()

  -- If could NOT turn.
  if not success then
    return false
  end

  -- Update facing direction.
  if direction == DIRECTION_NORTH then
    direction = DIRECTION_EAST
  elseif direction == DIRECTION_SOUTH then
    direction = DIRECTION_WEST
  elseif direction == DIRECTION_EAST then
    direction = DIRECTION_SOUTH
  elseif direction == DIRECTION_WEST then
    direction = DIRECTION_NORTH
  else 
    log("right() - Invalid facing direction (" .. direction .. ")", LOG_ERROR)
    error()
  end

  return true
end

-------------------------------------------------------------------------------
-- @function public turnAround()
--
-- Turn turtle around.

turnAround = function ()
  left()
  left()
end

-------------------------------------------------------------------------------
-- @function public turnTo(dir)
--
-- Turn to the argument direction. This is based on initial conditions. Initial
-- facing direction is always north.
--
-- @arg Integer dir
--   One of the direction constants.
-- @return Boolean
--   Return false if turning or facing directions are invalid and true
--   otherwise.

turnTo = function (dir)
  checkInit()

  if dir == DIRECTION_NORTH then
    if direction == DIRECTION_NORTH then
      return true
    elseif direction == DIRECTION_SOUTH then
      right()
      right()
    elseif direction == DIRECTION_EAST then
      left()
    elseif direction == DIRECTION_WEST then
      right()
    else
      log("Invalid facing direction - turnTo(dir) " .. facing, LOG_ERROR)
      error()
      return false
    end
  elseif dir == DIRECTION_SOUTH then
    if direction == DIRECTION_SOUTH then
      return true
    elseif direction == DIRECTION_NORTH then
      right()
      right()
    elseif direction == DIRECTION_WEST then
      left()
    elseif direction == DIRECTION_EAST then
      right()
    else
      log("Invalid facing direction - turnTo(dir) " .. facing, LOG_ERROR)
      error()
      return false
    end
  elseif dir == DIRECTION_WEST then
    if direction == DIRECTION_WEST then
      return true
    elseif direction == DIRECTION_EAST then
      right()
      right()
    elseif direction == DIRECTION_NORTH then
      left()
    elseif direction == DIRECTION_SOUTH then
      right()
    else
      log("Invalid facing direction - turnTo(dir) " .. facing, LOG_ERROR)
      error()
      return false
    end
  elseif dir == DIRECTION_EAST then
    if direction == DIRECTION_EAST then
      return true
    elseif direction == DIRECTION_WEST then
      right()
      right()
    elseif direction == DIRECTION_SOUTH then
      left()
    elseif direction == DIRECTION_NORTH then
      right()
    else
      log("Invalid facing direction - turnTo(dir) " .. facing, LOG_ERROR)
      error()
      return false
    end
  else
    log("Invalid goto direction - turnTo(dir) " .. dir, LOG_ERROR)
    error()
    return false
  end
  return true
end

-------------------------------------------------------------------------------
-- @function public gpsCheck()
--
-- Check turtle position based on GPS information.

gpsCheck = function ()
  local diff
  local success, gpsPosition = getGPS()

  checkInit()

  -- Check if we had GPS response.
  if not success or gpsPosition == nil then
    -- log("Could not get GPS position.", LOG_WARNING)
    return false
  end

  -- Check if current position is the same of the GPS.
  if position:equals(gpsPosition) then
    -- log("Position correct.", LOG_DEBUG)
    return true
  end

  log("Wrong location. Correcting with GPS.", LOG_WARNING)
  position = gpsPosition
  return true
end

-------------------------------------------------------------------------------
-- @function public getGPS()
--
-- Get GPS coordinates.

getGPS = function ()
  local x, y, z = gps.locate(2)
  local pos = vector.new(x, y, z)

  -- A new GPS request with heigher timeout if first failed.
  if pos == nil then
    x, y, z = gps.locate(10)
    pos = vector.new(x, y, z)

    if pos == nil then
      -- GPS not found.
      haveGPS = false
      log("Could not get GPS position.", LOG_ERROR)
      return false, nil
    end
  end

  log("GPS = " .. pos:tostring(), LOG_DEBUG)
  return true, pos
end

-------------------------------------------------------------------------------
-- @function public getDirection()
--
-- Get turtle facing direction using GPS.

getDirection = function ()
  local pos1, pos2, success1, success2, diff

  -- Make sure we have fuel to move.
  checkFuel()

  -- Get first position.
  success1, pos1 = getGPS()

  -- Check if we can move forward.
  while not turtle.forward() do
    if isBreakable("front") then
      turtle.dig()
    end
    sleep(2)
  end

  -- Get second position. 
  success2, pos2 = getGPS()
  turtle.back()

  -- If any of the GPS calls returned false.
  if not success1 and not success2 then
    log("GPS position not found.", LOG_ERROR)
    return false, nil
  end

  -- Get diff vector to access direction.
  diff = pos1:sub(pos2)

  if diff.x == 1 then
    return true, DIRECTION_WEST
  elseif diff.x == -1 then
    return true, DIRECTION_EAST
  elseif diff.z == 1 then
    return true, DIRECTION_NORTH
  elseif diff.z == -1 then
    return true, DIRECTION_SOUTH
  end

  return false, nil
end

-------------------------------------------------------------------------------
-- @function nforward()
--
-- Go to specified coordinates.

nforward = function (n)
  local success, i, tries

  checkInit()

  tries = 3
  n = math.abs(n)

  for i = 1, n do
    success = forward()

    -- If could NOT move forward.
    if not success then
      -- If we have space, go around.
      if i <= n - 2 then
        turnLeft()
        forward()
        turnRight()
        sleep(math.random(1, 3))
        forward()
        forward()
        turnRight()
        forward()
        turnLeft()
        i = i + 2
      -- If we do NOT have space, just wait before failing.
      else
        turnLeft()
        forward()
        turnAround()
        sleep(math.random(2, 5))
        forward()
        turnRight()
        tries = tries - 1

        -- After a number of tries, return false.
        if tries == 0 then
          turnLeft()
          forward()
          turnRight()
          forward()
          forward()
          return false
        end
      end
    end
  end

  return true
end

-------------------------------------------------------------------------------
-- @function getChunkOrigin()
--
-- Get current chunk (0, X, 0) coordinates.

getChunkOrigin = function ()
  local posx, posz

  if not haveGPS then
    return false
  end

  posx = math.modf(position.x/16)
  poxz = math.modf(position.z/16)
  return vector.new(posx * 16, position.y, posz * 16)
end

-------------------------------------------------------------------------------
-- @function moveTo(posx, posy)
--
-- Go to specified coordinates.

moveTo = function (destination)
  local moveVector, i, pos, rand, success

  checkInit()

  -- If destination is not set.
  if destination == nil then 
    log("moveTo() - Destination not set.", LOG_ERROR)
    return false
  end

  -- If destination is the same as current position.
  if destination:equals(position) then
    return true
  end

  -- Calculate move vector.
  moveVector = destination:sub(position)

  -- @@@ Y axis.
  if moveVector.y > 0 then
    for i = 1, moveVector.y do
      up()
    end
  elseif moveVector.y < 0 then
    for i = 1, math.abs(moveVector.y) do
      down()
    end
  end

  -- Random first axis move.
  rand = math.random(0, 1)

  -- @@@ X axis (random).
  if rand == 1 then
    if moveVector.x > 0 then
      turnTo(DIRECTION_EAST)
    elseif moveVector.x < 0 then
      turnTo(DIRECTION_WEST)
    end

    success = nforward(moveVector.x)

    -- If move failed, try again.
    if not success then
      return moveTo(destination)
    end
  end

  -- @@@ Z axis.
  if moveVector.z > 0 then
    turnTo(DIRECTION_SOUTH)
  elseif moveVector.z < 0 then
    turnTo(DIRECTION_NORTH)
  end

  success = nforward(moveVector.z)

  -- If move failed, try again.
  if not success then
    return moveTo(destination)
  end

  -- @@@ X axis (random).
  if rand == 0 then
    if moveVector.x > 0 then
      turnTo(DIRECTION_EAST)
    elseif moveVector.x < 0 then
      turnTo(DIRECTION_WEST)
    end

    success = nforward(moveVector.x)

    -- If move failed, try again.
    if not success then
      return moveTo(destination)
    end
  end

  -- Make sure position is correct with GPS.
  if haveGPS then
    gpsCheck()
  end

  -- It's not on the correct destination.
  while not position:equals(destination) do
    log("Position dont match destination.", LOG_WARNING)
    sleep(1)
    moveTo(destination)
  end

  return true
end

-------------------------------------------------------------------------------
-- @function public init()
--
-- Initialize turtle.

init = function ()
  local success, timeout, isStateLoaded

  isStateLoaded = loadState()

  -- Set position with GPS.
  log ("Set position", LOG_DEBUG)
  success, position = getGPS()

  timeout = 0
  while position == nil do
    success, position = getGPS()
    sleep(5)
    timeout = timeout + 1
    if timeout > 10 then
      haveGPS = false
      if not isStateLoaded then
        position = vector.new(0, 0, 0)
        direction = DIRECTION_NORTH
      end
      return false
    end
  end
  log ("init() - Position = " .. position:tostring(), LOG_DEBUG)

  -- Set facing direction.
  log ("Set facing", LOG_DEBUG)
  direction = getDirection()
  timeout = 0

  while direction == nil do
    direction = getDirection()
    sleep(5)
    timeout = timeout + 1
    if timeout > 10 then
      haveGPS = false
      if not isStateLoaded then
        position = vector.new(0, 0, 0)
        direction = DIRECTION_NORTH
      end
      return false
    end
  end
  log ("init() - Direction = " .. facing, LOG_DEBUG)

  -- Confirm turtle initialization to unblock other functions.
  haveInit = true

  return position ~= nil and facing ~= nil
end
