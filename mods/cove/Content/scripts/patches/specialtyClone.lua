local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local function shouldCastSpecialtyClone(mechanics, spellKey)
	local caster = mechanics:getHeroCaster()
	if not caster or spellKey ~= "core:clone" then
		return false
	end

	local specialtyCharges = caster:getBonusesValue({ type = "SPECIALTY_CLONE" })

	return specialtyCharges > 0
end

function Script:apply(mechanics, server, target)
	local spellKey = mechanics:getSpell():getJsonKey()
	if not shouldCastSpecialtyClone(mechanics, spellKey) then
		Base.apply(self, mechanics, server, target)
		return
	end

	local battle = mechanics:getBattle()
	local casterSide = mechanics:getCasterSide()
	local isAttacker = (casterSide == 0)

	server:addBattleBonus(battle, {
		type       = "SPECIALTY_CLONE",
		sourceType = "OTHER",
		val        = -1,
		valueType  = "ADDITIVE_VALUE",
		sourceID   = spellKey
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
				sourceID   = spellKey,
				turns      = mechanics:getEffectDuration()
			}, true)
		end
		::continue::
	end
end

return Script