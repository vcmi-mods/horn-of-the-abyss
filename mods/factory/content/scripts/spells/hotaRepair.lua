local Base = require("spells/heal")
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

	local injuries = unit:getTotalHealth() - unit:getAvailableHealth()
	if injuries <= 0 then return false end

	if unit:isDead() then
		local hexes = unit:getHexes()
		for i = 1, hexes:size() do
			local hex = hexes:at(i)
			local blockers = mechanics:getBattle():getUnitsIf(function(other)
				return other ~= unit and other:isValidTarget(false) and other:coversPos(hex)
			end)
			if #blockers > 0 then return false end
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

--- Heals the target unit and emits battle log messages.
function Script:apply(mechanics, server, target)
	local battle       = mechanics:getBattle()
	local isUnitCaster = mechanics:getHeroCaster() == nil

	local unit = target[1].unit
	if unit then
		local healedHP, resurrected = server:healUnit(
			battle, unit, mechanics:applySpellBonus(mechanics:getEffectValue(), unit), self:getHealLevel(unit), ENUM.HealPower.permanent)

		if resurrected > 0 then
			local textID = resurrected == 1 and "core.genrltxt.117" or "core.genrltxt.116"
			local nameTextID = unit:getCreature():getNameTextID(unit:getCount())
			server:appendLog(battle, {
				append         = { textID },
				replaceStrings = { nameTextID },
				replaceNumbers = { resurrected }
			})
		elseif healedHP > 0 and isUnitCaster then
			local casterUnit = mechanics:getUnitCaster()
			server:appendLog(battle, {
				append         = { "core.genrltxt.414" },
				replaceStrings = {
					casterUnit:getCreature():getNameTextID(1),
					unit:getCreature():getNameTextID(1)
				},
				replaceNumbers = { healedHP }
			})
		end
	end
end

return Script
