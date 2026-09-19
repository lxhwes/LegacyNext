-- Captured client data, ASSEMBLED from two earlier captures. Do not edit the rows by hand.
--
-- source:    (a) the section-B category sweep, script C3 in docs/ingame-commands.md, output
--                recorded verbatim in docs/legacy-internals.md "The live category tree"
--            (b) the categoryId / categoryName / parentCategoryId triples carried by every
--                challenge in dump_challenges_page1_fresh.lua (D3) and dump_criteria_types.lua
--                (D7), which Api.GetChallenges read through GetCategoryInfo
-- date:      2026-09-18 (a), 2026-09-19 (b)
-- build:     1.60.1 (69913), tocVersion 16001
-- pin:       70ef1b2 (1.60.1.69913)
-- character: fresh level 1 Shaman, nothing completed
--
-- PARTIAL, not invented. The live tree has 29 categories; this file carries the 16 whose id,
-- name and parent were all captured. The 13 missing are the other eight class categories
-- (Hunter ... Warrior) and the other five tradeskill categories (Blacksmithing ... Tailoring):
-- the sweep recorded their names and counts but not their ids, so they are OMITTED rather
-- than guessed. Order below is the doc table's (top level, then children), NOT the client's
-- GetCategoryList order, which the sweep did not preserve.
--
-- Queue row D9 (`/lgn dump categories`) replaces this with a complete capture in client order.
--
-- Shape matches Api.GetCategories: { id, name, parentId, numAchievements }. numComplete and
-- numIncomplete were not carried into the doc table and are left out here.

return {
	meta = {
		build = "69913",
		buildString = "1.60.1 (69913)",
		section = "categories-partial",
	},
	categories = {
		{ id = 15425, name = "Do Not Display", parentId = -1, numAchievements = 0 },
		{ id = 15568, name = "Classes", parentId = -1, numAchievements = 0 },
		{ id = 15577, name = "Druid", parentId = 15568, numAchievements = 3 },
		{ id = 15586, name = "Tradeskills", parentId = -1, numAchievements = 0 },
		{ id = 15587, name = "Alchemy", parentId = 15586, numAchievements = 3 },
		{ id = 15593, name = "Dungeons", parentId = -1, numAchievements = 3 },
		{ id = 15594, name = "Raids", parentId = -1, numAchievements = 3 },
		{ id = 15626, name = "Tier 1 Gear", parentId = 15594, numAchievements = 0 },
		{ id = 15595, name = "Player vs. Player", parentId = -1, numAchievements = 0 },
		{ id = 15597, name = "Ranks", parentId = 15595, numAchievements = 5 },
		{ id = 15598, name = "Reputations", parentId = 15595, numAchievements = 4 },
		{ id = 15620, name = "Season Journey", parentId = 15595, numAchievements = 3 },
		{ id = 15596, name = "Adventure", parentId = -1, numAchievements = 2 },
		{ id = 15607, name = "Explorer", parentId = 15596, numAchievements = 3 },
		{ id = 14777, name = "Eastern Kingdoms", parentId = 15596, numAchievements = 23 },
		{ id = 14778, name = "Kalimdor", parentId = 15596, numAchievements = 20 },
	},
}
