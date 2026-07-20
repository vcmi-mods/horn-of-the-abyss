local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local function applyHeroSpecialty(mechanics, unit)
	local base = mechanics:getEffectValue()
	local hero = mechanics:getHeroCaster()

	if not hero then return base end
	if mechanics:getSpell():getJsonKey() ~= "core:cure" then return base end

	local tier = math.min(math.max(unit:creatureLevel(), 1), 7)

	local specialty = hero:getBonuses(function(b)
		return b:getType() == "SPECIALTY_CURE"
	end)
	if specialty:size() > 0 then
		local increments = math.floor(specialty:getBonus(1):getVal() / (8 - tier))
		base = math.floor(base * (1 + (increments * 0.10)))
	end

	return base
end

function Script:getHealthChange(mechanics, spellTarget)
	local result = { hpDelta = 0, unitsDelta = 0 }
	for _, dest in ipairs(spellTarget) do
		local unit = dest.unit
		if unit then
			local copy = unit:copy()
			local effectValue = applyHeroSpecialty(mechanics, unit)
			local healedHP, resurrected = copy:heal(effectValue, self:getHealLevel(), self:getHealPower())
			result.hpDelta   = result.hpDelta   + healedHP
			result.unitsDelta = result.unitsDelta + resurrected
			result.unitType  = unit:getCreature()
		end
	end
	return result
end

function Script:apply(mechanics, server, target)
	local battle       = mechanics:getBattle()
	local isUnitCaster = mechanics:getHeroCaster() == nil

	for _, dest in ipairs(target) do
		local unit = dest.unit
		if unit then
			local effectValue = applyHeroSpecialty(mechanics, unit)
			local healedHP, resurrected = server:healUnit(
				battle, unit, effectValue, self:getHealLevel(), self:getHealPower())

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
end

return Script