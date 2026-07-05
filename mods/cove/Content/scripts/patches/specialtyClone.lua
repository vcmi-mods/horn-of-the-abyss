local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local totalSpecialtyCastsThisBattle = {0, 0, 0, 0, 0, 0, 0, 0}

function Script:apply(mechanics, server, target)
    local caster = mechanics:getHeroCaster()
	local casterID = caster:getOwner() + 1

    if not caster then
        Base.apply(self, mechanics, server, target)
        return
    end

    local filteredHeroBonuses = caster:getBonuses(function(bonus)
        return bonus:getType() == "SPECIALTY_CLONE"
    end)

    local totalHeroCharges = 0
    for i = 1, filteredHeroBonuses:size() do
        local bonus = filteredHeroBonuses:getBonus(i)
        totalHeroCharges = totalHeroCharges + bonus:getVal()
    end

    local remainingCharges = totalHeroCharges - totalSpecialtyCastsThisBattle[casterID]
	
    if remainingCharges > 0 then
        totalSpecialtyCastsThisBattle[casterID] = (totalSpecialtyCastsThisBattle[casterID] or 0) + 1
        Base.apply(self, mechanics, server, target)
        Base.apply(self, mechanics, server, target)
    else
        Base.apply(self, mechanics, server, target)
    end
end

return Script