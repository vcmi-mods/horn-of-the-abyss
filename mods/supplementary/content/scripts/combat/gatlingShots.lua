local Base = require("combat/combatScript")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

--- The cap for extra attacks.
local GATLING_CAP = 4
local COUNTER_TYPE = "GATLING_COUNTER"
local HAS_ATTACKED = "GATLING_HAS_ATTACKED"
local SOURCE_ID = "hota.supplementary:gatlingCannon"
local SPELL_KEY = "hota.supplementary:abilityOverload"

--- Helper function that creates the bonus descriptors.
local function createBonus(bonusType, value, extra)
	local bonus = {
		type       = bonusType,
		sourceType = ENUM.BonusSource.creatureAbility,
		sourceID   = SOURCE_ID,
		val        = value,
		valueType  = ENUM.BonusValueType.baseNumber,
		duration   = ENUM.BonusDuration.oneBattle,
	}
	if extra then
		for k, v in pairs(extra) do
			bonus[k] = v
		end
	end

	return bonus
end

--- Removes the old counter and replaces it with one with updated value.
local function setCounter(server, battle, unit, value)
	server:removeUnitBonuses(battle, unit, unit:getBonuses({ type = COUNTER_TYPE }))

	if value > 0 then
		server:addUnitBonus(battle, unit, createBonus(COUNTER_TYPE, value), false)
	end
end

--- Updates the counter and grants extra attacks.
function Script:setAttackCount(server, battle, unit, value)
	setCounter(server, battle, unit, value)
	server:removeUnitBonuses(battle, unit, unit:getBonuses({
		type       = "ADDITIONAL_ATTACK",
		sourceType = ENUM.BonusSource.creatureAbility,
		sourceID   = SOURCE_ID
	}))

	server:addUnitBonus(battle, unit, createBonus("ADDITIONAL_ATTACK", value, { hidden = true }), false)
end

--- Increments the counter and the amount of extra attacks.
function Script:increaseAttacks(server, battle, unit)
	if not unit:isAlive() or not unit:hasBonuses({ type = HAS_ATTACKED }) then return end

	local currentCounter = unit:getBonusesValue({ type = COUNTER_TYPE })

	if currentCounter >= GATLING_CAP then return end

	if currentCounter == GATLING_CAP - 1 then
		server:removeUnitBonuses(battle, unit, unit:getBonuses({ type = "CASTS" }))
	end

	self:setAttackCount(server, battle, unit, currentCounter + 1)
end

--- Marks the unit as having attacked, once per attack sequence.
function Script:onAfterAttack(server, battle, unit, other, payload)
	if payload.attackIndex ~= 0 then return end
	server:addUnitBonus(battle, unit, createBonus(HAS_ATTACKED, 1), false)
end

--- Sets the current counter and extra attacks to the cap.
function Script:onUnitSpellcast(server, battle, unit, other, payload)
	if payload.spell:getJsonKey() ~= SPELL_KEY then return end
	self:setAttackCount(server, battle, unit, GATLING_CAP)
	server:removeUnitBonuses(battle, unit, unit:getBonuses({ type = "CASTS" }))
end

--- Increments the counter and the extra attacks. Unmarks unit as having attacked.
function Script:onActionFinished(server, battle, unit, other)
	self:increaseAttacks(server, battle, unit)
	server:removeUnitBonuses(battle, unit, unit:getBonuses({ type = HAS_ATTACKED }))
end

--- Starts the counter and grants 1 spell cast to the unit.
function Script:onBattleSetup(server, battle, unit, other)
	server:addUnitBonus(battle, unit, createBonus(COUNTER_TYPE, 0), false)
	server:addUnitBonus(battle, unit, createBonus("CASTS", 1), false)
end

return Script
