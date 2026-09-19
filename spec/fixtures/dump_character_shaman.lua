-- Captured client data. Do not edit the table below by hand.
--
-- source:    /lgn dump (section "all", LegacyNext 0.0.1)
-- date:      2026-09-19
-- build:     1.60.1 (69913), tocVersion 16001
-- pin:       70ef1b2 (1.60.1.69913)
-- character: fresh level 1 Shaman, no professions
--
-- `professions` is an EMPTY TABLE, not nil -- the read succeeded and the character knows none.
-- That is the absence-versus-failure distinction the Api guard exists to preserve, and it is
-- what a Model test should assert against.
--
-- D4 IS STILL OPEN: this does not show what a populated professions list looks like, so
-- GetProfessions' seven Forever slots remain unverified against a real return.
--
-- `realm` is present and non-empty ("Classic Beta PvP"), which matters for v1's character key
-- -- the Phase 4 note wondered whether a realmless Forever setup would break it. It does not.

return {
	character = {
		class = "Shaman",
		classId = 7,
		classToken = "SHAMAN",
		level = 1,
		name = "Bong Wrip",
		professions = {},
		realm = "Classic Beta PvP",
	},
	meta = {
		build = "69913",
		buildString = "1.60.1 (69913)",
		section = "all",
	},
}
