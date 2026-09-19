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
--
-- Most of these are resolved by name through _G in Api/, so luacheck never sees the reference.
-- The list stays exhaustive anyway: it is the manifest of what we depend on.
read_globals = {
	-- Addon plumbing
	"C_AddOns",
	"GetAddOnMetadata",
	"GetBuildInfo",
	"CreateFrame",
	"UIParent",
	"ChatFontNormal",
	"issecretvalue",
	"Constants",
	"WOW_PROJECT_ID",

	-- Legacy challenges are achievements
	"GetCategoryList",
	"GetCategoryInfo",
	"GetAchievementInfo",
	"GetAchievementNumCriteria",
	"GetAchievementCriteriaInfo",
	"GetAchievementCategory",
	"GetCategoryNumAchievements",
	"GetNumFilteredAchievements",
	"GetFilteredAchievementID",
	"C_AchievementInfo",
	"ACHIEVEMENT_FLAGS_ACCOUNT",
	"EVALUATION_TREE_FLAG_PROGRESS_BAR",

	-- Legacy trees and points are the trait system (read only)
	"C_Traits",
	"LEGACY_TREE_PROFESSIONS",
	"LEGACY_TREE_ADVENTURE",
	"LEGACY_TREE_PROGRESSION",

	-- Legacy reward track is a renown faction
	"C_MajorFactions",

	-- Character state, for the dump and for v1's roster
	"UnitClass",
	"UnitLevel",
	"UnitName",
	"GetRealmName",
	"GetProfessions",
	"GetProfessionInfo",
}

files["spec/"] = {
	std = "lua51+busted",
}
