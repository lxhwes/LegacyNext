local _, ns = ...

-- SavedVariables behind an interface. Nothing else in the addon names LegacyNextDB or
-- LegacyNextCharDB, so a change in how the client persists them -- the beta bug where
-- SavedVariables were written but never loaded back, reported fixed 2026-09-30 and unverified
-- until S1 -- stays a one-file change.
--
-- Layout, schema 1:
--   LegacyNextDB = {
--     schema = 1,
--     sessions = <number of times the addon loaded with this table>,
--     characters = { [<key>] = <Model.BuildSnapshot output>, ... },
--       -- <key> is Model.CharacterKey: the character's GUID. A row saved before GUID keys, or
--       -- on a session whose UnitGUID read failed, is keyed "Name-Realm" until that character
--       -- logs in again and Core moves it (Model.PlanSnapshot). Store never parses a key.
--     snapshotLog = { { session, at, text }, ... },   -- last LOG_LIMIT snapshot results
--     skillLineParents = { [skillLineId] = <Model.MergeSkillLineParents entry>, ... },
--   }
--
-- snapshotLog and skillLineParents are additive, so schema stays 1: an older build ignores
-- them.
--
-- Per character, no schema, every field optional:
--   LegacyNextCharDB = {
--     ui = { tab = <tab id>, filter = <Next Up group id>, point = { left = x, top = y } },
--   }
--
-- Store never interprets a snapshot. Merging, validating and rendering them is Model's job.
-- Window state is the same: UI validates it.
ns.Store = ns.Store or {}
local Store = ns.Store

Store.SCHEMA = 1
Store.LOG_LIMIT = 10
local GLOBAL_NAME = "LegacyNextDB"
local CHARACTER_GLOBAL = "LegacyNextCharDB"

local db = nil
local diagnostics = { attached = false }

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, item in pairs(value) do
		out[key] = copy(item)
	end
	return out
end

local function countKeys(tbl)
	local count = 0
	for _ in pairs(tbl) do
		count = count + 1
	end
	return count
end

--- Call once, on ADDON_LOADED for this addon: the client assigns SavedVariables just before it.
-- Returns true, or false plus a reason. A table saved by a newer schema is left untouched and
-- the store stays read-only, so a downgrade never destroys an alt list.
function Store.Attach()
	local saved = rawget(_G, GLOBAL_NAME)
	local loadedType = type(saved)

	if loadedType ~= "table" then
		saved = {}
	end

	-- What came back from disk, recorded before this session touches anything. This is the
	-- S1 evidence: after a /reload, a working client shows sessions >= 1 here.
	diagnostics = {
		attached = true,
		loadedType = loadedType,
		loadedSchema = saved.schema,
		loadedSessions = type(saved.sessions) == "number" and saved.sessions or 0,
		loadedCharacters = type(saved.characters) == "table" and countKeys(saved.characters) or 0,
		-- Earlier sessions' snapshot results, logout included: the one write nobody sees.
		loadedLog = type(saved.snapshotLog) == "table" and copy(saved.snapshotLog) or {},
	}

	if saved.schema ~= nil and saved.schema ~= Store.SCHEMA then
		diagnostics.readOnly = true
		diagnostics.reason = "saved schema " .. tostring(saved.schema) .. ", this build reads "
			.. Store.SCHEMA
		db = saved
		rawset(_G, GLOBAL_NAME, saved)
		return false, diagnostics.reason
	end

	saved.schema = Store.SCHEMA
	if type(saved.characters) ~= "table" then
		saved.characters = {}
	end
	saved.sessions = diagnostics.loadedSessions + 1

	db = saved
	rawset(_G, GLOBAL_NAME, saved)
	return true
end

-- Keys this session wrote (true) or forgot (false), replayed if the table is swapped.
local touched = {}

-- The client should assign SavedVariables before ADDON_LOADED, but the beta bug behind S1 was
-- never explained. If a different table turns up in the global later, it came from disk: adopt
-- it rather than keep writing to an orphan the client saves over, and replay this session's
-- character writes onto it. The log is not replayed; Core holds this session's copy.
local function sync()
	if not db then
		return
	end
	local current = rawget(_G, GLOBAL_NAME)
	if current == db or type(current) ~= "table" then
		return
	end
	local orphan = db
	local lateLoads = (diagnostics.lateLoads or 0) + 1
	Store.Attach()
	diagnostics.lateLoads = lateLoads
	if diagnostics.readOnly or type(orphan.characters) ~= "table" then
		return
	end
	for key, wrote in pairs(touched) do
		db.characters[key] = wrote and orphan.characters[key] or nil
	end
