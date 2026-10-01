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
-- The list stays exhaustive anyway: it is the manifest of what we depend on. It is a manifest,
-- not a lint gate: every read goes through rawget or resolve, so a missing entry does not fail
-- lint. Keep it current by hand.
read_globals = {
	-- Addon plumbing
	"C_AddOns",
	"GetAddOnMetadata",
	"GetBuildInfo",
	"CreateFrame",
	"C_EventUtils",
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
	"UnitFullName",
	"UnitNameUnmodified",
	"UnitGUID",
	"C_PlayerInfo",
	"GetRealmName",
	"GetProfessions",
	"GetProfessionInfo",
	"C_TradeSkillUI",
	"GetServerTime",

	-- UI and Debug (reached through rawget; listed so the manifest stays honest)
	"GameTooltip",
	"C_Timer",
	"InCombatLockdown",
	"UISpecialFrames",
	"GameFontNormalLarge",
	"GameFontHighlightSmall",
	"GameFontNormal",
	"GameFontHighlight",
	"GameFontDisable",
	"GameFontNormalSmall",
	"debugprofilestop",
}

-- Model/ is pure Lua. No WoW global is readable there, so a stray CreateFrame fails lint as
-- well as the strict-environment test in spec/model.
files["LegacyNext/Model/"] = {
	std = "lua51",
	new_globals = {},
	new_read_globals = {},
}

files["spec/"] = {
	std = "lua51+busted",
}

-- Fixtures are captured client data, not code. Reward descriptions run past 120 characters
-- and reflowing them would edit the evidence, which is the one thing a fixture may not do.
files["spec/fixtures/"] = {
	std = "lua51",
	max_line_length = false,
	-- A verbatim paste keeps the padding our renderer printed, trailing spaces included.
	ignore = { "614" },
}
