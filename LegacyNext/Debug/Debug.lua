local _, ns = ...

-- /legacynext dump: serializes Api output into a copyable multiline EditBox, so real client
-- data can be pasted back as spec fixtures. SavedVariables cannot do this job yet.
ns.Debug = ns.Debug or {}
local Debug = ns.Debug

local CHALLENGE_PAGE_SIZE = 20

-- Past this, the EditBox gets unwieldy and the copy is easy to truncate by accident. Not a
-- refusal, just a nudge towards a section dump.
local LARGE_DUMP = 60000

--------------------------------------------------------------------------------------------
-- Serialization
--------------------------------------------------------------------------------------------

local IDENTIFIER = "^[%a_][%w_]*$"

local RESERVED = {
	["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true, ["elseif"] = true,
	["end"] = true, ["false"] = true, ["for"] = true, ["function"] = true, ["if"] = true,
	["in"] = true, ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true,
	["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true, ["until"] = true,
	["while"] = true,
}

-- A pipe in the output would be read as a colour escape by the EditBox, and %q renders a
-- newline as a backslash followed by a real one. Both are re-encoded so the result is a single
-- clean Lua literal that round-trips back to the original string.
local function quote(value)
	local literal = string.format("%q", value)
	literal = literal:gsub("\\\n", "\\n")
	literal = literal:gsub("|", "\\124")
	return literal
end

local function number(value)
	if value ~= value then
		return "0/0"
	end
	if value == math.huge then
		return "math.huge"
	end
	if value == -math.huge then
		return "-math.huge"
	end
	return string.format("%.14g", value)
end

local function scalar(value)
	local kind = type(value)
	if kind == "string" then
		return quote(value)
	elseif kind == "number" then
		return number(value)
	elseif kind == "boolean" then
		return value and "true" or "false"
	elseif kind == "nil" then
		return "nil"
	end
	return quote("<" .. kind .. ">")
end

-- Deterministic ordering, so two dumps of unchanged client state diff cleanly.
local function sortedKeys(tbl)
	local numbers, strings, others = {}, {}, {}
	for key in pairs(tbl) do
		local kind = type(key)
		if kind == "number" then
			numbers[#numbers + 1] = key
		elseif kind == "string" then
			strings[#strings + 1] = key
		else
			others[#others + 1] = key
		end
	end

	table.sort(numbers)
	table.sort(strings)

	local keys = {}
	for _, key in ipairs(numbers) do keys[#keys + 1] = key end
	for _, key in ipairs(strings) do keys[#keys + 1] = key end
	for _, key in ipairs(others) do keys[#keys + 1] = key end
	return keys
end

local function isArray(keys)
	for index, key in ipairs(keys) do
		if key ~= index then
			return false
		end
	end
	return #keys > 0
end

local function renderKey(key)
	if type(key) == "string" and key:match(IDENTIFIER) and not RESERVED[key] then
		return key .. " = "
	end
	return "[" .. scalar(key) .. "] = "
end

local function write(value, indent, pieces)
	if type(value) ~= "table" then
		pieces[#pieces + 1] = scalar(value)
		return
	end

	local keys = sortedKeys(value)
	if #keys == 0 then
		pieces[#pieces + 1] = "{}"
		return
	end

	local inner = indent .. "\t"
	local array = isArray(keys)

	pieces[#pieces + 1] = "{\n"
	for _, key in ipairs(keys) do
		pieces[#pieces + 1] = inner
		if not array then
			pieces[#pieces + 1] = renderKey(key)
		end
		write(value[key], inner, pieces)
		pieces[#pieces + 1] = ",\n"
	end
	pieces[#pieces + 1] = indent .. "}"
end

-- Pure Lua, no WoW globals, which is what makes it testable under busted.
function Debug.Serialize(value)
	local pieces = {}
	write(value, "", pieces)
	return table.concat(pieces)
end

--------------------------------------------------------------------------------------------
-- Dump contents
--------------------------------------------------------------------------------------------

local function clientInfo()
	local Api = ns.Api
	local info = {
		addon = ns.name,
		addonVersion = ns.version or "unknown",
		flags = {
			eventDrivenRefresh = Api.flags.eventDrivenRefresh,
			followMetaChains = Api.flags.followMetaChains,
		},
	}

	local build = Api.Call("GetBuildInfo")
	if build then
		info.version = build[1]
		info.build = build[2]
		info.buildDate = build[3]
		-- The client's own interface number. Recorded, never branched on.
		info.tocVersion = build[4]
		info.buildString = tostring(build[1]) .. " (" .. tostring(build[2]) .. ")"
	end

	local meta = Api.Call("C_AddOns.GetAddOnMetadata", ns.name, "Interface")
	if meta and meta[1] then
		info.addonInterface = tonumber(meta[1]) or meta[1]
	end

	local project = rawget(_G, "WOW_PROJECT_ID")
	if type(project) == "number" then
		info.wowProjectId = project
	end

	return info
end

local function withReason(value, reason)
	if value ~= nil then
		return value
	end
	return { unavailable = reason or "unknown" }
end

local function challengePage(challenges, page)
	if not page then
		return challenges, nil
	end

	local total = #challenges
	local pages = math.max(1, math.ceil(total / CHALLENGE_PAGE_SIZE))
	page = math.max(1, math.min(page, pages))

	local slice = {}
	local first = (page - 1) * CHALLENGE_PAGE_SIZE + 1
	for index = first, math.min(first + CHALLENGE_PAGE_SIZE - 1, total) do
		slice[#slice + 1] = challenges[index]
	end

	return slice, {
		page = page,
		pages = pages,
		pageSize = CHALLENGE_PAGE_SIZE,
		total = total,
		firstIndex = first,
	}
end

Debug.sections = { "all", "summary", "challenges", "rewards", "trees", "character", "probe" }

function Debug.IsSection(name)
	for _, known in ipairs(Debug.sections) do
		if known == name then
			return true
		end
	end
	return false
end

-- Everything is data inside one returned table — no comment lines. A dump that loses its
-- newlines on the way back still parses, which `--` headers would not.
function Debug.Build(section, page)
	local Api = ns.Api
	section = section or "all"

	-- An unrecognised name used to fall through every branch and produce a dump with a meta
	-- block and no payload, which reads exactly like "the client returned nothing". `/lgn dump
	-- characters` cost a round trip that way. Say so instead.
	if not Debug.IsSection(section) then
		return "return {\n\tunknownSection = " .. string.format("%q", section)
			.. ",\n\tsections = { \"" .. table.concat(Debug.sections, "\", \"") .. "\" },\n}\n"
	end

	local dump = { meta = clientInfo() }
	dump.meta.section = section

	if section == "challenges" or section == "all" then
		local challenges, reason = Api.GetChallenges()
		if challenges then
			local slice, paging = challengePage(challenges, page)
			dump.challenges = slice
			dump.meta.challengeCount = #challenges
			dump.meta.paging = paging
		else
			dump.challenges = withReason(nil, reason)
		end
	end

	if section == "rewards" or section == "all" then
		local track, reason = Api.GetRewardTrack()
		dump.rewardTrack = withReason(track, reason)
	end

	if section == "trees" or section == "all" then
		local spend, reason = Api.GetTreeSpend()
		dump.treeSpend = withReason(spend, reason)
	end

	if section == "character" or section == "all" then
		local character, reason = Api.GetCharacterInfo()
		dump.character = withReason(character, reason)
	end

	if section == "probe" then
		dump.probe = Api.Probe()
	end

	if section == "summary" then
		local challenges = Api.GetChallenges()
		if challenges then
			local points, withCriteria, bars, binary = 0, 0, 0, 0
			for _, challenge in ipairs(challenges) do
				points = points + (challenge.points or 0)
				local criteria = challenge.criteria
				if criteria and #criteria > 0 then
					withCriteria = withCriteria + 1
					if criteria[1].isProgressBar then
						bars = bars + 1
					end
				else
					binary = binary + 1
				end
			end
			dump.summary = {
				challenges = #challenges,
				totalPoints = points,
				withCriteria = withCriteria,
				progressBar = bars,
				checklist = withCriteria - bars,
				noCriteria = binary,
			}
		end

		local track = Api.GetRewardTrack()
		if track then
			dump.summary = dump.summary or {}
			dump.summary.earned = track.earned
			dump.summary.nextThreshold = track.nextThreshold
			dump.summary.pointsToNext = track.pointsToNext
		end
	end

	-- Read last, so the tally covers the calls this dump just made.
	dump.failures = Api.GetFailures()

	return "return " .. Debug.Serialize(dump) .. "\n"
end

--------------------------------------------------------------------------------------------
-- The copyable window
--------------------------------------------------------------------------------------------

local function ensureFrame()
	if Debug.frame then
		return Debug.frame
	end

	local frame = CreateFrame("Frame", "LegacyNextDumpFrame", UIParent)
	frame:SetSize(760, 520)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

	local background = frame:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0, 0, 0, 0.92)

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 12, -10)
	frame.title = title

	-- UIPanelScrollFrameTemplate exists on the forever branch, but it is Blizzard UI and we do
	-- not gate on the client version, so a plain ScrollFrame is the fallback.
	local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	if not ok or not scroll then
		scroll = CreateFrame("ScrollFrame", nil, frame)
	end
	scroll:SetPoint("TOPLEFT", 12, -30)
	scroll:SetPoint("BOTTOMRIGHT", -32, 12)

	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject(ChatFontNormal)
	edit:SetWidth(700)
	if edit.SetMaxLetters then
		edit:SetMaxLetters(0)
	end
	if edit.SetMaxBytes then
		edit:SetMaxBytes(0)
	end
	edit:SetScript("OnEscapePressed", function()
		frame:Hide()
	end)
	scroll:SetScrollChild(edit)

	local closeOk, close = pcall(CreateFrame, "Button", nil, frame, "UIPanelCloseButton")
	if closeOk and close then
		close:SetPoint("TOPRIGHT", 0, 0)
		close:SetScript("OnClick", function()
			frame:Hide()
		end)
	end

	frame.edit = edit
	frame:Hide()
	Debug.frame = frame
	return frame
end

function Debug.Show(text, label)
	local frame = ensureFrame()
	frame.title:SetText("LegacyNext " .. (label or "dump") .. " - ctrl-A, ctrl-C")
	frame:Show()
	frame.edit:SetText(text)
	frame.edit:HighlightText()
	frame.edit:SetFocus()
	return frame
end

local function say(message)
	if ns.say then
		ns.say(message)
	else
		print(message)
	end
end

function Debug.Dump(section, page)
	local ok, text = pcall(Debug.Build, section, page)
	if not ok then
		say("dump failed: " .. tostring(text))
		return
	end

	local label = section or "all"
	if page then
		label = label .. " page " .. page
	end

	Debug.Show(text, label)

	if #text > LARGE_DUMP then
		say(("dump is %d characters. If the copy comes out short, use a section: %s")
			:format(#text, table.concat(Debug.sections, ", ")))
	end
end

-- One line per API, straight to chat: short enough to read in place, and it has to work even
-- when the dump frame is what is broken.
function Debug.Probe()
	local rows = ns.Api.Probe()
	say("probe - " .. #rows .. " APIs")

	local counts = {}
	for _, row in ipairs(rows) do
		counts[row.status] = (counts[row.status] or 0) + 1
		local line = row.status .. "  " .. row.name
		if row.detail then
			line = line .. "  " .. row.detail
		end
		print(line)
	end

	local parts = {}
	for _, state in ipairs({ "ok", "partial", "nil", "missing", "error", "secret", "skipped" }) do
		if counts[state] then
			parts[#parts + 1] = state .. "=" .. counts[state]
		end
	end
	say(table.concat(parts, "  "))

	return rows
end
