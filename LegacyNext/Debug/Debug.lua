local _, ns = ...

-- /legacynext dump: serializes Api output into a copyable multiline EditBox, so real client
-- data can be pasted back as spec fixtures. SavedVariables cannot do this job yet.
ns.Debug = ns.Debug or {}
local Debug = ns.Debug

local CHALLENGE_PAGE_SIZE = 20

-- Past this, the EditBox gets unwieldy and the copy is easy to truncate by accident. Not a
-- refusal, just a nudge towards a section dump.
local LARGE_DUMP = 60000

local function say(message)
	if ns.say then
		ns.say(message)
	else
		print(message)
	end
end

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

Debug.sections = {
	"all", "summary", "challenges", "categories", "rewards", "trees", "character", "probe",
}

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

	if section == "categories" or section == "all" then
		local categories, reason = Api.GetCategories()
		dump.categories = withReason(categories, reason)
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
-- uidump: the v0 view as text
--------------------------------------------------------------------------------------------

-- The frame is roughly this many characters wide at its default size. An estimate for the
-- overflow report only; the real truncation happens in the FontString.
Debug.ROW_CHARS = 44
Debug.NAME_CHARS = 30

local function pad(text, width)
	text = tostring(text or "")
	if #text >= width then
		return text
	end
	return text .. string.rep(" ", width - #text)
end

local function lpad(text, width)
	text = tostring(text or "")
	if #text >= width then
		return text
	end
	return string.rep(" ", width - #text) .. text
end

-- Pure: renders a Model.BuildView result to the text /lgn uidump shows, so row content can be
-- checked here against fixtures and only the look needs the client. No WoW globals.
function Debug.RenderView(view, label)
	local out = {}
	local function w(line) out[#out + 1] = line end

	w("LegacyNext uidump" .. (label and ("  " .. label) or ""))
	w("== HEADER (" .. view.header.state .. ") ==")
	for _, line in ipairs(view.header.lines or {}) do
		w(line)
	end

	w("== FILTERS ==")
	local parts = {}
	for _, filter in ipairs(view.filters or {}) do
		local text = filter.name .. " " .. tostring(filter.count)
		if filter.selected then
			text = "[" .. text .. "]"
		end
		parts[#parts + 1] = text
	end
	w(table.concat(parts, " | "))

	w("== ROWS (" .. #(view.rows or {}) .. ") ==")
	local longest, longestName, overflow = 0, "", {}
	local rowNumber = 0
	for _, row in ipairs(view.rows or {}) do
		if row.kind == "divider" then
			w("     ----- " .. row.text .. " -----")
		else
			rowNumber = rowNumber + 1
			local name = row.name or ""
			if #name > longest then
				longest, longestName = #name, name
			end
			if #name > Debug.NAME_CHARS then
				overflow[#overflow + 1] = name
			end
			w(lpad(rowNumber, 3) .. "  " .. pad(name, Debug.NAME_CHARS) .. lpad(row.progressText, 9)
				.. "  " .. lpad(row.pointsText, 4))
		end
	end

	w("== STATE ==")
	w("state=" .. tostring(view.state) .. (view.message and ("  " .. view.message) or ""))
	local stats = view.stats
	if stats then
		w(("total=%d ranked=%d measurable=%d measureless=%d completed=%d zeroPoint=%d otherClass=%d"
			.. " partialRead=%d pointsUnknown=%d"):format(stats.total, stats.ranked, stats.measurable,
				stats.measureless, stats.completed, stats.zeroPoint, stats.otherClass or 0,
				stats.partialRead, stats.pointsUnknown))
	end
	if view.footnote then
		w("note=" .. view.footnote)
	end
	if rowNumber > 0 then
		w(("longest name=%d chars %q"):format(longest, longestName))
		w(("names over %d chars: %d"):format(Debug.NAME_CHARS, #overflow))
		for _, name in ipairs(overflow) do
			w("  " .. name)
		end
	end

	return table.concat(out, "\n") .. "\n"
end

-- Reads Api once, builds the view through Model, renders it. `filter` is a group name typed
-- on the command line ("classes"), matched case-insensitively against the filter labels.
function Debug.BuildUIDump(filterName)
	local Model = ns.Model

	-- The same read the frame makes, so uidump and the window cannot disagree on content.
	-- Timed, because a ~900-call sweep is the one cost nobody has measured (status.md).
	local clock = rawget(_G, "debugprofilestop")
	local started = type(clock) == "function" and clock() or nil
	local input = ns.ReadViewInput()
	local elapsed = started and (clock() - started) or nil

	local filterId
	if filterName and filterName ~= "" then
		local probe = Model.BuildView(input)
		for _, filter in ipairs(probe.filters or {}) do
			if filter.id and string.lower(filter.name) == string.lower(filterName) then
				filterId = filter.id
			end
		end
	end

	input.filter = filterId
	local view = Model.BuildView(input)

	local info = clientInfo()
	local label = tostring(info.buildString or "?") .. "  filter=" .. (filterName or "all")
	if filterName and filterName ~= "" and not filterId then
		label = label .. " (unknown, showing all)"
	end

	local text = Debug.RenderView(view, label)

	-- Footer: what the read cost and what the frame decided about its templates, so U1
	-- answers the performance and template questions in the same paste.
	local footer = {}
	if elapsed then
		footer[#footer + 1] = ("read took %.0f ms"):format(elapsed)
	end
	if ns.UI and ns.UI.Describe then
		footer[#footer + 1] = "frame " .. Debug.Serialize(ns.UI.Describe()):gsub("%s+", " ")
	end
	if #footer > 0 then
		text = text .. "== CLIENT ==\n" .. table.concat(footer, "\n") .. "\n"
	end
	return text
end

function Debug.UIDump(filterName)
	local ok, text = pcall(Debug.BuildUIDump, filterName)
	if not ok then
		say("uidump failed: " .. tostring(text))
		return
	end
	Debug.Show(text, "uidump")
end

--------------------------------------------------------------------------------------------
-- /lgn roster: the v1 data as text, until the roster frame exists
--------------------------------------------------------------------------------------------

-- Stored snapshots are unvalidated (Store never interprets them), so every field is
-- type-checked here: one junk row must not cost the whole paste.
local function professionText(professions)
	if type(professions) ~= "table" then
		return "professions ?"
	end
	if #professions == 0 then
		return "no professions"
	end
	local parts = {}
	for _, profession in ipairs(professions) do
		if type(profession) == "table" then
			parts[#parts + 1] = ("%s %s/%s [%s]"):format(tostring(profession.name),
				tostring(profession.skill), tostring(profession.max), tostring(profession.skillLineId))
		end
	end
	return table.concat(parts, ", ")
end

local function treeText(snapshot)
	if type(snapshot.trees) ~= "table" then
		return "trees ?"
	end
	local parts = {}
	for _, tree in ipairs(snapshot.trees) do
		if type(tree) == "table" then
			parts[#parts + 1] = tostring(tree.name) .. " " .. tostring(tree.spent)
		end
	end
	return ("%s | unspent %s, cap %s"):format(table.concat(parts, ", "), tostring(snapshot.unspent),
		tostring(snapshot.cap))
end

-- Pure: renders the roster, the profession candidates and the store's own diagnostics.
-- input = { roster = Model.Roster, candidates = Model.ProfessionCandidates, diagnostics,
-- parents, parentsReason, challengesReason, snapshotResult, snapshotLog, eventsNotRegistered,
-- now }.
function Debug.RenderRoster(input)
	local out = {}
	local function w(line) out[#out + 1] = line end

	w("LegacyNext roster" .. (input.label and ("  " .. input.label) or ""))

	w("== STORE ==")
	local d = input.diagnostics or {}
	w(("attached=%s loadedType=%s loadedSessions=%s loadedCharacters=%s sessions=%s characters=%s")
		:format(tostring(d.attached), tostring(d.loadedType), tostring(d.loadedSessions),
			tostring(d.loadedCharacters), tostring(d.sessions), tostring(d.characters)))
	if d.readOnly then
		w("READ ONLY: " .. tostring(d.reason))
	end
	if d.lateLoads then
		w("LATE LOAD: the client replaced LegacyNextDB after ADDON_LOADED " .. d.lateLoads
			.. " time(s); the loaded* numbers are from the replacement")
	end
	if d.globalIsOurs == false then
		w("NOT SAVED: LegacyNextDB is no longer the table being written")
	end
	if input.snapshotResult then
		w("this snapshot: " .. input.snapshotResult)
	end
	local function logLines(title, log, withSession)
		if type(log) ~= "table" or not log[1] then
			return
		end
		w(title)
		for _, entry in ipairs(log) do
			if type(entry) == "table" then
				local age = ""
				if type(input.now) == "number" and type(entry.at) == "number" then
					age = ("%dm ago  "):format(math.floor((input.now - entry.at) / 60))
				end
				local session = withSession and ("session " .. tostring(entry.session) .. "  ") or ""
				w("  " .. session .. age .. tostring(entry.text))
			end
		end
	end
	logLines("snapshots this session:", input.snapshotLog, false)
	logLines("snapshots saved by earlier sessions:", d.loadedLog, true)
	if input.eventsNotRegistered and input.eventsNotRegistered[1] then
		w("events not registered: " .. table.concat(input.eventsNotRegistered, ", "))
	end

	local roster = input.roster or { rows = {} }
	w("== CHARACTERS (" .. #roster.rows .. ") ==")
	for _, row in ipairs(roster.rows) do
		local age = ""
		if type(input.now) == "number" and type(row.takenAt) == "number" then
			age = ("  %dm ago"):format(math.floor((input.now - row.takenAt) / 60))
		end
		w(("%s%s  L%s %s%s"):format(row.key == roster.currentKey and "* " or "  ", row.key,
			tostring(row.level), tostring(row.class), age))
		w("    " .. treeText(row))
		w("    " .. professionText(row.professions))
	end
	if (roster.skipped or 0) > 0 then
		w("skipped " .. roster.skipped .. " unreadable snapshots")
	end

	w("== TRADESKILL CANDIDATES ==")
	if input.challengesReason then
		w("challenge read failed: " .. tostring(input.challengesReason))
	elseif not (input.candidates and input.candidates[1]) then
		w("no incomplete tradeskill challenges")
	end
	if input.parentsReason then
		w("parent lookup: " .. input.parentsReason)
	end
	for _, entry in ipairs(input.candidates or {}) do
		local parent = input.parents and input.parents[entry.skillLineId]
		w(("%s  [line %s, parent %s, profession %s]  need %s"):format(tostring(entry.challenge.name),
			tostring(entry.skillLineId), tostring(parent and parent.parentId),
			tostring(parent and parent.professionId), tostring(entry.need)))
		if #entry.candidates == 0 then
			w("    no stored character has this profession")
		end
		for _, candidate in ipairs(entry.candidates) do
			w(("    %s  skill %s, %s to go%s"):format(tostring(candidate.key), tostring(candidate.skill),
				tostring(candidate.remaining), candidate.reached and "  (already reached)" or ""))
		end
	end

	return table.concat(out, "\n") .. "\n"
end

-- Reads through ns.ReadRosterInput (Core), then appends the raw inputs as a Lua literal so the
-- paste doubles as S1's fixture.
function Debug.BuildRoster()
	local Model = ns.Model
	local input = ns.ReadRosterInput()

	local text = Debug.RenderRoster({
		label = tostring(clientInfo().buildString or "?"),
		roster = Model.Roster(input.snapshots, input.currentKey),
		candidates = Model.ProfessionCandidates(input.challenges, input.snapshots, input.parents),
		diagnostics = input.diagnostics,
		parents = input.parents,
		parentsReason = input.parentsReason,
		snapshotResult = input.snapshotResult,
		snapshotLog = input.snapshotLog,
		eventsNotRegistered = input.eventsNotRegistered,
		challengesReason = input.challengesReason,
		now = input.now,
	})

	return text .. "== RAW ==\n" .. Debug.Serialize({
		diagnostics = input.diagnostics,
		challengesReason = input.challengesReason,
		skillLines = input.skillLines,
		parents = withReason(input.parents, input.parentsReason),
		snapshots = input.snapshots,
	}) .. "\n"
end

function Debug.Roster()
	local ok, text = pcall(Debug.BuildRoster)
	if not ok then
		say("roster failed: " .. tostring(text))
		return
	end
	Debug.Show(text, "roster")
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
