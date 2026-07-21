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
	if not shouldCastSpecialtyClone(mechanics) then
		Base.apply(self, mechanics, server, target)
		return
	end

	local battle = mechanics:getBattle()
	local casterSide = mechanics:getCasterSide()
	local isAttacker = (casterSide == 0)

	server:addBattleBonus(battle, {
		type       = "SPECIALTY_CLONE",
		sourceType = ENUM.BonusSource.other,
		val        = -1,
		valueType  = 0,
		sourceID   = mechanics:getSpell():getJsonKey()
	})

	for _, dest in ipairs(target) do
		local unit = dest.unit
		if unit == nil or unit:getCount() < 1 then goto continue end

		local creature = unit:getCreature()
		local unitPos = unit:getPosition()

		for cloneIndex = 1, 2 do
			local searchOrigin
			if cloneIndex == 1 then
				searchOrigin = isAttacker and unitPos:copyToNorthEast() or unitPos:copyToNorthWest()
			else
				searchOrigin = isAttacker and unitPos:copyToSouthEast() or unitPos:copyToSouthWest()
			end
			if not searchOrigin:isValid() then
				print("falling back to unitPos")
				searchOrigin = unitPos
			end

			local hex = battle:getAvailableHex(creature, casterSide, searchOrigin)
			if not hex:isValid() then break end

			local cloneUnit = server:addUnit(battle, {
				count    = unit:getCount(),
				type     = creature,
				side     = casterSide,
				position = hex,
				summoned = true
			})
			if cloneUnit == nil then break end

			local cloneState = cloneUnit:copy()
			cloneState:setCloned(true)
			server:changeUnit(battle, cloneState)

			local originalState = unit:copy()
			originalState:setClone(cloneUnit)
			server:changeUnit(battle, originalState)

			server:addUnitBonus(battle, cloneUnit, {
				duration   = ENUM.BonusDuration.nTurns,
				type       = "NONE",
				sourceType = ENUM.BonusSource.spellEffect,
				val        = 0,
				sourceID   = mechanics:getSpell():getJsonKey(),
				turns      = mechanics:getEffectDuration()
			}, true)
		end
		::continue::
	end
end

return Script