-- Captured client data. Do not edit the entries below by hand.
--
-- source:    /lgn dump (section "all", LegacyNext 0.0.1), queue row D7
-- date:      2026-09-19
-- build:     1.60.1 (69913), tocVersion 16001
-- pin:       70ef1b2 (1.60.1.69913)
-- character: fresh level 1 Shaman "Bong Wrip", realm "Classic Beta PvP", 0 Legacy points
--
-- EXCERPTED, not invented. Every entry below is copied verbatim from the full 111-challenge
-- dump; nothing is reshaped and no value is filled in. The full dump was not committed whole
-- because the 46 zero-point Explore achievements carry ~600 subzone criteria that Next Up
-- excludes anyway (see Ranking decision 2 in docs/status.md). What is kept is one challenge
-- per distinct criteriaType, plus the only completed criterion on the account.
--
-- WHY THIS FILE EXISTS: before this capture, CLAUDE.md recorded three criteriaType values
-- (7, 8, 43). The full dump has EIGHT. Anything switching exhaustively on criteriaType was
-- already wrong and did not know it.
--
--   type   0 -- encounter / dungeon completion, assetId is an encounter or instance ID
--   type   7 -- skill threshold, assetId is a skill line          (see dump_challenges_page1_fresh)
--   type   8 -- child achievement, assetId is an achievement ID   (see dump_challenges_page1_fresh)
--   type  27 -- journey/quest step, assetId is a quest ID
--   type  43 -- area discovery, assetId is an area ID             (see dump_challenges_page1_fresh)
--   type  78 -- dungeon with alternatives ("X or Y"), assetId is 0
--   type 165 -- raid encounter variant, assetId is an encounter ID
--   type 243 -- reputation threshold, assetId is a faction ID
--
-- THE RANKING TRAP, and the reason this file is worth more than its size: the type-243
-- reputation criteria carry `need = 42000` with `have = 0`, but `isProgressBar = false` and
-- `flags = 1024` -- bit 1 is clear, so the progress-bar test says "checklist". Scored as a
-- checklist, "Master of Alterac Valley" reads as one step from done. It is 0/42000 reputation.
-- Closeness must consider need/have whenever need > 1, not only when the progress-bar bit is
-- set.

