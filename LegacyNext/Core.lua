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
		return value
	end

	return "unknown"
end

local function say(message)
	print("|cff33ff99" .. ADDON_NAME .. "|r: " .. message)
end

ns.say = say

-- One read of everything the v0 view needs. The only place Api output is gathered for
-- Model, shared by the frame and by /lgn uidump so the two cannot disagree.
function ns.ReadViewInput()
	local Api = ns.Api
	-- Categories first, then handed to GetChallenges so the list is read once.
	local categories = Api.GetCategories()
	local challenges, challengesReason = Api.GetChallenges(categories)
	local rewardTrack, rewardTrackReason = Api.GetRewardTrack()
	-- For hiding other classes' challenges. A failed read hides nothing.
	local character = Api.GetCharacterInfo()
	return {
		challenges = challenges,
		challengesReason = challengesReason,
		rewardTrack = rewardTrack,
		rewardTrackReason = rewardTrackReason,
		categories = categories,
		character = character,
	}
end

ns.UI.SetDataSource(ns.ReadViewInput)

--------------------------------------------------------------------------------------------
-- v1 roster: this character's snapshot, written through Store
--------------------------------------------------------------------------------------------

-- Reads this character, merges over what Store already holds, writes it back. Never throws:
-- it runs inside PLAYER_LOGOUT, where an error costs the one write that matters most.
-- Returns a one-line result, kept for /lgn roster to show.
function ns.TakeSnapshot(trigger)
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
		return "written"
	end)
	ns.lastSnapshot = tostring(trigger) .. " -> " .. (ok and result or ("error: " .. tostring(result)))
	return ns.lastSnapshot
end

-- Level, skill and trait changes arrive in bursts, and UnitLevel can lag PLAYER_LEVEL_UP, so
-- they coalesce into one snapshot a few seconds later. PLAYER_LOGOUT is the backstop if none
-- of these fire on Forever (C2 is still open on the trait event).
local SNAPSHOT_DELAY = 5
local snapshotPending = false

local function scheduleSnapshot(trigger)
	if snapshotPending then
		return
	end
	local timer = rawget(_G, "C_Timer")
	if type(timer) ~= "table" or type(timer.After) ~= "function" then
		ns.TakeSnapshot(trigger)
		return
	end
	snapshotPending = true
	timer.After(SNAPSHOT_DELAY, function()
		snapshotPending = false
		ns.TakeSnapshot(trigger)
	end)
end

-- One read for /lgn roster. Takes a snapshot first so the current character is never stale.
-- The challenge sweep is the ~900-call one, so this runs on command only, never on an event.
function ns.ReadRosterInput()
	local Api, Model, Store = ns.Api, ns.Model, ns.Store
	local snapshotResult = ns.TakeSnapshot("roster command")
	local challenges = Api.GetChallenges(Api.GetCategories())
	local skillLines = Model.ChallengeSkillLines(challenges)
	local parents, parentsReason = Api.GetSkillLineParents(skillLines)
	return {
		snapshots = Store.GetSnapshots(),
		currentKey = ns.currentKey,
		challenges = challenges,
		skillLines = skillLines,
		parents = parents,
		parentsReason = parentsReason,
		diagnostics = Store.Diagnostics(),
		snapshotResult = snapshotResult,
		now = Api.GetServerTime(),
	}
end

local SNAPSHOT_EVENTS = {
	PLAYER_LEVEL_UP = true,      -- UnitDocumentation.lua:3817
	SKILL_LINES_CHANGED = true,  -- SkillInfoDocumentation.lua:105
	TRAIT_CONFIG_UPDATED = true, -- SharedTraitsDocumentation.lua:873
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
for event in pairs(SNAPSHOT_EVENTS) do
	frame:RegisterEvent(event)
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
		ns.TakeSnapshot(event)
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
	print("  /lgn                     open or close the Next Up window")
	print("  /lgn show | hide")
	print("  /lgn uidump [category]   what the window would show, as copyable text")
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
