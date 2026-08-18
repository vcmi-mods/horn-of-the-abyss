local Base = require("combat/combatScript")
local BattleLog = require("battleLog")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

--- Returns all affected units
function Script:getAffectedUnits(battle, unit)
	local affectedUnits = {}
	local uniqueUnits = {}
	local hexes = unit:getSurroundingHexes()

	for i = 1, hexes:size() do
		local hex = hexes:at(i)
    	local targetUnit = battle:getUnitByPos(hex, true)
		if targetUnit and targetUnit:unitID() ~= unit:unitID() then
			if not uniqueUnits[targetUnit] then
				local bonuses = targetUnit:getBonuses(function(bonus)
					return bonus:getType() == "INVINCIBLE"
				end)
				if bonuses:size() == 0 then
					uniqueUnits[targetUnit] = true
					table.insert(affectedUnits, targetUnit)
				end
			end
		end
	end

	return affectedUnits
end

--- Calculate the damage the explosion should do to each adjacent unit
function Script:getExplosionDamage(unit, killed)
	local baseDamage = 90 + 5 * killed

	return baseDamage
end

--- The entry of the payload describing the hit this unit took.
function Script:ownEntry(unit, payload)
	for _, target in ipairs(payload.targets or {}) do
		if target.unit and target.unit:unitID() == unit:unitID() then
			return target
		end
	end

	return nil
end

--- Called after `unit` was attacked by `other`
function Script:onAfterAttacked(server, battle, unit, other, payload)
	if unit:isAlive() then
		return
	end
	local entry = self:ownEntry(unit, payload)
	if entry and entry.killed > 0 then
		local damage = self:getExplosionDamage(unit, entry.killed)
		print(string.format("should do %d Damage", damage))
		local targets = self:getAffectedUnits(battle, unit)
		for _, target in ipairs(targets) do
			print(target:getCreature():getJsonKey())
		end
	end
end

return Script