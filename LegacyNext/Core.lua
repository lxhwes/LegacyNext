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

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		ns.version = getVersion()
		say("v" .. ns.version .. " loaded.")
	end
end)

SLASH_LEGACYNEXT1 = "/legacynext"
SLASH_LEGACYNEXT2 = "/lgn"

local function usage()
	say("commands:")
	print("  /lgn probe               one line per API: ok / nil / missing / error / secret")
	print("  /lgn dump                everything Api returns, as a Lua literal")
	print("  /lgn dump <section>      one of: " .. table.concat(ns.Debug.sections, ", "))
	print("  /lgn dump challenges 2   page 2 of the challenge list")
end

SlashCmdList["LEGACYNEXT"] = function(input)
	local command, rest = string.match(input or "", "^%s*(%S*)%s*(.-)%s*$")
	command = string.lower(command or "")

	if command == "probe" then
		ns.Debug.Probe()
	elseif command == "dump" then
		local section, page = string.match(rest, "^(%S*)%s*(%S*)$")
		if section == "" then
			section = nil
		end
		ns.Debug.Dump(section, tonumber(page))
	elseif command == "" or command == "help" then
		usage()
	else
		say("unknown command '" .. command .. "'")
		usage()
	end
end
