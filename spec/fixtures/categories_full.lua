-- Captured client data. Do not edit the rows by hand.
--
-- source:    /lgn dump categories (queue row D9), pasted back from the live client
-- date:      2026-09-19
-- build:     1.60.1 (69913), tocVersion 16001
-- pin:       70ef1b2 (1.60.1.69913)
-- character: fresh, nothing completed (numComplete is 0 throughout)
--
-- COMPLETE: all 29 categories, in GetCategoryList order, which is not sorted by id, name or
-- depth. Order is preserved because Api.GetCategories returns the client's order and Model
-- groups off it. Replaces the assembled categories_partial.lua, whose 16 rows this capture
-- confirms field for field.
--
-- numAchievements sums to 111 across the 29, matching the 111-challenge sweep. The seven rows
-- with parentId -1 are the six real top-level groups plus the empty "Do Not Display" bucket.
-- Raids and Adventure both hold achievements of their own AND have children; Classes,
-- Tradeskills and Player vs. Player hold none.

return {
	meta = {
		build = "69913",
		buildString = "1.60.1 (69913)",
		section = "categories",
		tocVersion = 16001,
		version = "1.60.1",
	},
	categories = {
		{ id = 15425, name = "Do Not Display", parentId = -1, numAchievements = 0, numComplete = 0, numIncomplete = 0 },
		{ id = 15577, name = "Druid", parentId = 15568, numAchievements = 3, numComplete = 0, numIncomplete = 3 },
		{ id = 15587, name = "Alchemy", parentId = 15586, numAchievements = 3, numComplete = 0, numIncomplete = 3 },
		{ id = 15597, name = "Ranks", parentId = 15595, numAchievements = 5, numComplete = 0, numIncomplete = 5 },
		{ id = 15607, name = "Explorer", parentId = 15596, numAchievements = 3, numComplete = 0, numIncomplete = 3 },
		{ id = 15626, name = "Tier 1 Gear", parentId = 15594, numAchievements = 0, numComplete = 0, numIncomplete = 0 },
		{ id = 14777, name = "Eastern Kingdoms", parentId = 15596, numAchievements = 23, numComplete = 0, numIncomplete = 23 },
		{ id = 15578, name = "Hunter", parentId = 15568, numAchievements = 3, numComplete = 0, numIncomplete = 3 },
		{ id = 15588, name = "Blacksmithing", parentId = 15586, numAchievements = 3, numComplete = 0, numIncomplete = 3 },
		{ id = 15598, name = "Reputations", parentId = 15595, numAchievements = 4, numComplete = 0, numIncomplete = 4 },
		{ id = 14778, name = "Kalimdor", parentId = 15596, numAchievements = 20, numComplete = 0, numIncomplete = 20 },
		{ id = 15568, name = "Classes", parentId = -1, numAchievements = 0, numComplete = 0, numIncomplete = 0 },
		{ id = 15579, name = "Mage", parentId = 15568, numAchievements = 3, numComplete = 0, numIncomplete = 3 },
		{ id = 15589, name = "Enchanting", parentId = 15586, numAchievements = 3, numComplete = 0, numIncomplete = 3 },
		{ id = 15620, name = "Season Journey", parentId = 15595, numAchievements = 3, numComplete = 0, numIncomplete = 3 },
		{ id = 15580, name = "Paladin", parentId = 15568, numAchievements = 3, numComplete = 0, numIncomplete = 3 },
		{ id = 15586, name = "Tradeskills", parentId = -1, numAchievements = 0, numComplete = 0, numIncomplete = 0 },
		{ id = 15590, name = "Engineering", parentId = 15586, numAchievements = 3, numComplete = 0, numIncomplete = 3 },
		{ id = 15581, name = "Priest", parentId = 15568, numAchievements = 3, numComplete = 0, numIncomplete = 3 },
		{ id = 15591, name = "Leatherworking", parentId = 15586, numAchievements = 3, numComplete = 0, numIncomplete = 3 },
		{ id = 15593, name = "Dungeons", parentId = -1, numAchievements = 3, numComplete = 0, numIncomplete = 3 },
		{ id = 15582, name = "Rogue", parentId = 15568, numAchievements = 3, numComplete = 0, numIncomplete = 3 },
		{ id = 15592, name = "Tailoring", parentId = 15586, numAchievements = 3, numComplete = 0, numIncomplete = 3 },
		{ id = 15594, name = "Raids", parentId = -1, numAchievements = 3, numComplete = 0, numIncomplete = 3 },
		{ id = 15583, name = "Shaman", parentId = 15568, numAchievements = 3, numComplete = 0, numIncomplete = 3 },
		{ id = 15595, name = "Player vs. Player", parentId = -1, numAchievements = 0, numComplete = 0, numIncomplete = 0 },
		{ id = 15584, name = "Warlock", parentId = 15568, numAchievements = 3, numComplete = 0, numIncomplete = 3 },
		{ id = 15596, name = "Adventure", parentId = -1, numAchievements = 2, numComplete = 0, numIncomplete = 2 },
		{ id = 15585, name = "Warrior", parentId = 15568, numAchievements = 3, numComplete = 0, numIncomplete = 3 },
	},
}
