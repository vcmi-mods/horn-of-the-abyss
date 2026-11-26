local Base = require("spells/unitEffect")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

function Script:getHealLevel(unit)
	return unit:hasBonuses({type = "HOTA_RING_OF_OBLIVION"}) and ENUM.HealLevel.heal or ENUM.HealLevel.resurrect
end

--- Only injured units are valid; without Ring of Oblivion also accept dead units.
function Script:isValidTarget(mechanics, unit)
	local level = self:getHealLevel(unit)
	local allowDead = level ~= ENUM.HealLevel.heal
	if not unit:isValidTarget(allowDead) then return false end

	local injuries
	if allowDead then
		injuries = unit:getTotalHealth() - unit:getAvailableHealth()
	else
		injuries = unit:getMaxHealth() - unit:getFirstHPleft()
	end
	if injuries <= 0 then return false end

	if unit:isDead() then
		local hexes = unit:getHexes()
		for i = 1, hexes:size() do
			local hex = hexes:at(i)
			local blockers = mechanics:getBattle():getUnitsIf(function(other)
				return other ~= unit and other:isValidTarget(false) and other:coversPos(hex)
			end)
			if #blockers > 0 then return false end
			if #mechanics:getBattle():getObstaclesOnPos(hex, true) > 0 then return false end
		end
	end

	return true
end

--- Returns HP and unit count change for hover tooltip.
function Script:getHealthChange(mechanics, spellTarget)
	local result = { hpDelta = 0, unitsDelta = 0 }
	local unit = spellTarget[1].unit

	if unit then
		local copy = unit:copy()
		local healedHP, resurrected = copy:heal(mechanics:applySpellBonus(mechanics:getEffectValue(), unit), self:getHealLevel(unit), ENUM.HealPower.permanent)
		result.hpDelta   = result.hpDelta   + healedHP
		result.unitsDelta = result.unitsDelta + resurrected
		result.unitType  = unit:getCreature()
	end

	return result
end

function Script:emitBattleLog(server, battle, caster, target, healedHP, resurrected)
	if not caster or healedHP <= 0 then return end
	local casterCount = caster:getCount()
	local targetCreature = target:getCreature()

	server:appendLog(battle, {
		append = { casterCount == 1 and self.messageSingular or self.messagePlural },
		replaceStrings = {
			caster:getCreature():getNameTextID(casterCount),
			targetCreature:getNameTextID(target:getBaseAmount())
		},
		replaceNumbers = { healedHP }
	})

	if resurrected > 0 then
		server:appendLog(battle, {
			append         = { resurrected == 1 and self.messageResurrectSingular or self.messageResurrectPlural },
			replaceStrings = { targetCreature:getNameTextID(resurrected) },
			replaceNumbers = { resurrected }
		})
	end
end

--- Heals the target unit and emits battle log messages.
function Script:apply(mechanics, server, target)
	local battle       = mechanics:getBattle()
	local unit = target[1].unit

	if unit then
		local healedHP, resurrected = server:healUnit(
			battle,
			unit,
			mechanics:applySpellBonus(mechanics:getEffectValue(), unit),
			self:getHealLevel(unit),
			ENUM.HealPower.permanent
		)

		self:emitBattleLog(server, battle, mechanics:getUnitCaster(), unit, healedHP, resurrected)
	end
end

return Script
