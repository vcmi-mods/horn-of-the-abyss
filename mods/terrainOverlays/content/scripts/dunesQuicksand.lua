local Base = require("spellEffect")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local function hexesFromArray(arr)
	local list = {}
	for i = 1, arr:size() do
		list[#list+1] = arr:at(i)
	end
	return list
end

local function isHexAvailable(battle, hex)
    if not hex:isAvailable() then return false end

    if battle:getUnitByPos(hex, true) ~= nil then return false end

    local obstacles = battle:getObstaclesOnPos(hex, false)
    if #obstacles > 0 then
        for _, o in ipairs(obstacles) do
            if o:getObstacleType() ~= ENUM.ObstacleType.moat then
                return false
            end
        end
    end

    return true
end

function Script:applicableGeneral(mechanics, problem)
	return true
end

function Script:applicableTarget(mechanics, problem, target)
	return true
end

function Script:apply(mechanics, server, target)
    local battle = mechanics:getBattle()
    local spell  = mechanics:getSpell()
    local patchCount = server:rngInt(15, 19)
    local available = {}
    for _, hex in ipairs(hexesFromArray(battle:getAllPossibleHexes())) do
        if isHexAvailable(battle, hex) then
            available[#available + 1] = hex
        end
    end

    for i = #available, 2, -1 do
        local j = server:rngInt(1, i)
        available[i], available[j] = available[j], available[i]
    end

    local toPlace = math.min(patchCount, #available)
    for i = 1, toPlace do
        local hex = available[i]
        local descriptor = {
            pos              = hex,
            obstacleType     = ENUM.ObstacleType.spellCreated,
            spell            = spell,
            casterSpellPower = mechanics:getEffectPower(),
            spellLevel       = mechanics:getEffectLevel(),
            casterSide       = -1,
            turnsRemaining   = -1,
            hidden           = false,
            passable         = true,
            nativeVisible    = false,
            trap             = true,
            removeOnTrigger  = false,
            appearSound      = "QUIKSAND",
            appearAnimation  = "C17SPE0",
            animation        = "C17SPE1"
        }

        server:addObstacle(battle, descriptor)
    end
end

return Script