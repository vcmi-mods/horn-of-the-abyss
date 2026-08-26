local Base = require("spells/timed")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

--- Already checked everything
function Script:applicableTarget(mechanics, problem, target)
	return true
end

--- Add the caster, hex does not matter
function Script:transformTarget(mechanics, aimPoint, spellTarget)
	return {{ unit = mechanics:getUnitCaster(), hex = nil }}
end

--- Only for unit-self cast
function Script:applicableGeneral(mechanics, problem)
	local caster = mechanics:getUnitCaster()
	if caster and caster:isAlive() then
		return true
	end

	problem:addStandard(mechanics, ENUM.SpellCastProblem.noAppropriateTarget)
	return false
end

return Script