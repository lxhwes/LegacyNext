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
	-- With no live answer the merge is the saved map, so there is nothing to write.
	if type(parentsLive) == "table" and next(parentsLive) ~= nil then
		Store.PutSkillLineParents(parents)
	end
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
	-- The character it read is also for hiding other classes' challenges; a failed read hides
	-- nothing.
	local _, snapshotProblem, character = ns.TakeSnapshot("window", true)
	-- Categories first, then handed to GetChallenges so the list is read once.
	local categories = Api.GetCategories()
	local challenges, challengesReason = Api.GetChallenges(categories)
	local rewardTrack, rewardTrackReason = Api.GetRewardTrack()
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
		snapshotProblem = snapshotProblem,
		parents = roster.parents,
		candidates = roster.candidates,
		now = Api.GetServerTime(),
	}
end

ns.UI.SetDataSource(ns.ReadViewInput)

-- A challenge row's click: the chat-link click (Shift unless rebound) links it, as Blizzard's
-- own rows do, and any other click opens Blizzard's Legacy panel on it. A refusal is said in
-- chat, since the click otherwise does nothing visible.
local function challengeClick(id)
	local Api = ns.Api
	if Api.IsLinkClick() then
		local ok, reason = Api.LinkChallenge(id)
		if not ok then
			say("could not link it: " .. tostring(reason))
		end
		return
	end
	local ok, reason = Api.OpenLegacyChallenge(id)
	if not ok then
		say("could not open the Legacy panel: " .. tostring(reason))
	end
end

ns.UI.SetActions({ challengeClick = challengeClick })

-- The minimap tooltip reads what the window reads, so the two rank alike.
ns.MinimapButton.SetSummarySource(function()
	return ns.Model.BuildSummary(ns.ReadViewInput())
end)

-- Minimap exists by PLAYER_LOGIN, and both read Store, which attaches at ADDON_LOADED. A
-- failure is kept for /lgn uidump rather than said: neither stops the window working.
local function initMinimapAndOptions()
	local _, minimapReason = ns.MinimapButton.Init()
	ns.minimapReason = minimapReason
	local _, optionsReason = ns.Options.Register()
	ns.optionsReason = optionsReason
end

--------------------------------------------------------------------------------------------
-- v1 roster: this character's snapshot, written through Store
--------------------------------------------------------------------------------------------

-- This session's snapshot results, for /lgn roster. Each is also logged through Store, so the
-- logout result -- written after the last chance to see chat -- shows up next session.
-- SKILL_LINES_CHANGED fires on every skill-up, so it is held to Store's LOG_LIMIT: the login
-- result first, then the latest, with the dropped middle counted in snapshotLogSkipped.
ns.snapshotLog = {}
ns.snapshotLogSkipped = 0

