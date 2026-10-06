local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local function drainableDamage(payload)
	local total = 0

	for _, target in ipairs(payload.targets or {}) do
		if target.unit and target.unit:isLiving() then
			total = total + target.damage
		end
	end

	return total
end

function Script:onAfterAttack(server, battle, unit, other, payload)
	if unit:getTotalHealth() == unit:getAvailableHealth() then return end

	local toHeal = math.floor(drainableDamage(payload) * (self.val or 0) / 100)
	if unit:hasBonuses({type = "HOTA_RING_OF_OBLIVION"}) then
		toHeal = math.min(toHeal, unit:getMaxHealth() - unit:getFirstHPleft())
	end

	if toHeal <= 0 then return end

	local drainerCount = unit:getCount()

	local healed, resurrected = server:healUnit(battle, unit, toHeal,
		ENUM.HealLevel.resurrect, ENUM.HealPower.permanent)

	if healed <= 0 then return end

	server:showBattleAnimation(battle, { { unit = unit } }, "SP06_", "DRAINLIF", 0.5)
	BattleLog.lifeDrained(server, battle, unit, other, healed, resurrected, drainerCount)
end

return Script