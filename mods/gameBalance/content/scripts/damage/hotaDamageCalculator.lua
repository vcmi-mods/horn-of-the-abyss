local Script = setmetatable({}, {__index = Base})
Script.__index = Script

function Script:getLuckFactor(info)
	return 0
end

function Script:getUnluckyFactor(info)
	return 0
end

function Script:getHotALuckFactor(info)
	if info.luckyStrike then
		return 2.0
	elseif info.unluckyStrike then
		return 0.5
	else
		return 1.0
	end
end

function Script:calculate(battle, info)
	info.battle = battle

	local baseMin, baseMax = self:getBaseDamage(info)

	local raising = 1.0
	local lowering = 1.0

	for _, method in ipairs(self:getFactors()) do
		local factor = self[method](self, info)

		if factor > 0 then
			raising = raising + factor
		elseif factor < 0 then
			lowering = lowering * (1 + math.max(-1.0, factor))
		end
	end

	local cap = self:getDamageCap(info)
	local hotaLuck = self:getHotALuckFactor(info)

	local function apply(base, factor)
		return math.min(cap, math.max(1, math.floor(base * factor * hotaLuck)))
	end

	local damageMin = apply(baseMin, raising * lowering)
	local damageMax = apply(baseMax, raising * lowering)

	local killsMin, killsMax = self:getCasualties(info, damageMin, damageMax)

	return {
		damage = { min = damageMin, max = damageMax },
		kills = { min = killsMin, max = killsMax },
		-- what the blow would have been worth had the target no defences at all, which is what an
		-- ability reflecting a strike works from
		damageBeforeDefense = { min = apply(baseMin, raising), max = apply(baseMax, raising) }
	}
end

return Script