return {
	meta = {
		build = "69913",
		buildString = "1.60.1 (69913)",
		excerptOf = "section \"all\", 111 challenges",
		section = "criteria-types",
	},

	-- type 78 (assetId 0, alternatives in one criterion) and type 0 in the same challenge.
	dungeons = {
		categoryId = 15593,
		categoryIndex = 1,
		categoryName = "Dungeons",
		completed = false,
		criteria = {
			{
				assetId = 0,
				completed = false,
				criteriaType = 78,
				flags = 0,
				have = 0,
				index = 1,
				isProgressBar = false,
				need = 1,
				quantityString = "0",
				text = "Ragefire Chasm or Hall of Thanes",
			},
			{
				assetId = 250657,
				completed = false,
				criteriaType = 0,
				flags = 0,
				have = 0,
				index = 2,
				isProgressBar = false,
				need = 1,
				quantityString = "0",
				text = "Ruins of Lordaeron",
			},
			{
				assetId = 639,
				completed = false,
				criteriaType = 0,
				flags = 0,
				have = 0,
				index = 4,
				isProgressBar = false,
				need = 1,
				quantityString = "0",
				text = "The Deadmines",
			},
		},
		criteriaExpected = 6,
		description = "Complete the following dungeons.",
		flags = 134349824,
		icon = 4504543,
		id = 62031,
		isAccountWide = true,
		name = "Novice Spelunker",
		parentCategoryId = -1,
		points = 1,
		rewardText = "Earn 1 Legacy Point.",
		wasEarnedByMe = false,
	},

	-- type 243. need = 42000 with isProgressBar false -- see THE RANKING TRAP above.
	-- Note the description names two factions ("Frostwolf Clan or Stormpike Guard") while the
	-- criteria list carries only the one matching this character's faction.
	reputation = {
		categoryId = 15598,
		categoryIndex = 1,
		categoryName = "Reputations",
		completed = false,
		criteria = {
			{
				assetId = 729,
				completed = false,
				criteriaType = 243,
				flags = 1024,
				have = 0,
				index = 1,
				isProgressBar = false,
				need = 42000,
				quantityString = "0",
				text = "Reach exalted reputation with the Frostwolf Clan",
			},
		},
		criteriaExpected = 1,
		description = "Reach exalted reputation with the Frostwolf Clan or Stormpike Guard.",
		flags = 134349824,
		icon = 236711,
		id = 62046,
		isAccountWide = true,
		name = "Master of Alterac Valley",
		parentCategoryId = 15595,
		points = 1,
		rewardText = "Earn 1 Legacy Point.",
		wasEarnedByMe = false,
	},

	-- type 27, assetId is a quest ID.
	seasonJourney = {
		categoryId = 15620,
		categoryIndex = 1,
		categoryName = "Season Journey",
		completed = false,
		criteria = {
			{
				assetId = 96915,
				completed = false,
				criteriaType = 27,
				flags = 0,
				have = 0,
				index = 1,
				isProgressBar = false,
				need = 1,
				quantityString = "0",
				text = "Complete Field of Honor: Week 4",
			},
		},
		criteriaExpected = 1,
		description = "Complete Week 4 of the Field of Honor Journey.",
		flags = 134349824,
		icon = 2022756,
		id = 63340,
		isAccountWide = true,
		name = "Field of Honor: Week 4",
		parentCategoryId = 15595,
		points = 1,
		rewardText = "Earn 1 Legacy Point.",
		wasEarnedByMe = false,
	},

	-- type 165 alongside type 0 in one raid challenge.
	raid = {
		categoryId = 15594,
		categoryIndex = 1,
		categoryName = "Raids",
		completed = false,
		criteria = {
			{
				assetId = 249790,
				completed = false,
				criteriaType = 0,
				flags = 0,
				have = 0,
				index = 1,
				isProgressBar = false,
				need = 1,
				quantityString = "0",
				text = "Bandalar",
			},
			{
				assetId = 3339,
				completed = false,
				criteriaType = 165,
				flags = 0,
				have = 0,
				index = 3,
				isProgressBar = false,
				need = 1,
				quantityString = "0",
				text = "Time-Lost Battalion",
			},
		},
		criteriaExpected = 13,
		description = "Defeat the following encounters in Hyjal Summit.",
		flags = 134349824,
		icon = 409547,
		id = 62034,
		isAccountWide = true,
		name = "Conquerer of the Wilds",
		parentCategoryId = -1,
		points = 1,
		rewardText = "Earn 1 Legacy Point.",
		wasEarnedByMe = false,
	},

	-- The ONLY completed criterion anywhere on this account, and the only sighting of
	-- `charName`. Partially answers C3 (a part-done challenge: 1 of 11) and C4 (`charName`
	-- populated on completion). Note the achievement is per-character (isAccountWide false)
	-- yet charName is still set, and `wasEarnedByMe` is false because the achievement itself
	-- is not complete.
	partiallyDone = {
		categoryId = 14778,
		categoryIndex = 6,
		categoryName = "Kalimdor",
		completed = false,
		criteria = {
			{
				assetId = 242,
				charName = "Bong",
				completed = true,
				criteriaType = 43,
				flags = 0,
				have = 1,
				index = 10,
				isProgressBar = false,
				need = 1,
				quantityString = "1",
				text = "Valley of Trials",
			},
			{
				assetId = 260,
				completed = false,
				criteriaType = 43,
				flags = 0,
				have = 0,
				index = 11,
				isProgressBar = false,
				need = 1,
				quantityString = "0",
				text = "Skull Rock",
			},
		},
		criteriaExpected = 11,
		description = "Explore Durotar, revealing the covered areas of the world map.",
		flags = 0,
		icon = 236756,
		id = 728,
		isAccountWide = false,
		name = "Explore Durotar",
		parentCategoryId = 15596,
		points = 0,
		rewardText = "",
		wasEarnedByMe = false,
	},

	-- The real point-bearing Explorer, head of the meta chain. Its single type-8 criterion
	-- points at Explore Azeroth (62053), which is itself two more levels deep.
	explorerMeta = {
		categoryId = 15596,
		categoryIndex = 2,
		categoryName = "Adventure",
		completed = false,
		criteria = {
			{
				assetId = 62053,
				completed = false,
				criteriaType = 8,
				flags = 0,
				have = 0,
				index = 1,
				isProgressBar = false,
				need = 1,
				quantityString = "0",
				text = "Explorer",
			},
		},
		criteriaExpected = 1,
		description = "Have a character with the Explore Azeroth achievement.",
		flags = 134349824,
		icon = 237387,
		id = 62382,
		isAccountWide = true,
		name = "Explorer",
		parentCategoryId = -1,
		points = 1,
		rewardText = "Earn 1 Legacy Point.",
		wasEarnedByMe = false,
	},
}
