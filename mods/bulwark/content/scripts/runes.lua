local Base = require("combatScript")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local ANIMATIONS = {
	[1] = "hota/bulwark/skills/runes/runeLevels/rune1_01.def",
	[2] = "hota/bulwark/skills/runes/runeLevels/rune2_01.def",
	[3] = "hota/bulwark/skills/runes/runeLevels/rune3_01.def",
	[4] = "hota/bulwark/skills/runes/runeLevels/rune4_01.def",
	[5] = "hota/bulwark/skills/runes/runeLevels/rune5_01.def",
	[6] = "hota/bulwark/skills/runes/runeLevels/rune6_01.def",
	[7] = "hota/bulwark/skills/runes/runeLevels/rune7_01.def",
	[8] = "hota/bulwark/skills/runes/runeLevels/rune8_01.def",
	[9] = "hota/bulwark/skills/runes/runeLevels/rune9_01.def"
}
local ATTACK_BONUS = {
	[0] = 0,
	[1] = 2,
	[2] = 2,
	[3] = 2,
	[4] = 4,
	[5] = 4,
	[6] = 4,
	[7] = 6,
	[8] = 6,
	[9] = 6
}
local DEFENSE_BONUS = {
	[0] = 0,
	[1] = 0,
	[2] = 2,
	[3] = 2,
	[4] = 2,
	[5] = 4,
	[6] = 4,
	[7] = 4,
	[8] = 6,
	[9] = 6
}
local SPEED_BONUS = {
	[0] = 0,
	[1] = 0,
	[2] = 0,
	[3] = 1,
	[4] = 1,
	[5] = 1,
	[6] = 2,
	[7] = 2,
	[8] = 2,
	[9] = 3
}
local SOUND = "FIRESHIE"
local SOURCE = "runes"

function Script:getRuneLevelCap(battle, unit)
	local cap = 0

	local capList = unit:getBonuses(function(bonus)
		return bonus:getType() == "RUNE_LEVEL_CAP"
	end)
	for i = 1, capList:size() do
		cap = cap + capList:getBonus(i):getVal()
	end
	return cap
end

function Script:getCurrentRuneLevel(unit)
	local runeLevel = 0
	local runeLevelBonuses = unit:getBonuses(function(bonus)
		return bonus:getType() == "RUNE_LEVEL_COUNTER"
	end)
	for i = 1, runeLevelBonuses:size() do
		runeLevel = runeLevel + runeLevelBonuses:getBonus(i):getVal()
	end
	return runeLevel
end

function Script:updateBonuses(server, battle, unit, targetLevel, oldLevel)
	server:addUnitBonus(battle, unit, {
			type       = "RUNE_LEVEL_COUNTER",
			sourceType = ENUM.BonusSource.secondarySkill,
			val        = targetLevel - oldLevel,
			valueType  = ENUM.BonusValueType.baseNumber,
			sourceID   = SOURCE,
			duration   = ENUM.BonusDuration.oneBattle
	}, true)
	server:addUnitBonus(battle, unit, {
			type       = "PRIMARY_SKILL",
			subtype    = "attack",
			sourceType = ENUM.BonusSource.other,
			val        = ATTACK_BONUS[targetLevel] - ATTACK_BONUS[oldLevel],
			valueType  = ENUM.BonusValueType.baseNumber,
			duration   = ENUM.BonusDuration.oneBattle
	}, false)
	server:addUnitBonus(battle, unit, {
			type       = "PRIMARY_SKILL",
			subtype    = "defence",
			sourceType = ENUM.BonusSource.other,
			val        = DEFENSE_BONUS[targetLevel] - DEFENSE_BONUS[oldLevel],
			valueType  = ENUM.BonusValueType.baseNumber,
			duration   = ENUM.BonusDuration.oneBattle
	}, false)
	server:addUnitBonus(battle, unit, {
			type       = "STACKS_SPEED",
			sourceType = ENUM.BonusSource.other,
			val        = SPEED_BONUS[targetLevel] - SPEED_BONUS[oldLevel],
			valueType  = ENUM.BonusValueType.baseNumber,
			duration   = ENUM.BonusDuration.oneBattle
	}, false)
end

function Script:setRuneLevel(server, battle, unit, targetLevel)
	if targetLevel == 0 then
		server:addUnitBonus(battle, unit, {
			type       = "RUNE_LEVEL_COUNTER",
			sourceType = ENUM.BonusSource.secondarySkill,
			val        = 0,
			valueType  = ENUM.BonusValueType.baseNumber,
			sourceID   = SOURCE,
			duration   = ENUM.BonusDuration.oneBattle
	}, true)
		return
	end

	local cap = Script:getRuneLevelCap(battle, unit)

	if targetLevel > cap then
		targetLevel = cap
	elseif targetLevel < 0 then
		targetLevel = 0
	end

	local oldLevel = Script:getCurrentRuneLevel(unit)

	if oldLevel == targetLevel then return end


	Script:updateBonuses(server, battle, unit, targetLevel, oldLevel)
	if targetLevel > 0 and ANIMATIONS[targetLevel] then
		server:showBattleAnimation(battle, { { unit = unit } }, ANIMATIONS[targetLevel], SOUND, 1.0)
		if unit:getCreature().getJsonKey ~= "hota.bulwark:yetiRunemaster" then
			server:appendLog(battle, {
				append         = { "%s gain rune level %d" },
				replaceStrings = { unit:getCreature():getNameTextID(unit:getCount()) },
				replaceNumbers = { targetLevel }
			})
		end
	end
end

function Script:addRuneLevels(server, battle, unit, amount)
	local applyRunes = unit:isAlive()


	if not applyRunes then return end
	local current = Script:getCurrentRuneLevel(unit)
	Script:setRuneLevel(server, battle, unit, current + amount)
end

--- Called after `unit` attacked `other`.
function Script:onAfterAttack(server, battle, unit, other)
	Script:addRuneLevels(server, battle, unit, 1)
end

--- Called after `unit` was attacked by `other`.
function Script:onAfterAttacked(server, battle, unit, other)
	Script:addRuneLevels(server, battle, unit, 2)
end

--- Called when `unit` defends.
function Script:onDefend(server, battle, unit, other)
	Script:addRuneLevels(server, battle, unit, 3)
end

--- Called when `unit` casts a spell.
function Script:onUnitSpellcast(server, battle, unit, other)
	Script:addRuneLevels(server, battle, unit, 1)
end

--- Called once for every unit present when the battle starts, after tactics are over.
function Script:onBattleStart(server, battle, unit, other)
	local targetLevel = 0
	local bonusList = unit:getBonuses(function(bonus)
		return bonus:getType() == "STARTING_RUNE_LEVEL"
	end)
	for i = 1, bonusList:size() do
		targetLevel = targetLevel + bonusList:getBonus(i):getVal()
	end
	Script:setRuneLevel(server, battle, unit, targetLevel)
end

return Script
