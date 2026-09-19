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
	local challenges, challengesReason = Api.GetChallenges()
	local rewardTrack, rewardTrackReason = Api.GetRewardTrack()
	local categories = Api.GetCategories()
	return {
		challenges = challenges,
		challengesReason = challengesReason,
		rewardTrack = rewardTrack,
		rewardTrackReason = rewardTrackReason,
		categories = categories,
	}
end

ns.UI.SetDataSource(ns.ReadViewInput)

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		ns.version = getVersion()
		-- No "v" prefix: the packager writes the tag name into ## Version, and tags carry it.
		say(ns.version .. " loaded. /lgn to open, /lgn help for commands.")
	end
end)

SLASH_LEGACYNEXT1 = "/legacynext"
SLASH_LEGACYNEXT2 = "/lgn"

local function usage()
	say("commands:")
	print("  /lgn                     open or close the Next Up window")
	print("  /lgn show | hide")
	print("  /lgn uidump [category]   what the window would show, as copyable text")
	print("  /lgn probe               one line per API: ok / nil / missing / error / secret")
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
