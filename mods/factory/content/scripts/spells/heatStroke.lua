local Base = require("spells/unitEffect")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local function getConeHexes(mechanics, sourceHex, centerTargetHex)
    local affected = { centerTargetHex }

    local leftHex = centerTargetHex:copyToWest()
    local rightHex = centerTargetHex:copyToEast()

    if leftHex then table.insert(affected, leftHex) end
    if rightHex then table.insert(affected, rightHex) end

    return affected
end

local function getAffectedHexes(casterPos, direction)
	local hexes = {}
	if direction == 0 then
		local first = casterPos:copyToEast()
		local second = casterPos:copyToNorthEast()
		local last = casterPos:copyToSouthEast()
		hexes[1] = first
		hexes[2] = second
		hexes[3] = last
		hexes[4] = first:copyToEast()
		hexes[5] = first:copyToNorthEast()
		hexes[6] = first:copyToSouthEast()
		hexes[7] = second:copyToNorthEast()
		hexes[8] = last:copyToSouthEast()
		return hexes
	elseif direction == 1 then
		local first = casterPos:copyToEast()
		local second = first:copyToSouthWest()
		local last = second:copyToWest()
		hexes[1] = first
		hexes[2] = second
		hexes[3] = last
		hexes[4] = first:copyToEast()
		hexes[5] = first:copyToSouthEast()
		hexes[6] = second:copyToSouthEast()
		hexes[7] = second:copyToSouthWest()
		hexes[8] = last:copyToSouthWest()
		return hexes
	elseif direction == 2 then
		local first = casterPos:copyToSouthWest()
		local second = first:copyToEast()
		local last = first:copyToWest()
		hexes[1] = first
		hexes[2] = second
		hexes[3] = last
		hexes[4] = first:copyToSouthEast()
		hexes[5] = first:copyToSouthWest()
		hexes[6] = second:copyToSouthEast()
		hexes[7] = last:copyToSouthWest()
		return hexes
	elseif direction == 3 then
		local first = casterPos:copyToSouthWest()
		local second = first:copyToWest()
		local last = second:copyToNorthWest()
		hexes[1] = first
		hexes[2] = second
		hexes[3] = last
		hexes[4] = first:copyToSouthWest()
		hexes[5] = first:copyToSouthEast()
		hexes[6] = second:copyToWest()
		hexes[7] = second:copyToSouthWest()
		hexes[8] = last:copyToWest()
		return hexes
	elseif direction == 4 then
		local first = casterPos:copyToWest():copyToWest()
		local second = first:copyToNorthEast()
		local last = first:copyToSouthEast()
		hexes[1] = first
		hexes[2] = second
		hexes[3] = last
		hexes[4] = first:copyToWest()
		hexes[5] = first:copyToNorthWest()
		hexes[6] = first:copyToSouthWest()
		hexes[7] = second:copyToNorthWest()
		hexes[8] = last:copyToSouthWest()
		return hexes
	elseif direction == 5 then
		local second = casterPos:copyToNorthWest()
		local first = second:copyToWest()
		local last = first:copyToSouthWest()
		hexes[1] = first
		hexes[2] = second
		hexes[3] = last
		hexes[4] = first:copyToWest()
		hexes[5] = first:copyToNorthEast()
		hexes[6] = first:copyToNorthWest()
		hexes[7] = second:copyToNorthEast()
		hexes[8] = last:copyToWest()
		return hexes
	elseif direction == 6 then
		local first = casterPos:copyToNorthWest()
		local second = casterPos:copyToNorthEast()
		local last = first:copyToWest()
		hexes[1] = first
		hexes[2] = second
		hexes[3] = last
		hexes[4] = first:copyToNorthWest()
		hexes[5] = first:copyToNorthEast()
		hexes[6] = second:copyToNorthEast()
		hexes[7] = last:copyToNorthWest()
		return hexes
	elseif direction == 7 then
		local first = casterPos:copyToNorthEast()
		local second = casterPos:copyToNorthWest()
		local last = casterPos:copyToEast()
		hexes[1] = first
		hexes[2] = second
		hexes[3] = last
		hexes[4] = first:copyToNorthWest()
		hexes[5] = first:copyToNorthEast()
		hexes[6] = first:copyToEast()
		hexes[7] = second:copyToNorthWest()
		hexes[8] = last:copyToEast()
		return hexes
	end

	return hexes
end

local function getHexDirection(castX, castY, destX, destY)
    local dx = destX - castX
    local dy = destY - castY

    -- Even rows are shifted right
    if castY % 2 == 0 then
        dx = dx - 0.5
    end

    if destY % 2 == 0 then
        dx = dx + 0.5
    end

    local angle = math.deg(math.atan2(dy, dx))
    if angle < 0 then
        angle = angle + 360
    end

    -- Convert to 8 directions
    return math.floor((angle + 22.5) / 45) % 8
end

function Script:transformTarget(mechanics, aimPoint, spellTarget)
	local ret = {}
	local battle = mechanics:getBattle()
	local casterUnit = mechanics:getUnitCaster()
	local sourceHex = casterUnit:getPosition()
	local leftHex = sourceHex:copyToWest()
	local rightHex = sourceHex:copyToEast()

	table.insert(ret, { hex = leftHex, unit = battle:getUnitByPos(leftHex, true) })
	table.insert(ret, { hex = rightHex, unit = battle:getUnitByPos(rightHex, true) })

    return ret
end

function Script:adjustAffectedHexes(mechanics, hexes, spellTarget)
	if #spellTarget == 0 then return end
	local hex = spellTarget[1].hex
	local caster = mechanics:getUnitCaster():getPosition()
	local pattern = getAffectedHexes(caster, getHexDirection(caster:getX(), caster:getY(), hex:getX(), hex:getY()))
	for _, h in ipairs(pattern) do
		if h:isValid() then
			hexes:insert(h)
		end
	end
	return hexes
end

function Script:applicableGeneral(mechanics, problem)
	return true
end

function Script:applicableTarget(mechanics, problem, target)
	return true
end

function Script:apply(mechanics, server, target)
    return
end

return Script