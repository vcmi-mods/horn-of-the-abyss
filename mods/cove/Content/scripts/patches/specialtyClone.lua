local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local function shouldCastSpecialtyClone(mechanics)
	local caster = mechanics:getHeroCaster()
	if not caster then
		return false
	end

	local filteredHeroBonuses = caster:getBonuses(function(bonus)
        return bonus:getType() == "SPECIALTY_CLONE"
    end)
	if filteredHeroBonuses:size() < 1 then
		return false
	end

	local specialtyCharges = 0
    for i = 1, filteredHeroBonuses:size() do
        local bonus = filteredHeroBonuses:getBonus(i)
        specialtyCharges = specialtyCharges + bonus:getVal()
    end
	if specialtyCharges == 0 then
		return false
	end

	return true
end

function Script:apply(mechanics, server, target)
    if shouldCastSpecialtyClone(mechanics) then
		server:addBattleBonus(mechanics:getBattle(), {
			type       = "SPECIALTY_CLONE",
			sourceType = ENUM.BonusSource.spellEffect,
			val        = -1,
			valueType  = 0,
			sourceID   = mechanics:getSpell():getJsonKey(),
			propagator = BONUS_OWNER_PROPAGATOR,
			limiters   = { noneOf, OPPOSITE_SIDE }
		})
        Base.apply(self, mechanics, server, target)
        Base.apply(self, mechanics, server, target)
    else
        Base.apply(self, mechanics, server, target)
    end
end

return Script