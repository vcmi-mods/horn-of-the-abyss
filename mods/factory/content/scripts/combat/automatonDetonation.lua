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
		if targetUnit then
			local id = targetUnit:unitID()

			if id ~= unit:unitID() then
				if not uniqueUnits[id] then
					local bonuses = targetUnit:getBonuses(function(bonus)
						return bonus:getType() == "INVINCIBLE"
					end)
					if bonuses:size() == 0 then
						uniqueUnits[id] = true
						table.insert(affectedUnits, targetUnit)
					end
				end
			end
		end
	end

	return affectedUnits
end

--- Calculate the damage the explosion should do to each adjacent unit
function Script:getExplosionDamage(unit, killed)
	local baseDamage = 90 + 5 * killed
	local unitBonuses = unit:getBonuses(function(bonus)
		return bonus:getType() == "AUTOMATON_EXPLOSION_DAMAGE"
	end)

	if unitBonuses:size() == 0 then
		return baseDamage
	end

	local specialtyPercent = 100

	for i = 1, unitBonuses:size() do
		specialtyPercent = specialtyPercent + unitBonuses:getBonus(i):getVal()
	end

	baseDamage = math.ceil((baseDamage * specialtyPercent) / 100)
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

--- Plays the detonation death animation of 'unit' and damages all surrounding targets
function Script:processTriggerEvent(server, battle, unit, payload)
	if unit:isAlive() then return end
	local entry = self:ownEntry(unit, payload)

	if entry and entry.killed > 0 then
		local animation = unit:getCreature():getJsonKey() == "hota.factory:sentinelAutomaton" and "hota/factory/spells/detonationSentinel" or "hota/factory/spells/detonationAutomaton"
		server:showBattleAnimation(battle, { { unit = unit } }, animation, "hota/factory/creatures/automaton/AUTOSPEC", 1.0, true)
		local targets = self:getAffectedUnits(battle, unit)

		if #targets == 0 then return end
		local damage = self:getExplosionDamage(unit, entry.killed)
		local totalDamage, totalKilled = 0, 0

		for _, target in ipairs(targets) do
			local dealt, killed = server:damageUnit(battle, target, damage)
			totalDamage = totalDamage + dealt
			totalKilled = totalKilled + killed
		end

		local victim = #targets == 1 and targets[1] or nil
		local spell = LIBRARY:getSpellByName("abilityDetonation")
		BattleLog.spellDamage(server, battle, spell, victim, totalDamage, totalKilled)
	end
end

--- Called after `unit` was attacked by `other`
function Script:onAfterAttacked(server, battle, unit, other, payload)
	self:processTriggerEvent(server, battle, unit, payload)
end

--- TODO - add trigger for taking spell damage here and call processTriggerEvent like onAfterAttacked

return Script