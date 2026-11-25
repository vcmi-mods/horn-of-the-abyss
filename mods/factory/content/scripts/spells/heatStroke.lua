local Base = require("spells/unitEffect")
local BattleLog = require("battleLog")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script
--- Parameters:
--- hoverText: registered string for hovering over a valid target, required
--- blockedText: registered string for hovering over an invalid target, required

local E, W = "copyToEast", "copyToWest"
local NE, NW = "copyToNorthEast", "copyToNorthWest"
local SE, SW = "copyToSouthEast", "copyToSouthWest"

--- Cone patterns as relative hex steps; invalid and caster-occupied results are filtered later.
local PATTERNS = {
	[0] = { {E}, {NE}, {SE}, {E,E}, {E,NE}, {E,SE}, {NE,NE}, {SE,SE} },
	[1] = { {E}, {E,SW}, {E,SW,W}, {E,E}, {E,SE}, {E,SW,SE}, {E,SW,SW}, {E,SW,W,SW} },
	[2] = { {SW}, {SW,E}, {SW,W}, {SW,SE}, {SW,SW}, {SW,E,SE}, {SW,W,SW} },
	[3] = { {SE}, {SW}, {W}, {SE,SW}, {SE,SE}, {SW,W}, {SW,SW}, {W,W} },
	[4] = { {W}, {W,NE}, {W,SE}, {W,W}, {W,NW}, {W,SW}, {W,NE,NW}, {W,SE,SW} },
	[5] = { {NW}, {NE}, {W}, {NW,W}, {NW,NE}, {NW,NW}, {NE,NE}, {W,W} },
	[6] = { {NW}, {NE}, {NW,W}, {NW,NW}, {NW,NE}, {NE,NE}, {NW,W,NW} },
	[7] = { {NE}, {NW}, {E}, {NE,NW}, {NE,NE}, {NE,E}, {NW,NW}, {E,E} }
}

--- LuaJIT uses `math.atan2`; Lua 5.3 uses two-argument `math.atan`.
local atan2 = math.atan2 or math.atan

--- Returns one of eight directions from caster to aim point.
local function getHexDirection(from, to)
	local dx = to:getX() - from:getX()
	local dy = to:getY() - from:getY()

	-- Even rows are shifted right.
	if from:getY() % 2 == 0 then
		dx = dx - 0.5
	end

	if to:getY() % 2 == 0 then
		dx = dx + 0.5
	end

	local angle = math.deg(atan2(dy, dx))
	if angle < 0 then
		angle = angle + 360
	end

	-- Convert the angle to eight directions.
	return math.floor((angle + 22.5) / 45) % 8
end

--- Returns the footprint hex facing the cast direction.
local function getAnchor(caster, direction)
	local hexes = caster:getHexes()
	local anchor = hexes:at(1)
	local wantWest = direction >= 3 and direction <= 5

	for i = 2, hexes:size() do
		local other = hexes:at(i)
		if (other:getX() < anchor:getX()) == wantWest then
			anchor = other
		end
	end

	return anchor
end

--- Returns valid cone hexes outside the caster footprint.
local function getAffectedHexes(mechanics, spellTarget)
	if #spellTarget == 0 then return {} end

	local caster = mechanics:getUnitCaster()
	local direction = getHexDirection(caster:getPosition(), spellTarget[1].hex)
	local anchor = getAnchor(caster, direction)
	local pattern = {}

	for _, steps in ipairs(PATTERNS[direction]) do
		local hex = anchor
		for _, step in ipairs(steps) do
			hex = hex[step](hex)
		end

		if hex:isValid() and not caster:coversPos(hex) then
			table.insert(pattern, hex)
		end
	end

	return pattern
end

--- Returns whether luck modifies the attack.
local function rollForLuck(server, luckDice)
	if luckDice <= 0 then
		return false
	end

	return server:rngInt(1, 24) <= luckDice
end

--- Returns the factor for the Attack-Defense difference between caster's `attack` and the `target`
local function getDamageFactor(attack, target)
	local add = attack - target:getDefense(false)
	return (add > 0) and math.min(1 + add * 0.05, 4.0) or math.max(1 + add * 0.025, 0.3)
end

--- Applies the damage cap, should `target` request one
local function applyDamageCap(rawDamage, target)
	local cap = target:getBonusesValue({ type = "DAMAGE_RECEIVED_CAP" })
	local damage = rawDamage

	if cap > 0 then
		damage = math.min(damage, math.max(math.floor(target:getMaxHealth() * cap / 100), 1))
	end

	return damage
end

--- Returns whether `target` is a valid receptive non-self unit.
function Script:isEligible(mechanics, unit, target)
	if unit:unitID() == target:unitID() or not target:isValidTarget(false) or target:isInvincible() then
		return false
	end

	return mechanics:isReceptive(target)
