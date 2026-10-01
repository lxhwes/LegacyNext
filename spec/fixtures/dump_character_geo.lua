-- Captured client data. Do not edit the tables below by hand.
--
-- source:    /lgn dump character (LegacyNext dev build from main, PR #4 merged)
-- date:      2026-10-01
-- build:     1.60.1 (70124), tocVersion 16001
-- pin:       966519c (1.60.1.70124)
-- character: Geo Prizm (first name Geo, surname Prizm), Classic Beta PvP, level 6 Druid,
--            Alchemy 1/75, Herbalism 20/75, Cooking 1/75. Queue row D4.
-- via:       Alex's gist "lgn dump character", 2026-10-01
--
-- `slot` is the position in GetProfessions' returns: primaries at 1 and 2, Cooking at 5.
-- `skillLineId` is GetProfessionInfo's seventh return, and reads the Classic line for all
-- three, Alchemy's 171 included, not the Forever child 2937 a tradeskill challenge names.
-- `name` is the first name only, though the character's full name is "Geo Prizm".
--
-- The `failures` tally from the capture is omitted, as in dump_character_shaman.lua: it
-- records our guard's behaviour at capture time, not client data. It read no secret, error
-- or missing call.

return {
	character = {
		class = "Druid",
		classId = 11,
		classToken = "DRUID",
		level = 6,
		name = "Geo",
		professions = {
			{
				icon = 136240,
				max = 75,
				modifier = 0,
				name = "Alchemy",
				skill = 1,
				skillIndex = 4,
				skillLineId = 171,
				skillLineName = "Alchemy",
				slot = 1,
			},
			{
				icon = 136246,
				max = 75,
				modifier = 0,
				name = "Herbalism",
				skill = 20,
				skillIndex = 5,
				skillLineId = 182,
				skillLineName = "Herbalism",
				slot = 2,
			},
			{
				icon = 133971,
				max = 75,
				modifier = 0,
				name = "Cooking",
				skill = 1,
				skillIndex = 6,
				skillLineId = 185,
				skillLineName = "Cooking",
				slot = 5,
			},
		},
		realm = "Classic Beta PvP",
	},
	meta = {
		addon = "LegacyNext",
		addonVersion = "dev",
		build = "70124",
		buildDate = "Sep 29 2026",
		buildString = "1.60.1 (70124)",
		flags = {
			eventDrivenRefresh = false,
			followMetaChains = false,
		},
		section = "character",
		tocVersion = 16001,
		version = "1.60.1",
		wowProjectId = 1,
	},
}
