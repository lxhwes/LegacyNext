local helper = require("spec.spec_helper")

-- Store's only global is LegacyNextDB, which the client assigns before ADDON_LOADED. These
-- tests play the client: set the global, load the file, attach.
local function loadStore()
	return helper.loadAddonFile("LegacyNext/Store/Store.lua").Store
end

describe("Store", function()
	after_each(function()
		_G.LegacyNextDB = nil
		_G.LegacyNextCharDB = nil
	end)

	it("starts a fresh table when nothing was saved, and says so", function()
		local Store = loadStore()

		assert.is_true(Store.Attach())

		local d = Store.Diagnostics()
		assert.equals("nil", d.loadedType)
		assert.equals(0, d.loadedSessions)
		assert.equals(1, d.sessions)
		assert.equals(1, _G.LegacyNextDB.schema)
	end)

	it("keeps what was saved and counts the session", function()
		_G.LegacyNextDB = { schema = 1, sessions = 4, characters = { ["A-R"] = { key = "A-R" } } }
		local Store = loadStore()

		Store.Attach()

		local d = Store.Diagnostics()
		assert.equals("table", d.loadedType)
		assert.equals(4, d.loadedSessions)
		assert.equals(1, d.loadedCharacters)
		assert.equals(5, d.sessions)
		assert.equals("A-R", Store.GetSnapshot("A-R").key)
	end)

	it("round-trips a snapshot through the global, as a copy", function()
		local Store = loadStore()
		Store.Attach()
		local snapshot = { key = "A-R", level = 10 }

		assert.is_true(Store.PutSnapshot("A-R", snapshot))
		snapshot.level = 99

		assert.equals(10, _G.LegacyNextDB.characters["A-R"].level)
		local read = Store.GetSnapshot("A-R")
		read.level = 50
		assert.equals(10, Store.GetSnapshot("A-R").level)
	end)

	it("lists and forgets characters", function()
		local Store = loadStore()
		Store.Attach()
		Store.PutSnapshot("A-R", { key = "A-R" })
		Store.PutSnapshot("B-R", { key = "B-R" })

		assert.equals(2, #Store.GetSnapshots())
		assert.is_true(Store.Forget("A-R"))
		assert.is_false(Store.Forget("A-R"))
		assert.equals(1, #Store.GetSnapshots())
	end)

	it("refuses writes before attach", function()
		local Store = loadStore()

		local ok, reason = Store.PutSnapshot("A-R", {})

		assert.is_false(ok)
		assert.equals("store not attached", reason)
		assert.same({}, Store.GetSnapshots())
	end)

	it("leaves a newer schema untouched and read-only", function()
		_G.LegacyNextDB = { schema = 2, characters = { ["A-R"] = { key = "A-R" } }, future = true }
		local Store = loadStore()

		local ok, reason = Store.Attach()

		assert.is_false(ok)
		assert.truthy(reason:find("schema 2", 1, true))
		assert.is_false((Store.PutSnapshot("B-R", {})))
		assert.is_false((Store.Forget("A-R")))
		assert.equals(2, _G.LegacyNextDB.schema)
		assert.is_true(_G.LegacyNextDB.future)
		assert.is_nil(_G.LegacyNextDB.sessions)
	end)

	it("logs snapshot results for the next session, keeping the last LOG_LIMIT", function()
		_G.LegacyNextDB = { schema = 1, sessions = 2, snapshotLog = { { session = 2, at = 1, text = "old" } } }
		local Store = loadStore()
		Store.Attach()

		for index = 1, Store.LOG_LIMIT + 2 do
			assert.is_true(Store.LogSnapshot(100 + index, "result " .. index))
		end

		local log = _G.LegacyNextDB.snapshotLog
		assert.equals(Store.LOG_LIMIT, #log)
		assert.same({ session = 3, at = 100 + Store.LOG_LIMIT + 2, text = "result " .. (Store.LOG_LIMIT + 2) },
			log[#log])
		assert.same({ { session = 2, at = 1, text = "old" } }, Store.Diagnostics().loadedLog)
	end)

	it("refuses to log before attach or into a newer schema", function()
		local Store = loadStore()
		assert.is_false((Store.LogSnapshot(1, "x")))

		_G.LegacyNextDB = { schema = 2 }
		Store = loadStore()
		Store.Attach()
		assert.is_false((Store.LogSnapshot(1, "x")))
		assert.is_nil(_G.LegacyNextDB.snapshotLog)
	end)

	it("repairs a table whose characters field is junk", function()
		_G.LegacyNextDB = { schema = 1, characters = "oops" }
		local Store = loadStore()

		assert.is_true(Store.Attach())
		assert.is_true(Store.PutSnapshot("A-R", { key = "A-R" }))
	end)

	it("round-trips the skill-line map account-wide, as a copy", function()
		local Store = loadStore()
		assert.same({}, Store.GetSkillLineParents())
		assert.is_false((Store.PutSkillLineParents({})))

		Store.Attach()
		local map = { [2937] = { parentId = 171 } }
		assert.is_true(Store.PutSkillLineParents(map))
		map[2937].parentId = 1

		assert.equals(171, _G.LegacyNextDB.skillLineParents[2937].parentId)
		assert.equals(171, Store.GetSkillLineParents()[2937].parentId)
		assert.is_false((Store.PutSkillLineParents("junk")))
	end)

	describe("window state", function()
		it("reads nothing and refuses writes before attach", function()
			local Store = loadStore()

			assert.same({}, Store.GetUIState())
			local ok, reason = Store.PutUIState("tab", "roster")
			assert.is_false(ok)
			assert.equals("store not attached", reason)
			assert.is_nil(_G.LegacyNextCharDB)
		end)

		it("keeps it per character, in LegacyNextCharDB, as a copy", function()
			local Store = loadStore()
			Store.Attach()
			local point = { left = 10, top = 600 }

			assert.is_true(Store.PutUIState("tab", "roster"))
			assert.is_true(Store.PutUIState("point", point))
			point.left = 99

			assert.equals("roster", _G.LegacyNextCharDB.ui.tab)
			assert.equals(10, _G.LegacyNextCharDB.ui.point.left)
			local read = Store.GetUIState()
			assert.same({ tab = "roster", point = { left = 10, top = 600 } }, read)
			read.point.left = 50
			assert.equals(10, Store.GetUIState().point.left)
			assert.is_nil(_G.LegacyNextDB.ui)
		end)

		it("reads what was saved, adds to it, and clears a field set to nil", function()
			_G.LegacyNextCharDB = { other = true, ui = { tab = "roster", filter = 15 } }
			local Store = loadStore()
			Store.Attach()

			assert.same({ tab = "roster", filter = 15 }, Store.GetUIState())
			assert.is_true(Store.PutUIState("filter", nil))

			assert.same({ tab = "roster" }, Store.GetUIState())
			assert.is_true(_G.LegacyNextCharDB.other)
		end)

		it("replaces a saved table that is junk", function()
			_G.LegacyNextCharDB = "oops"
			local Store = loadStore()
			Store.Attach()

			assert.same({}, Store.GetUIState())
			assert.is_true(Store.PutUIState("tab", "roster"))
			assert.equals("roster", _G.LegacyNextCharDB.ui.tab)
		end)

		-- The read-only rule protects the account's alt list from a downgrade; window state is
		-- this character's and holds nothing a downgrade could lose.
		it("still saves under a newer account schema", function()
			_G.LegacyNextDB = { schema = 2 }
			local Store = loadStore()
			Store.Attach()

			assert.is_true(Store.PutUIState("tab", "roster"))
			assert.equals("roster", Store.GetUIState().tab)
			assert.is_nil(_G.LegacyNextDB.ui)
		end)

		it("refuses a field name that is not a string", function()
			local Store = loadStore()
			Store.Attach()

			assert.is_false((Store.PutUIState(1, "x")))
		end)
	end)

	describe("settings", function()
		it("reads nothing and refuses writes before attach", function()
			local Store = loadStore()

			assert.same({}, Store.GetSettings())
			local ok, reason = Store.PutSetting("minimapHidden", true)
			assert.is_false(ok)
			assert.equals("store not attached", reason)
		end)

		it("keeps them account-wide, in LegacyNextDB, as a copy", function()
			local Store = loadStore()
			Store.Attach()

			assert.is_true(Store.PutSetting("minimapHidden", true))
			assert.is_true(Store.PutSetting("minimapAngle", 200))

			assert.same({ minimapHidden = true, minimapAngle = 200 }, _G.LegacyNextDB.settings)
			local read = Store.GetSettings()
			read.minimapAngle = 1
			assert.equals(200, Store.GetSettings().minimapAngle)
			assert.is_nil(_G.LegacyNextCharDB)
		end)

		it("reads what an earlier session saved, and clears a setting set to nil", function()
			_G.LegacyNextDB = { schema = 1, sessions = 1, characters = {},
				settings = { minimapLocked = true, minimapAngle = 90 } }
			local Store = loadStore()
			Store.Attach()

			assert.same({ minimapLocked = true, minimapAngle = 90 }, Store.GetSettings())
			assert.is_true(Store.PutSetting("minimapLocked", nil))
			assert.same({ minimapAngle = 90 }, Store.GetSettings())
		end)

		it("replaces a saved settings field that is junk", function()
			_G.LegacyNextDB = { schema = 1, sessions = 1, characters = {}, settings = "oops" }
			local Store = loadStore()
			Store.Attach()

			assert.same({}, Store.GetSettings())
			assert.is_true(Store.PutSetting("minimapHidden", false))
			assert.is_false(_G.LegacyNextDB.settings.minimapHidden)
		end)

		it("refuses writes into a newer schema, which may lay them out differently", function()
			_G.LegacyNextDB = { schema = 99, settings = { minimapHidden = true } }
			local Store = loadStore()
			Store.Attach()

			assert.same({ minimapHidden = true }, Store.GetSettings())
			assert.is_false((Store.PutSetting("minimapHidden", false)))
			assert.is_true(_G.LegacyNextDB.settings.minimapHidden)
		end)

		it("refuses a setting name that is not a string", function()
			local Store = loadStore()
			Store.Attach()

			assert.is_false((Store.PutSetting(1, true)))
		end)
	end)

	-- Hypothetical until S1: the client assigning the loaded table after ADDON_LOADED.
	describe("a table assigned after attach", function()
		it("is adopted, with this session's writes replayed onto it", function()
			local Store = loadStore()
			Store.Attach()
			Store.PutSnapshot("Me-R", { key = "Me-R", level = 10 })

			_G.LegacyNextDB = { schema = 1, sessions = 3,
				characters = { ["Alt-R"] = { key = "Alt-R" }, ["Me-R"] = { key = "Me-R", level = 9 } } }
			local adopted = _G.LegacyNextDB
			local d = Store.Diagnostics()

			assert.equals(1, d.lateLoads)
			assert.equals("table", d.loadedType)
			assert.equals(3, d.loadedSessions)
			assert.equals(4, d.sessions)
			assert.is_true(d.globalIsOurs)
			assert.equals(adopted, _G.LegacyNextDB)
			assert.equals(10, adopted.characters["Me-R"].level)
			assert.is_table(adopted.characters["Alt-R"])
		end)

		it("replays a forget too", function()
			local Store = loadStore()
			Store.Attach()
			Store.PutSnapshot("Gone-R", { key = "Gone-R" })
			Store.Forget("Gone-R")

			_G.LegacyNextDB = { schema = 1, characters = { ["Gone-R"] = { key = "Gone-R" } } }
			Store.PutSnapshot("Me-R", { key = "Me-R" })

			assert.is_nil(_G.LegacyNextDB.characters["Gone-R"])
			assert.is_table(_G.LegacyNextDB.characters["Me-R"])
		end)

		it("reports a global cleared under it", function()
			local Store = loadStore()
			Store.Attach()

			_G.LegacyNextDB = nil

			assert.is_false(Store.Diagnostics().globalIsOurs)
		end)
	end)
end)
