local Script = setmetatable({}, {__index = Base})
Script.__index = Script

--- Ballista's Damage in HotA is baseDamage * (heroAttack + 5)
--- Cannon uses baseDamage * (heroAttack + 1), so we have to distinguish between the two
function Script:getBaseDamageSingle(info)
	local minDamage, maxDamage = Base.getBaseDamageSingle(self, info)

	if not self:hasBonusOfType(info.attackerBonuses, "BALLISTA_DAMAGE_OVERRIDE") then
		return minDamage, maxDamage
	end

	local heroAttack =
		info.attacker:getBonusesValue({
			type = "PRIMARY_SKILL",
			subtype = "attack",
			sourceType = ENUM.BonusSource.artifact
		})
		+
		info.attacker:getBonusesValue({
			type = "PRIMARY_SKILL",
			subtype = "attack",
			sourceType = ENUM.BonusSource.heroBaseSkill
		})
	--- base damage is already multiplied by the siegeWeapon.lua script in core
	minDamage = minDamage / (heroAttack + 1)
	maxDamage = maxDamage / (heroAttack + 1)

	return minDamage * (heroAttack + 5), maxDamage * (heroAttack + 5)
end

Script:declareBonus("BALLISTA_DAMAGE_OVERRIDE")

return Script
