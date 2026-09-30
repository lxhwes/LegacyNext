local _, ns = ...

-- SavedVariables behind an interface. Nothing else in the addon names LegacyNextDB, so a change
-- in how the client persists it -- the beta bug where SavedVariables were written but never
-- loaded back, reported fixed 2026-09-30 and unverified until S1 -- stays a one-file change.
--
-- Layout, schema 1:
--   LegacyNextDB = {
--     schema = 1,
--     sessions = <number of times the addon loaded with this table>,
--     characters = { ["Name-Realm"] = <Model.BuildSnapshot output>, ... },
--   }
--
-- Store never interprets a snapshot. Merging, validating and rendering them is Model's job.
ns.Store = ns.Store or {}
local Store = ns.Store

Store.SCHEMA = 1
local GLOBAL_NAME = "LegacyNextDB"

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

local function writable()
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
	return true
end

--- Every stored snapshot, as copies, in no particular order. Model sorts.
function Store.GetSnapshots()
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

function Store.Diagnostics()
	local out = copy(diagnostics)
	if db then
		out.sessions = db.sessions
		out.characters = type(db.characters) == "table" and countKeys(db.characters) or 0
	end
	return out
end