end

--- Retains the aimed hex as `targets[1]` for cursor validation.
function Script:transformTarget(mechanics, aimPoint, spellTarget)
	local battle = mechanics:getBattle()
	local casterUnit = mechanics:getUnitCaster()
	local pattern = getAffectedHexes(mechanics, spellTarget)
	local targets = {}
	local seenUnits = {}

	table.insert(targets, { unit = nil, hex = spellTarget[1].hex })

	for _, hex in ipairs(pattern) do
		local target = battle:getUnitByPos(hex, true)

		if target and not seenUnits[target:unitID()] then
			seenUnits[target:unitID()] = true

			if self:isEligible(mechanics, casterUnit, target) then
				table.insert(targets, { unit = target, hex = hex })
			end
		end
	end

	return targets
end

function Script:adjustAffectedHexes(mechanics, hexes, spellTarget)
	for _, hex in ipairs(getAffectedHexes(mechanics, spellTarget)) do
		hexes:insert(hex)
	end
	return hexes
end

function Script:applicableGeneral(mechanics, problem)
	local caster = mechanics:getUnitCaster()
	if not caster or not caster:isAlive() then
		problem:addGeneric(mechanics)
		return false
	end
	return true
end

function Script:applicableTarget(mechanics, problem, target)
	local pattern = getAffectedHexes(mechanics, target)
	local targetHex = target[1].hex

	for _, hex in ipairs(pattern) do
		if targetHex == hex then
			return true
		end
	end

	problem:addStandard(mechanics, ENUM.SpellCastProblem.wrongSpellTarget)
	return false
end

function Script:getHealthChange(mechanics, spellTarget)
    local result = { hpDelta = 0, unitsDelta = 0 }
	local caster = mechanics:getUnitCaster()
	local baseDamage = ((caster:getMinDamage(false) + caster:getMaxDamage(false)) / 2) * caster:getCount()
	local attack = caster:getAttack(false)

	for _, dest in ipairs(spellTarget) do
		local unit = dest.unit
		if unit then
			local damage = math.floor(baseDamage * getDamageFactor(attack, unit))
			damage = applyDamageCap(damage, unit)

			local copy = unit:copy()
			local hpBefore    = copy:getAvailableHealth()
			local countBefore = copy:getCount()
			copy:damage(damage)

			result.hpDelta = result.hpDelta - (hpBefore - copy:getAvailableHealth())
			result.unitsDelta = result.unitsDelta - (countBefore - copy:getCount())
		end
	end

	return result
end

function Script:describeTargetStep(mechanics, partialTarget, hoveredHex)
	return {
		cursor = "combatHeatStroke",
		text = {
			append = { self.hoverText }
		},
		blockedText = {
			append = { self.blockedText }
		},
		healthGainTextID = 0
	}
end

function Script:apply(mechanics, server, target)
	local battle = mechanics:getBattle()
	local caster = mechanics:getUnitCaster()
	local count = caster:getCount()
	local baseDamMin = caster:getMinDamage(false) * count
	local baseDamMax = caster:getMaxDamage(false) * count
	local attack = caster:getAttack(false)
	local totalDamage, totalKilled = 0, 0
	-- Use effective luck after caps and unit exclusions.
	local luck = caster:getLuck()
	local isUnluck = luck < 0
	-- Negative luck uses twice as many rolls.
	local luckDice = isUnluck and -luck * 2 or luck

    --- Fix potentially swapped damage due to mods
	if baseDamMin > baseDamMax then
		print("minimum damage is bigger than maximum damage!")
		baseDamMin, baseDamMax = baseDamMax, baseDamMin
	end

	-- TODO: Replace this approximation when the engine exposes creature attack damage calculation.
	for _, dest in ipairs(target) do
		local unit = dest.unit
		if unit then
			--- note: not quite correct mechanics-wise, but fine for temporary
			local factor = getDamageFactor(attack, unit)
			local scaledMin = math.floor(baseDamMin * factor)
			local scaledMax = math.floor(baseDamMax * factor)
			local damage = server:rngInt(scaledMin, scaledMax)

			if rollForLuck(server, luckDice) then
				damage = isUnluck and math.floor(damage * 0.5) or math.floor(damage * 2)
			end
			damage = applyDamageCap(damage, unit)

			local dealt, killed = server:damageUnit(battle, unit, damage)
			totalDamage = totalDamage + dealt
			totalKilled = totalKilled + killed
		end
	end
	local victim = #target == 2 and target[2].unit or nil

	-- Resolve the spell here because script-load and battle contexts use different services.
	BattleLog.spellDamage(server, battle, LIBRARY:getSpellByName("heatStroke"), victim, totalDamage, totalKilled)
end

return Script
