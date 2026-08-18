local Base = require("combat/combatScript")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local ANIMATIONS = {
	"hota/bulwark/skills/runes/runeLevels/rune1_01.def",
	"hota/bulwark/skills/runes/runeLevels/rune2_01.def",
	"hota/bulwark/skills/runes/runeLevels/rune3_01.def",
	"hota/bulwark/skills/runes/runeLevels/rune4_01.def",
	"hota/bulwark/skills/runes/runeLevels/rune5_01.def",
	"hota/bulwark/skills/runes/runeLevels/rune6_01.def",
	"hota/bulwark/skills/runes/runeLevels/rune7_01.def",
	"hota/bulwark/skills/runes/runeLevels/rune8_01.def",
	"hota/bulwark/skills/runes/runeLevels/rune9_01.def"
}
local RUNE_TYPES = {
	hero = {
		counterType = "RUNE_LEVEL_COUNTER",
		sourceType = ENUM.BonusSource.secondarySkill,
		sourceID = "runes"
	},
	yeti = {
		counterType = "YETI_RUNE_LEVEL_COUNTER",
		sourceType = ENUM.BonusSource.creatureAbility,
		sourceID = "yetiRunemaster"
	}
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
local SOUND = "hota/bulwark/spells/RUNE"

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

function Script:getCurrentRuneLevels(unit)
	local heroRuneLevel = 0
	local yetiRuneLevel = 0
	local runeLevelBonuses = unit:getBonuses(function(bonus)
		local btype = bonus:getType()
		return btype == "RUNE_LEVEL_COUNTER" or btype == "YETI_RUNE_LEVEL_COUNTER"
	end)
	for i = 1, runeLevelBonuses:size() do
		local bonus = runeLevelBonuses:getBonus(i)
		local btype = bonus:getType()
		if btype == "YETI_RUNE_LEVEL_COUNTER" then
			yetiRuneLevel = yetiRuneLevel + bonus:getVal()
		else
			heroRuneLevel = heroRuneLevel + bonus:getVal()
		end
	end
	return heroRuneLevel, yetiRuneLevel
end

function Script:updateRuneBonuses(server, battle, unit, targetLevel, oldLevel, runeType)
	local runeLevelBonuses = unit:getBonuses(function(bonus)
		return bonus:getType() == runeType.counterType
	end)
	server:removeUnitBonuses(battle, unit, runeLevelBonuses)
	server:addUnitBonus(battle, unit, {
			type       = runeType.counterType,
			sourceType = runeType.sourceType,
			sourceID   = runeType.sourceID,
			val        = targetLevel,
			valueType  = ENUM.BonusValueType.baseNumber,
			duration   = ENUM.BonusDuration.oneBattle
	}, false)
	local bonusVal = ATTACK_BONUS[targetLevel] - ATTACK_BONUS[oldLevel]
	if bonusVal > 0 then
		server:addUnitBonus(battle, unit, {
				type       = "PRIMARY_SKILL",
				subtype    = "attack",
				sourceType = ENUM.BonusSource.other,
				val        = bonusVal,
				valueType  = ENUM.BonusValueType.baseNumber,
				duration   = ENUM.BonusDuration.oneBattle
		}, false)
	end
	bonusVal = DEFENSE_BONUS[targetLevel] - DEFENSE_BONUS[oldLevel]
	if bonusVal > 0 then
		server:addUnitBonus(battle, unit, {
				type       = "PRIMARY_SKILL",
				subtype    = "defence",
				sourceType = ENUM.BonusSource.other,
				val        = bonusVal,
				valueType  = ENUM.BonusValueType.baseNumber,
				duration   = ENUM.BonusDuration.oneBattle
		}, false)
	end
	bonusVal = SPEED_BONUS[targetLevel] - SPEED_BONUS[oldLevel]
	if bonusVal > 0 then
		server:addUnitBonus(battle, unit, {
				type       = "STACKS_SPEED",
				sourceType = ENUM.BonusSource.other,
				val        = bonusVal,
				valueType  = ENUM.BonusValueType.baseNumber,
				duration   = ENUM.BonusDuration.oneBattle
		}, false)
	end
end

function Script:addRuneLevel(server, battle, unit, oldLevel, amount, runeType, cap)
	if cap == 0 then
		return 0
	end
	local targetLevel = oldLevel + amount

	if targetLevel == 0 then
		return 0
	end

	targetLevel = math.max(0, math.min(targetLevel, cap))

	if oldLevel == targetLevel then return oldLevel end

	self:updateRuneBonuses(server, battle, unit, targetLevel, oldLevel, runeType)

	return targetLevel
end

function Script:addHeroRuneLevels(server, battle, unit, oldLevel, amount)
	local cap = self:getRuneLevelCap(battle, unit)

	return self:addRuneLevel(server, battle, unit, oldLevel, amount, RUNE_TYPES.hero, cap)
end

function Script:addYetiRuneLevels(server, battle, unit, oldLevel, amount)
	return self:addRuneLevel(server, battle, unit, oldLevel, amount, RUNE_TYPES.yeti, 9)
end

function Script:processRuneGain(server, battle, unit, amount, deferAnimation)
	if not unit:isAlive() then return end
	local isYeti = self.isYeti
	local heroRuneLevel, yetiRuneLevel = self:getCurrentRuneLevels(unit)
	local oldLevel = isYeti and yetiRuneLevel or heroRuneLevel

	heroRuneLevel = self:addHeroRuneLevels(server, battle, unit, heroRuneLevel, amount)
	if isYeti then
		yetiRuneLevel = self:addYetiRuneLevels(server, battle, unit, yetiRuneLevel, amount)
	end

	local newLevel = isYeti and yetiRuneLevel or heroRuneLevel

	if oldLevel == newLevel or newLevel == 0 then
		return
	end

	local animation = ANIMATIONS[newLevel]
	if animation then
		server:showBattleAnimation(battle, { { unit = unit } }, animation, SOUND, 1.0, deferAnimation)
	end

	self:describe(server, battle, unit, newLevel)
end

function Script:processAltar(server, battle, unit, startLevel)
	if not unit then return end

	local side = unit:getSide()
	local sideUnits = battle:getUnitsIf(function(battleUnit)
		return battleUnit:getSide() == side
	end)

	local animationTargets = {}

	for _, sideUnit in ipairs(sideUnits) do
		local bonusList = sideUnit:getBonuses(function(bonus)
			return bonus:getType() == "SIEGE_WEAPON"
		end)

		if bonusList:size() == 0 then
			local heroRuneLevel, yetiRuneLevel = self:getCurrentRuneLevels(sideUnit)

			local isYeti = sideUnit:getCreature():getJsonKey() == "hota.bulwark:yetiRunemaster"
			local oldLevel = isYeti and yetiRuneLevel or heroRuneLevel

			heroRuneLevel = self:addHeroRuneLevels(server, battle, sideUnit, heroRuneLevel, startLevel)

			if isYeti then
				yetiRuneLevel = self:addYetiRuneLevels(server, battle, sideUnit, yetiRuneLevel, startLevel)
			end

			local newLevel = isYeti and yetiRuneLevel or heroRuneLevel

			if newLevel ~= oldLevel and newLevel > 0 then
				animationTargets[newLevel] = animationTargets[newLevel] or {}
				table.insert(animationTargets[newLevel], { unit = sideUnit })
			end
		end
	end

	for level, targets in pairs(animationTargets) do
		server:showBattleAnimation(battle, targets, ANIMATIONS[level], SOUND, 1.0)
	end

	self:describe(server, battle, nil, startLevel)
end

--- Called after `unit` attacked `other`.
function Script:onAfterAttack(server, battle, unit, other, payload)
	if payload.isCounter then return end
	if payload.attackIndex ~= 0 then return end
	self:processRuneGain(server, battle, unit, 1, false)
end

--- Called after `unit` was attacked by `other`.
function Script:onAfterAttacked(server, battle, unit, other, payload)
	if payload.attackIndex ~= 0 then return end
	self:processRuneGain(server, battle, unit, 2, false)
end

--- Called when `unit` defends.
function Script:onDefend(server, battle, unit, other)
	self:processRuneGain(server, battle, unit, 3, false)
end

--- Called when `unit` casts a spell.
function Script:onUnitSpellcast(server, battle, unit, other)
	self:processRuneGain(server, battle, unit, 1, true)
end

--- Called once for every unit present when the battle starts, after tactics are over.
function Script:onBattleStart(server, battle, unit, other)
	local cap = self.isYeti and 9 or self:getRuneLevelCap(battle, unit)
	if cap == 0 then return end

	local startLevel, currentLevel = 0, 0
	local targetCounterType = self.isYeti and "YETI_RUNE_LEVEL_COUNTER" or "RUNE_LEVEL_COUNTER"
	local bonusList = unit:getBonuses(function(bonus)
		local bType = bonus:getType()
		return bType == "STARTING_RUNE_LEVEL" or bType == targetCounterType
	end)

	for i = 1, bonusList:size() do
		local bonus = bonusList:getBonus(i)

		if bonus:getType() == "STARTING_RUNE_LEVEL" then
			startLevel = startLevel + bonus:getVal()
		else
			currentLevel = currentLevel + bonus:getVal()
		end
	end

	if math.min(startLevel, cap) > currentLevel then
		self:processAltar(server, battle, unit, startLevel)
	end
end

function Script:describe(server, battle, unit, newLevel)
	if not unit then
		if newLevel == 1 then
			server:appendLog(battle, {
				append         = { "core.bonus.RUNE_LEVEL_CAP.description" }
			})
		else
			server:appendLog(battle, {
				append         = { "core.bonus.STARTING_RUNE_LEVEL.description" },
				replaceNumbers = { newLevel }
			})
		end
	else
		local count = unit:getCount()
		server:appendLog(battle, {
			append         = { count == 1 and "core.bonus.RUNE_LEVEL_COUNTER.description" or "core.bonus.YETI_RUNE_LEVEL_COUNTER.description" },
			replaceStrings = { unit:getCreature():getNameTextID(count) },
			replaceNumbers = { newLevel }
		})
	end
end

return Script
