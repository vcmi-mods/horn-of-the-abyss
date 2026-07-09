local Script = setmetatable({}, {__index = Base})
Script.__index = Script

function Script:applyHeroSpecialty(mechanics, buffer, unit)
	local hero = mechanics:getHeroCaster()
	if not hero then return end

	local spellKey = mechanics:getSpell():getJsonKey()
	local tier = math.max(unit:creatureLevel(), 1)

	local peculiar = hero:getBonuses(function(b)
		return b:getType() == "SPECIAL_PECULIAR_ENCHANT" and b:getSubtype() == spellKey
	end)
	if peculiar:size() > 0 then
		local mode = peculiar:getBonus(1):getParametersAsNumber()
		local power = 0
		if mode == 0 then
			if spellKey == "core:prayer" or spellKey == "core:haste" then
				if tier <= 4 then power = 3
				elseif tier <= 6 then power = 2
				else power = 1
				end
			elseif mechanics:isNegative() then
				if tier <= 2 then power = -4
				elseif tier <= 4 then power = -6
				elseif tier <= 6 then power = -8
				else power = -10
				end
			else
				if tier <= 2 then power = 10
				elseif tier <= 4 then power = 8
				elseif tier <= 6 then power = 6
				else power = 4
				end
			end
		elseif mode == 2 then
			if spellKey == "core:forgetfulness" then
				for _, nb in pairs(buffer) do
					if nb.type == "PERCENTAGE_DAMAGE_BOOST" then
						local base = -nb.val
						local increments = math.floor(peculiar:getBonus(1):getVal() / tier)
						nb.val = math.max(-math.floor(base * (1 + (increments * 0.10))), -100)
					end
				end
				goto endpeculiar
			elseif spellKey == "core:airShield" or spellKey == "core:shield" then
				for _, nb in pairs(buffer) do
					if nb.type == "GENERAL_DAMAGE_REDUCTION" then
						local increments = math.floor(peculiar:getBonus(1):getVal() / tier)
						nb.val = math.min(math.floor(nb.val * (1 + (increments * 0.10))), 100)
					end
				end
				goto endpeculiar
			end
		end
		if power ~= 0 then
			for _, nb in pairs(buffer) do
				nb.val = (nb.val or 0) + power
			end
		end
	end
	::endpeculiar::
	local addVal = hero:getBonuses(function(b)
		return b:getType() == "SPECIAL_ADD_VALUE_ENCHANT" and b:getSubtype() == spellKey
	end)
	if addVal:size() > 0 then
		local addAmount = addVal:getBonus(1):getParametersAsNumber()
		for _, nb in pairs(buffer) do
			nb.val = (nb.val or 0) + addAmount
		end
	end

	local fixedVal = hero:getBonuses(function(b)
		return b:getType() == "SPECIAL_FIXED_VALUE_ENCHANT" and b:getSubtype() == spellKey
	end)
	if fixedVal:size() > 0 then
		local fixedAmount = fixedVal:getBonus(1):getParametersAsNumber()
		for _, nb in pairs(buffer) do
			nb.val = fixedAmount
		end
	end
end

return Script