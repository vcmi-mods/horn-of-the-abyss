local Base = require("combat/combatScript")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

function Script:castDevourCorpses(server, battle, unit)
	local frontHex = unit:getPosition()
	local deadUnitsOnPos = battle:getUnitsIf(function(target)
		return target:isDead() and not target:isGhost() and target:coversPos(frontHex)
	end)

	if #deadUnitsOnPos == 0 then
		return
	end

	for i = 1, #deadUnitsOnPos do
		server:removeUnit(battle, deadUnitsOnPos[i])
		server:addUnitBonus(battle, unit, {
        duration   = ENUM.BonusDuration.oneBattle,
        type       = "ADDITIONAL_ATTACK",
        sourceType = ENUM.BonusSource.creatureAbility,
        sourceID   = unit:getCreature():getJsonKey(),
        val        = 1
		}, false)
	end
	server:refreshBattleUnits(battle)
end

function Script:onBeforeAttack(server, battle, unit, other, payload)
	if payload.isCounter then return end
	if payload.attackIndex > 0 then return end
	self:castDevourCorpses(server, battle, unit)
end

function Script:onAfterAttack(server, battle, unit, other, payload)
	if payload.attackIndex == 0 then return end
	local creatureKey = unit:getCreature():getJsonKey()
	local devourCorpsesAttacks = unit:getBonuses(function(bonus)

		return bonus:getType() == "ADDITIONAL_ATTACK" and bonus:getSourceID() == creatureKey
	end)
	if devourCorpsesAttacks:size() == 1 then
		server:removeUnitBonuses(battle, unit, devourCorpsesAttacks)
	elseif devourCorpsesAttacks:size() > 1 then
		server:removeUnitBonuses(battle, unit, { devourCorpsesAttacks:get(1) })
	end
end

function Script:onAfterMove(server, battle, unit, other, payload)
	self:castDevourCorpses(server, battle, unit)
	local creatureKey = unit:getCreature():getJsonKey()
	local devourCorpsesAttacks = unit:getBonuses(function(bonus)
		return bonus:getType() == "ADDITIONAL_ATTACK" and bonus:getSourceID() == creatureKey
	end)
end

return Script