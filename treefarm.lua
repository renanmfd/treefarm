-- @file treefarm.lua

os.loadAPI("bturtle")

bturtle.init()

local pos = bturtle.getPosition()
pos.x = pos.x + 10

moveTo(pos)
