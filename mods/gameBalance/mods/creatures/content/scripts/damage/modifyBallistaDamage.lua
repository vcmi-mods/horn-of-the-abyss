local Script = setmetatable({}, {__index = Base})
Script.__index = Script

function Script:getBallistaDamageRange(info, minDamage, maxDamage)
	local heroAttack = info.attacker:getBonusesValue({type = "PRIMARY_SKILL", subtype = "attack", sourceType = ENUM.BonusSource.artifact})
		+ info.attacker:getBonusesValue({type = "PRIMARY_SKILL", subtype = "attack", sourceType = ENUM.BonusSource.heroBaseSkill})

	if self:hasBonusOfType(info.attackerBonuses, "BALLISTA_DAMAGE_OVERRIDE") then
		return minDamage * (heroAttack + 5), maxDamage * (heroAttack + 5)
	else
		return minDamage * (heroAttack + 1), maxDamage * (heroAttack + 1)
	end
end

Script:declareBonus("PRIMARY_SKILL")
Script:declareBonus("BALLISTA_DAMAGE_OVERRIDE")

return Script
