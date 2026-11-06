local Base = require("combat/combatScript")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local GATLING_CAP = 4
local COUNTER_TYPE = "GATLING_COUNTER"
local HAS_ATTACKED = false
local SOURCE_ID = "hota.supplementary:gatlingCannon"
local SPELL_KEY = "hota.supplementary:abilityOverload"

local function setCounter(server, battle, unit, value)
	server:removeUnitBonuses(battle, unit, unit:getBonuses({ type = COUNTER_TYPE }))

	if value > 0 then
		server:addUnitBonus(battle, unit, {
			type       = COUNTER_TYPE,
			sourceType = ENUM.BonusSource.creatureAbility,
			sourceID   = SOURCE_ID,
			val        = value,
			valueType  = ENUM.BonusValueType.baseNumber,
			duration   = ENUM.BonusDuration.oneBattle
		}, false)
	end
end

function Script:setAttackCount(server, battle, unit, value)
	setCounter(server, battle, unit, value)
	server:removeUnitBonuses(battle, unit, unit:getBonuses({ type = "ADDITIONAL_ATTACK",
															 sourceType = ENUM.BonusSource.creatureAbility,
															 sourceID = SOURCE_ID }))
	server:addUnitBonus(battle, unit, {
					type       = "ADDITIONAL_ATTACK",
					sourceType = ENUM.BonusSource.creatureAbility,
					sourceID   = SOURCE_ID,
					val        = value,
					valueType  = ENUM.BonusValueType.baseNumber,
					duration   = ENUM.BonusDuration.oneBattle,
					hidden     = true
			}, false)
end

function Script:increaseAttacks(server, battle, unit)
	if not unit:isAlive() or not HAS_ATTACKED then return end

	local currentCounter = unit:getBonusesValue({ type = COUNTER_TYPE })

	if currentCounter >= GATLING_CAP then return end

	if currentCounter == GATLING_CAP - 1 then
		server:removeUnitBonuses(battle, unit, unit:getBonuses({ type = "CASTS" }))
	end

	self:setAttackCount(server, battle, unit, currentCounter + 1)
end

function Script:onAfterAttack(server, battle, unit, other, payload)
	HAS_ATTACKED = true
end

function Script:onUnitSpellcast(server, battle, unit, other, payload)
	if payload.spell:getJsonKey() ~= SPELL_KEY then return end
	self:setAttackCount(server, battle, unit, GATLING_CAP)
	server:removeUnitBonuses(battle, unit, unit:getBonuses({ type = "CASTS" }))
	HAS_ATTACKED = false
end

function Script:onActionFinished(server, battle, unit, other)
	self:increaseAttacks(server, battle, unit)
	HAS_ATTACKED = false
end

function Script:onRoundStart(server, battle, unit, other)
	HAS_ATTACKED = false
end

function Script:onBattleSetup(server, battle, unit, other)
	server:addUnitBonus(battle, unit, {
			type       = COUNTER_TYPE,
			sourceType = ENUM.BonusSource.creatureAbility,
			sourceID   = SOURCE_ID,
			val        = 0,
			valueType  = ENUM.BonusValueType.baseNumber,
			duration   = ENUM.BonusDuration.oneBattle
		}, false)
	server:addUnitBonus(battle, unit, {
			type       = "CASTS",
			sourceType = ENUM.BonusSource.creatureAbility,
			sourceID   = SOURCE_ID,
			val        = 1,
			valueType  = ENUM.BonusValueType.baseNumber,
			duration   = ENUM.BonusDuration.oneBattle
		}, false)
end

return Script
