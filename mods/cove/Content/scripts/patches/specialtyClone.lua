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

	local specialtyCharges = 0
    for i = 1, filteredHeroBonuses:size() do
        specialtyCharges = specialtyCharges + filteredHeroBonuses:getBonus(i):getVal()
    end

	return specialtyCharges > 0
end

function Script:apply(mechanics, server, target)
    if shouldCastSpecialtyClone(mechanics) then
		server:addBattleBonus(mechanics:getBattle(), {
			type       = "SPECIALTY_CLONE",
			sourceType = ENUM.BonusSource.other,
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