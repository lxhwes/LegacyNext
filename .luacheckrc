std = "lua51"
max_line_length = 120
codes = true

exclude_files = {
	"vendor/",
	"tools/",
}

-- Globals the addon writes.
globals = {
	"LegacyNextDB",
	"LegacyNextCharDB",
	"SLASH_LEGACYNEXT1",
	"SLASH_LEGACYNEXT2",
	"SlashCmdList",
}

-- WoW globals the addon reads. Keep this list to what we actually call: an entry here is a
-- claim that the API exists, and Api/ still has to feature-detect it at runtime.
read_globals = {
	-- Addon plumbing
	"C_AddOns",
	"GetAddOnMetadata",
	"CreateFrame",
	"UIParent",
	"issecretvalue",
	"Constants",

	-- Legacy challenges are achievements
	"GetAchievementInfo",
	"GetAchievementNumCriteria",
	"GetAchievementCriteriaInfo",
	"GetAchievementCategory",
	"GetCategoryNumAchievements",
	"GetNumFilteredAchievements",
	"GetFilteredAchievementID",
	"C_AchievementInfo",

	-- Legacy trees and points are the trait system (read only)
	"C_Traits",

	-- Legacy reward track is a renown faction
	"C_MajorFactions",
}

files["spec/"] = {
	std = "lua51+busted",
}
