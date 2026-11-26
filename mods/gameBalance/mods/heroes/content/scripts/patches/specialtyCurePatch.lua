local Script = setmetatable({}, {__index = Base})
Script.__index = Script

function Script:getHealAmount(mechanics, unit, server)
	local value = mechanics:applySpellBonus(mechanics:getEffectValue(), unit)
	local hero = mechanics:getHeroCaster()
	if hero and mechanics:getSpell():getJsonKey() == "core:cure" then
		local tier = math.min(math.max(unit:creatureLevel(), 1), 7)
		local specialtyValue = hero:getBonusesValue({ type = "SPECIALTY_CURE" })

		if specialtyValue ~= 0 then
			local percent = specialtyValue * math.floor(hero:getLevel() / (8 - tier))
			value = math.max(math.floor(value * (100 + percent) / 100), 0)
		end

		return value
	end
	if self.minValue and server ~= nil and value > self.minValue then
		return server:rngInt(self.minValue, math.floor(value))
	end
	return value
end

return Script