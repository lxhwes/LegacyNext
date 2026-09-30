local ADDON_NAME, ns = ...

ns.name = ADDON_NAME

-- Feature-detected even for metadata: the global GetAddOnMetadata is gone on the Mainline
-- API this client shares, and we never branch on the interface number to decide that.
local function getVersion()
	local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	if type(getMetadata) ~= "function" then
		return "unknown"
	end

	local ok, value = pcall(getMetadata, ADDON_NAME, "Version")
	if ok and value then
		-- A copy straight from the repo keeps the packager's version token. Match the leading
		-- "@" only: the packager rewrites the whole token in every file it copies, this one too.
		if type(value) == "string" and value:sub(1, 1) == "@" then
			return "dev"
		end
		return value
	end

	return "unknown"
end

local function say(message)
	print("|cff33ff99" .. ADDON_NAME .. "|r: " .. message)
end

ns.say = say

-- Store's characters and the skill-line map, shared by the window and /lgn roster so the two
-- join alts to tradeskill challenges the same way. The map is merged with this session's
-- lookup and saved back, so an answer read on the Alchemist still joins when the roster is
-- read on an alt that never learned it.
local function readRoster(challenges)
	local Api, Model, Store = ns.Api, ns.Model, ns.Store
	local skillLines = Model.ChallengeSkillLines(challenges)
	local parentsLive, parentsReason = Api.GetSkillLineParents(skillLines)
	local parents = Model.MergeSkillLineParents(Store.GetSkillLineParents(), parentsLive)
	Store.PutSkillLineParents(parents)
	local snapshots = Store.GetSnapshots()
	return {
		skillLines = skillLines,
		parentsLive = parentsLive,
		parentsReason = parentsReason,
		parents = parents,
		snapshots = snapshots,
		candidates = Model.ProfessionCandidates(challenges, snapshots, parents),
	}
end

-- One read of everything both tabs need. The only place Api output is gathered for Model,
-- shared by the frame and by /lgn uidump so the two cannot disagree.
function ns.ReadViewInput()
	local Api = ns.Api
	-- Keeps this character's roster row current. A window read stays out of the snapshot log.
	ns.TakeSnapshot("window", true)
	-- Categories first, then handed to GetChallenges so the list is read once.
	local categories = Api.GetCategories()
	local challenges, challengesReason = Api.GetChallenges(categories)
	local rewardTrack, rewardTrackReason = Api.GetRewardTrack()
	-- For hiding other classes' challenges. A failed read hides nothing.
	local character = Api.GetCharacterInfo()
	local roster = readRoster(challenges)
	return {
		challenges = challenges,
		challengesReason = challengesReason,
		rewardTrack = rewardTrack,
		rewardTrackReason = rewardTrackReason,
		categories = categories,
		character = character,
		snapshots = roster.snapshots,
		currentKey = ns.currentKey,
		parents = roster.parents,
		candidates = roster.candidates,
		now = Api.GetServerTime(),
	}
end

ns.UI.SetDataSource(ns.ReadViewInput)

--------------------------------------------------------------------------------------------
-- v1 roster: this character's snapshot, written through Store
--------------------------------------------------------------------------------------------

-- This session's snapshot results, for /lgn roster. Each is also logged through Store, so the
-- logout result -- written after the last chance to see chat -- shows up next session.
ns.snapshotLog = {}