end

local function writable()
	sync()
	if not db then
		return false, "store not attached"
	end
	if diagnostics.readOnly then
		return false, diagnostics.reason
	end
	return true
end

--- The stored snapshot for one character key, as a copy, or nil.
function Store.GetSnapshot(key)
	sync()
	if not db or type(db.characters) ~= "table" then
		return nil
	end
	return copy(db.characters[key])
end

--- Replaces one character's snapshot. The caller merges; Store only persists.
function Store.PutSnapshot(key, snapshot)
	local ok, reason = writable()
	if not ok then
		return false, reason
	end
	if type(key) ~= "string" or key == "" or type(snapshot) ~= "table" then
		return false, "bad key or snapshot"
	end
	db.characters[key] = copy(snapshot)
	touched[key] = true
	return true
end

--- Removes one character, for a deleted or transferred alt. Returns whether it existed.
function Store.Forget(key)
	local ok, reason = writable()
	if not ok then
		return false, reason
	end
	if db.characters[key] == nil then
		return false, "no character " .. tostring(key)
	end
	db.characters[key] = nil
	touched[key] = false
	return true
end

--- Appends one snapshot result for a later session to read, keeping the last LOG_LIMIT.
function Store.LogSnapshot(at, text)
	local ok, reason = writable()
	if not ok then
		return false, reason
	end
	if type(db.snapshotLog) ~= "table" then
		db.snapshotLog = {}
	end
	local log = db.snapshotLog
	log[#log + 1] = { session = db.sessions, at = at, text = tostring(text) }
	while #log > Store.LOG_LIMIT do
		table.remove(log, 1)
	end
	return true
end

--- The account-wide skill-line map, as a copy; empty when none was saved.
function Store.GetSkillLineParents()
	sync()
	if not db or type(db.skillLineParents) ~= "table" then
		return {}
	end
	return copy(db.skillLineParents)
end

--- Replaces the skill-line map. Model merges; Store only persists.
function Store.PutSkillLineParents(parents)
	local ok, reason = writable()
	if not ok then
		return false, reason
	end
	if type(parents) ~= "table" then
		return false, "bad skill-line map"
	end
	db.skillLineParents = copy(parents)
	return true
end

--- Every stored snapshot, as copies, in no particular order. Model sorts.
function Store.GetSnapshots()
	sync()
	local out = {}
	if not db or type(db.characters) ~= "table" then
		return out
	end
	for _, snapshot in pairs(db.characters) do
		if type(snapshot) == "table" then
			out[#out + 1] = copy(snapshot)
		end
	end
	return out
end

-- This character's table, read from the global on every call so a table the client assigns
-- late is the one written. Nil before attach, when the client has not assigned it yet.
local function characterTable(create)
	if not diagnostics.attached then
		return nil
	end
	local saved = rawget(_G, CHARACTER_GLOBAL)
	if type(saved) ~= "table" and create then
		saved = {}
		rawset(_G, CHARACTER_GLOBAL, saved)
	end
	return type(saved) == "table" and saved or nil
end

--- This character's window state, as a copy; empty when none was saved.
function Store.GetUIState()
	local saved = characterTable(false)
	if not saved or type(saved.ui) ~= "table" then
		return {}
	end
	return copy(saved.ui)
end

--- Sets one field of this character's window state; nil clears it. Not gated on the account
-- schema: the read-only rule guards the alt list, and this is not part of it.
function Store.PutUIState(name, value)
	local saved = characterTable(true)
	if not saved then
		return false, "store not attached"
	end
	if type(name) ~= "string" then
		return false, "bad field name"
	end
	if type(saved.ui) ~= "table" then
		saved.ui = {}
	end
	saved.ui[name] = copy(value)
	return true
end

function Store.Diagnostics()
	sync()
	local out = copy(diagnostics)
	if db then
		-- False means writes are landing in a table the client will not save.
		out.globalIsOurs = rawget(_G, GLOBAL_NAME) == db
		out.sessions = db.sessions
		out.characters = type(db.characters) == "table" and countKeys(db.characters) or 0
	end
	return out
end
