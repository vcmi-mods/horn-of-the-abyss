local Base = require("combat/combatScript")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local ANIMATION = "hota/hornEffect/SP16.def"
local SOUND     = "SUMMBOAT"

--- Returns the raised creature stack
function Script:getRaisedStack(server, unit)
	local raisedCreature = LIBRARY:getCreatureByName(self.raisedCreature or "core:peasant")

	if unit:getCreature():getJsonKey() == raisedCreature:getJsonKey() then return nil end

	local maxAmount = math.floor(unit:getBaseAmount() / 2)
	local hpResurrected = math.floor(unit:getTotalHealth() / 2)
	local count = math.floor(hpResurrected / raisedCreature:getMaxHealth())

	count = math.min(count, maxAmount)
	if count <= 0 then return nil end

	local side = unit:getSide()

	if not unit:hasBonuses({ type = "HORN_OF_THE_ABYSS" }) then
		side = 1 - side
	end

	return {
		count    = count,
		type     = raisedCreature,
		side     = side,
		position = unit:getPosition(),
		summoned = false
	}
end

function Script:emitBattleLog(server, battle, raisedStack)
	local count = raisedStack.count
	if count <= 0 then return end

	local textID = count == 1 and "core.bonus.HORN_OF_THE_ABYSS.description.0" or "core.bonus.HORN_OF_THE_ABYSS.description.1"
	local nameTextID = raisedStack.type:getNameTextID(count)
	server:appendLog(battle, {
		append         = { textID },
		replaceNumbers = { count },
		replaceStrings = { nameTextID }
	})
end

function Script:onDeath(server, battle, unit, other, payload)
	if unit:isClone() then return end
	if unit:isSummoned() then return end

	local raisedStack = self:getRaisedStack(server, unit)

	if not raisedStack then return end

	server:showBattleAnimation(battle, { { unit = unit } }, ANIMATION, SOUND, 1.0, false)
	self:emitBattleLog(server, battle, raisedStack)
	server:addUnit(battle, raisedStack)
	server:removeUnit(battle, unit)
end

return Script