-- Reads this character, merges over what Store already holds, writes it back. Never throws:
-- it runs inside PLAYER_LOGOUT, where an error costs the one write that matters most.
-- Returns a one-line result, the bare reason when nothing was written, for the Roster tab,
-- and the character it read, so a window read does not read it twice. `fromCommand` keeps
-- /lgn roster's own snapshot out of the log, which would otherwise fill with commands and
-- push out the logout results it exists for.
function ns.TakeSnapshot(trigger, fromCommand)
	local character
	local ok, result, problem = pcall(function()
		local Api, Model, Store = ns.Api, ns.Model, ns.Store
		local characterReason
		character, characterReason = Api.GetCharacterInfo()
		if not character then
			return "skipped: " .. tostring(characterReason), tostring(characterReason)
		end
		local treeSpend, treeSpendReason = Api.GetTreeSpend()
		local fresh, reason = Model.BuildSnapshot({
			character = character,
			treeSpend = treeSpend,
			treeSpendReason = treeSpendReason,
			now = Api.GetServerTime(),
		})
		if not fresh then
			return "skipped: " .. tostring(reason), tostring(reason)
		end
		-- The Name-Realm row is read only when a move could happen: a GUID key with no row yet.
		local stored = Store.GetSnapshot(fresh.key)
		local legacyKey = Model.LegacyCharacterKey(fresh)
		local legacy
		if stored == nil and legacyKey and legacyKey ~= fresh.key then
			legacy = Store.GetSnapshot(legacyKey)
		end
		local plan = Model.PlanSnapshot(fresh, stored, legacy)
		local merged = plan.snapshot
		local written, writeReason = Store.PutSnapshot(fresh.key, merged)
		ns.currentKey = fresh.key
		if not written then
			return "not written: " .. tostring(writeReason), tostring(writeReason)
		end
		-- Forgotten only after the GUID row is written, so a failed write loses nothing.
		local notes = {}
		if plan.forget then
			local forgot, forgetReason = Store.Forget(plan.forget)
			notes[#notes + 1] = forgot and ("migrated from " .. plan.forget)
				or ("copied from " .. plan.forget .. ", not forgotten: " .. tostring(forgetReason))
		end
		-- A part that failed to read was kept from before; say which, and why.
		for _, part in ipairs({ "trees", "professions" }) do
			local partReason = merged[part .. "Reason"]
			if partReason then
				notes[#notes + 1] = part .. ": " .. tostring(partReason)
			end
		end
		return notes[1] and ("written; " .. table.concat(notes, "; ")) or "written"
	end)
	if not ok then
		problem = "error: " .. tostring(result)
	end
	ns.lastSnapshot = tostring(trigger) .. " -> " .. (ok and result or problem)
	if not fromCommand then
		local at = ns.Api.GetServerTime()
		local log = ns.snapshotLog
		log[#log + 1] = { at = at, text = ns.lastSnapshot }
		if #log > ns.Store.LOG_LIMIT then
			table.remove(log, 2)
			ns.snapshotLogSkipped = ns.snapshotLogSkipped + 1
		end
		pcall(ns.Store.LogSnapshot, at, ns.lastSnapshot)
	end
	return ns.lastSnapshot, problem, character
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
		ns.UI.OnSnapshot()
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
		candidates = roster.candidates,
		parentsLive = roster.parentsLive,
		parentsReason = roster.parentsReason,
		diagnostics = Store.Diagnostics(),
		snapshotResult = snapshotResult,
		snapshotLog = ns.snapshotLog,
		snapshotLogSkipped = ns.snapshotLogSkipped,
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
		initMinimapAndOptions()
		-- Delayed like the others: skill and trait data may not be ready at PLAYER_LOGIN.
		scheduleSnapshot(event)
	elseif event == "PLAYER_LOGOUT" then
		ns.TakeSnapshot(event)
	elseif SNAPSHOT_EVENTS[event] then
		scheduleSnapshot(event)
	end
end)

-- Named by ## AddonCompartmentFunc. Blizzard's minimap dropdown calls it by global name with
-- (addonName, buttonName) (AddonCompartment.lua:99, :103); every button toggles, like /lgn.
function LegacyNext_OnAddonCompartmentClick()
	ns.UI.Toggle()
end

-- Hovering the dropdown entry shows the minimap button's summary tooltip. Named by
-- ## AddonCompartmentFuncOnEnter / OnLeave and called with (addonName, button)
-- (AddonCompartment.lua:106-117 at 9a789c0).
function LegacyNext_OnAddonCompartmentEnter(_, button)
	ns.MinimapButton.ShowTooltip(button, ns.MinimapButton.COMPARTMENT_HINT)
end

function LegacyNext_OnAddonCompartmentLeave()
	ns.MinimapButton.HideTooltip()
end

-- Key Bindings > AddOns. Bindings.xml loads by file name: none of the eight Blizzard addons that
-- ship one lists it in its TOC. The row label is BINDING_NAME_<name>, and category "ADDONS"
-- titles the section through _G.ADDONS, the Game Menu's own AddOns label.
--   label   used: Blizzard_SharedXML/BindingUtil.lua:142-149
--   section used: Blizzard_SettingsDefinitions_Frame/Keybindings.lua:220-227, :248-249
--   ADDONS  used: Blizzard_GameMenu/Shared/GameMenuFrame.lua:230
--   no TOC line:  Blizzard_PingUI/Blizzard_PingUI.toc, Blizzard_GroupFinder_VanillaStyle/
--                 Blizzard_GroupFinder_VanillaStyle.toc
-- pin:  966519c (1.60.1.70124)
BINDING_NAME_LEGACYNEXT_TOGGLE = "Open or close LegacyNext"

function LegacyNext_Toggle()
	ns.UI.Toggle()
end

SLASH_LEGACYNEXT1 = "/legacynext"
SLASH_LEGACYNEXT2 = "/lgn"

local function usage()
	say("commands:")
	print("  /lgn                     open or close the window (Next Up and Roster tabs)")
	print("  /lgn show | hide")
	print("  /lgn minimap             show or hide the minimap button")
	print("  /lgn config              open LegacyNext's settings")
	print("  /lgn uidump [category]   what the Next Up tab would show, as copyable text")
	print("  /lgn uidump roster       the same for the Roster tab")
	print("  /lgn roster              every saved character and tradeskill candidates, as text")
	print("  /lgn roster forget <Name-Realm>   drop a deleted alt from the roster (or name its saved key)")
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
	elseif command == "minimap" then
		local hidden = not ns.MinimapButton.IsHidden()
		ns.MinimapButton.SetHidden(hidden)
		say(hidden and "minimap button hidden. /lgn minimap brings it back." or "minimap button shown.")
	elseif command == "config" or command == "options" then
		ns.Options.Open()
	elseif command == "uidump" then
		ns.Debug.UIDump(rest ~= "" and rest or nil)
	elseif command == "roster" then
		local sub, key = string.match(rest, "^(%S*)%s*(.-)$")
		if string.lower(sub) == "forget" then
			-- Name-Realm or a stored key. Rows are GUID-keyed, but nobody types a GUID.
			local stored, reason = ns.Model.ForgetKey(key, ns.Store.GetSnapshots())
			local ok = false
			if stored then
				ok, reason = ns.Store.Forget(stored)
			end
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