-- Reads this character, merges over what Store already holds, writes it back. Never throws:
-- it runs inside PLAYER_LOGOUT, where an error costs the one write that matters most.
-- Returns a one-line result. `fromCommand` keeps /lgn roster's own snapshot out of the log,
-- which would otherwise fill with commands and push out the logout results it exists for.
function ns.TakeSnapshot(trigger, fromCommand)
	local ok, result = pcall(function()
		local Api, Model, Store = ns.Api, ns.Model, ns.Store
		local character, characterReason = Api.GetCharacterInfo()
		if not character then
			return "skipped: " .. tostring(characterReason)
		end
		local treeSpend, treeSpendReason = Api.GetTreeSpend()
		local fresh, reason = Model.BuildSnapshot({
			character = character,
			treeSpend = treeSpend,
			treeSpendReason = treeSpendReason,
			now = Api.GetServerTime(),
		})
		if not fresh then
			return "skipped: " .. tostring(reason)
		end
		local merged = Model.MergeSnapshot(Store.GetSnapshot(fresh.key), fresh)
		local written, writeReason = Store.PutSnapshot(fresh.key, merged)
		ns.currentKey = fresh.key
		if not written then
			return "not written: " .. tostring(writeReason)
		end
		-- A part that failed to read was kept from before; say which, and why.
		local notes = {}
		for _, part in ipairs({ "trees", "professions" }) do
			local partReason = merged[part .. "Reason"]
			if partReason then
				notes[#notes + 1] = part .. ": " .. tostring(partReason)
			end
		end
		return notes[1] and ("written; " .. table.concat(notes, "; ")) or "written"
	end)
	ns.lastSnapshot = tostring(trigger) .. " -> " .. (ok and result or ("error: " .. tostring(result)))
	if not fromCommand then
		local at = ns.Api.GetServerTime()
		ns.snapshotLog[#ns.snapshotLog + 1] = { at = at, text = ns.lastSnapshot }
		pcall(ns.Store.LogSnapshot, at, ns.lastSnapshot)
	end
	return ns.lastSnapshot
end

-- Level, skill and trait changes arrive in bursts, and UnitLevel can lag PLAYER_LEVEL_UP, so
-- they coalesce into one snapshot a few seconds after the *last* event: each one restarts the
-- wait, so a late event still gets the full delay. PLAYER_LOGOUT is the backstop if none of
-- these fire on Forever (C2 is still open on the trait event).
local SNAPSHOT_DELAY = 5
local snapshotGeneration = 0
local pendingTriggers = {}

local function scheduleSnapshot(trigger)
	local seen = false
	for _, pending in ipairs(pendingTriggers) do
		seen = seen or pending == trigger
	end
	if not seen then
		pendingTriggers[#pendingTriggers + 1] = trigger
	end

	-- C_Timer.After cannot be cancelled, so a superseded timer is told apart by generation.
	snapshotGeneration = snapshotGeneration + 1
	local generation = snapshotGeneration
	local function fire()
		if generation ~= snapshotGeneration then
			return
		end
		local triggers = table.concat(pendingTriggers, "+")
		pendingTriggers = {}
		ns.TakeSnapshot(triggers)
	end

	local timer = rawget(_G, "C_Timer")
	local scheduled = type(timer) == "table" and type(timer.After) == "function"
		and pcall(timer.After, SNAPSHOT_DELAY, fire)
	if not scheduled then
		fire()
	end
end

-- One read for /lgn roster. Takes a snapshot first so the current character is never stale.
-- The challenge sweep is the ~900-call one, so this runs on command only, never on an event.
function ns.ReadRosterInput()
	local Api, Store = ns.Api, ns.Store
	local snapshotResult = ns.TakeSnapshot("roster command", true)
	-- A failed read has to reach the paste: an empty candidate list otherwise reads as "no
	-- tradeskill challenges" rather than "could not read them".
	local categories, categoriesReason = Api.GetCategories()
	local challenges, challengesReason
	if categories then
		challenges, challengesReason = Api.GetChallenges(categories)
	else
		challengesReason = "categories: " .. tostring(categoriesReason)
	end
	local roster = readRoster(challenges)
	return {
		snapshots = roster.snapshots,
		currentKey = ns.currentKey,
		challenges = challenges,
		challengesReason = challengesReason,
		skillLines = roster.skillLines,
		parents = roster.parents,
		parentsLive = roster.parentsLive,
		parentsReason = roster.parentsReason,
		diagnostics = Store.Diagnostics(),
		snapshotResult = snapshotResult,
		snapshotLog = ns.snapshotLog,
		eventsNotRegistered = ns.eventsNotRegistered,
		now = Api.GetServerTime(),
	}
end

local SNAPSHOT_EVENTS = {
	PLAYER_LEVEL_UP = true,      -- UnitDocumentation.lua:3817
	SKILL_LINES_CHANGED = true,  -- SkillInfoDocumentation.lua:105
	TRAIT_CONFIG_UPDATED = true, -- SharedTraitsDocumentation.lua:873
}

local frame = CreateFrame("Frame")

-- RegisterEvent throws on a name the client does not know, and a throw here stops Core before
-- the slash commands exist. Checked first where the client can say, pcall'd regardless.
-- Anything skipped is listed by /lgn roster, which is also C2's evidence.
ns.eventsNotRegistered = {}

local function register(event)
	local ok, reason
	if ns.Api.IsEventValid(event) == false then
		ok, reason = false, "unknown to this client"
	else
		ok, reason = pcall(frame.RegisterEvent, frame, event)
	end
	if not ok then
		ns.eventsNotRegistered[#ns.eventsNotRegistered + 1] = event .. " (" .. tostring(reason) .. ")"
	end
end

register("ADDON_LOADED")
register("PLAYER_LOGIN")
register("PLAYER_LOGOUT")
for event in pairs(SNAPSHOT_EVENTS) do
	register(event)
end
frame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON_NAME then
			local ok, reason = ns.Store.Attach()
			if not ok then
				say("saved roster is read-only: " .. tostring(reason))
			end
		end
	elseif event == "PLAYER_LOGIN" then
		ns.version = getVersion()
		-- No "v" prefix: the packager writes the tag name into ## Version, and tags carry it.
		say(ns.version .. " loaded. /lgn to open, /lgn help for commands.")
		-- Delayed like the others: skill and trait data may not be ready at PLAYER_LOGIN.
		scheduleSnapshot(event)
	elseif event == "PLAYER_LOGOUT" then
		ns.TakeSnapshot(event)
	elseif SNAPSHOT_EVENTS[event] then
		scheduleSnapshot(event)
	end
end)

SLASH_LEGACYNEXT1 = "/legacynext"
SLASH_LEGACYNEXT2 = "/lgn"

local function usage()
	say("commands:")
	print("  /lgn                     open or close the window (Next Up and Roster tabs)")
	print("  /lgn show | hide")
	print("  /lgn uidump [category]   what the Next Up tab would show, as copyable text")
	print("  /lgn uidump roster       the same for the Roster tab")
	print("  /lgn roster              every saved character and tradeskill candidates, as text")
	print("  /lgn roster forget <Name-Realm>   drop a deleted alt from the roster")
	print("  /lgn probe               one line per API: ok / partial / nil / missing / error / secret / skipped")
	print("  /lgn dump                everything Api returns, as a Lua literal")
	print("  /lgn dump <section>      one of: " .. table.concat(ns.Debug.sections, ", "))
	print("  /lgn dump challenges 2   page 2 of the challenge list")
end

SlashCmdList["LEGACYNEXT"] = function(input)
	local command, rest = string.match(input or "", "^%s*(%S*)%s*(.-)%s*$")
	command = string.lower(command or "")

	if command == "" or command == "toggle" then
		ns.UI.Toggle()
	elseif command == "show" then
		ns.UI.Show()
	elseif command == "hide" then
		ns.UI.Hide()
	elseif command == "uidump" then
		ns.Debug.UIDump(rest ~= "" and rest or nil)
	elseif command == "roster" then
		local sub, key = string.match(rest, "^(%S*)%s*(.-)$")
		if string.lower(sub) == "forget" then
			local ok, reason = ns.Store.Forget(key)
			say(ok and ("forgot " .. key) or ("not forgotten: " .. tostring(reason)))
		else
			ns.Debug.Roster()
		end
	elseif command == "probe" then
		ns.Debug.Probe()
	elseif command == "dump" then
		local section, page = string.match(rest, "^(%S*)%s*(%S*)$")
		if section == "" then
			section = nil
		end
		ns.Debug.Dump(section, tonumber(page))
	elseif command == "help" then
		usage()
	else
		say("unknown command '" .. command .. "'")
		usage()
	end
end
