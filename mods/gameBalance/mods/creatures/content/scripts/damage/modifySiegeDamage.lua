local Script = setmetatable({}, {__index = Base})
Script.__index = Script

function Script:getBaseDamageSingle(info)
	local minDamage, maxDamage = Base.getBaseDamageSingle(self, info)

	if not self:hasBonusOfType(info.attackerBonuses, "SIEGE_WEAPON") then return minDamage, maxDamage end
	if info.attacker:isTurret() then return minDamage, maxDamage end

	local heroAttack = info.attacker:getBonusesValue({type = "PRIMARY_SKILL", subtype = "attack", sourceType = ENUM.BonusSource.artifact})
		+ info.attacker:getBonusesValue({type = "PRIMARY_SKILL", subtype = "attack", sourceType = ENUM.BonusSource.heroBaseSkill})

	if self:hasBonusOfType(info.attackerBonuses, "BALLISTA_DAMAGE_OVERRIDE") then
		return minDamage * (heroAttack + 5), maxDamage * (heroAttack + 5)
	else
		return minDamage * (heroAttack + 1), maxDamage * (heroAttack + 1)
	end
end

Script:declareBonus("SIEGE_WEAPON")
Script:declareBonus("BALLISTA_DAMAGE_OVERRIDE")

return Script
