-- Captured client data. Do not edit the table below by hand.
--
-- source:    /lgn roster, its `== RAW ==` block. The rendered text above that block is kept
--            verbatim at the bottom of this file.
-- date:      2026-10-01
-- build:     1.60.1 (70124), from the paste's own first line
-- pin:       966519c (1.60.1.70124)
-- character: Geo-Classic Beta PvP, level 5 Druid, Herbalism 13/75 and Cooking 1/75, no Legacy
--            points. This is session 2. Session 1 was Bong-Classic Beta PvP (level 1 Shaman, no
--            professions), which logged out to character select before Geo logged in. Queue row
--            S1, steps 1 and 3, without the /reload of step 2 or the restart of step 4.
-- via:       Alex's gist "lgn roster", 2026-10-01
--
-- `parentsLive` is what C_TradeSkillUI.GetProfessionInfoBySkillLineID returned on a character
-- who knows none of the six tradeskills. `raw` is the client's struct, copied by Api; the
-- fields beside it are Api's reading of it. `snapshots` and `diagnostics` are our own Store
-- shapes, written by the addon in game, so they are evidence of what the addon did, not of a
-- client API's shape.
--
-- No `now` and no this-session snapshot log: /lgn roster's RAW block does not carry them.

return {
	diagnostics = {
		attached = true,
		characters = 2,
		globalIsOurs = true,
		loadedCharacters = 1,
		loadedLog = {
			{
				at = 1790845245,
				session = 1,
				text = "SKILL_LINES_CHANGED+PLAYER_LOGIN -> written",
			},
			{
				at = 1790845303,
				session = 1,
				text = "PLAYER_LOGOUT -> written; trees: unspent points not read",
			},
		},
		loadedSchema = 1,
		loadedSessions = 1,
		loadedType = "table",
		sessions = 2,
	},
	parents = {
		[2937] = {
			name = "Alchemy",
			parentId = 171,
			parentName = "Alchemy",
			professionId = 2937,
			raw = {
				expansionName = "Alchemy",
				isPrimaryProfession = true,
				maxSkillLevel = 0,
				parentProfessionID = 171,
				parentProfessionName = "Alchemy",
				profession = 3,
				professionID = 2937,
				professionName = "Alchemy",
				skillLevel = 0,
				skillModifier = 0,
				sourceCounter = 2,
			},
		},
		[2938] = {
			name = "Blacksmithing",
			parentId = 164,
			parentName = "Blacksmithing",
			professionId = 2938,
			raw = {
				expansionName = "Blacksmithing",
				isPrimaryProfession = true,
				maxSkillLevel = 0,
				parentProfessionID = 164,
				parentProfessionName = "Blacksmithing",
				profession = 1,
				professionID = 2938,
				professionName = "Blacksmithing",
				skillLevel = 0,
				skillModifier = 0,
				sourceCounter = 2,
			},
		},
		[2940] = {
			name = "Enchanting",
			parentId = 333,
			parentName = "Enchanting",
			professionId = 2940,
			raw = {
				expansionName = "Enchanting",
				isPrimaryProfession = true,
				maxSkillLevel = 0,
				parentProfessionID = 333,
				parentProfessionName = "Enchanting",
				profession = 9,
				professionID = 2940,
				professionName = "Enchanting",
				skillLevel = 0,
				skillModifier = 0,
				sourceCounter = 2,
			},
		},
		[2941] = {
			name = "Engineering",
			parentId = 202,
			parentName = "Engineering",
			professionId = 2941,
			raw = {
				expansionName = "Engineering",
				isPrimaryProfession = true,
				maxSkillLevel = 0,
				parentProfessionID = 202,
				parentProfessionName = "Engineering",
				profession = 8,
				professionID = 2941,
				professionName = "Engineering",
				skillLevel = 0,
				skillModifier = 0,
				sourceCounter = 2,
			},
		},
		[2945] = {
			name = "Leatherworking",
			parentId = 165,
			parentName = "Leatherworking",
			professionId = 2945,
			raw = {
				expansionName = "Leatherworking",
				isPrimaryProfession = true,
				maxSkillLevel = 0,
				parentProfessionID = 165,
				parentProfessionName = "Leatherworking",
				profession = 2,
				professionID = 2945,
				professionName = "Leatherworking",
				skillLevel = 0,
				skillModifier = 0,
				sourceCounter = 2,
			},
		},
		[2948] = {
			name = "Tailoring",
			parentId = 197,
			parentName = "Tailoring",
			professionId = 2948,
			raw = {
				expansionName = "Tailoring",
				isPrimaryProfession = true,
				maxSkillLevel = 0,
				parentProfessionID = 197,
				parentProfessionName = "Tailoring",
				profession = 7,
				professionID = 2948,
				professionName = "Tailoring",
				skillLevel = 0,
				skillModifier = 0,
				sourceCounter = 2,
			},
		},
	},
	parentsLive = {
		[2937] = {
			name = "Alchemy",
			parentId = 171,
			parentName = "Alchemy",
			professionId = 2937,
			raw = {
				expansionName = "Alchemy",
				isPrimaryProfession = true,
				maxSkillLevel = 0,
				parentProfessionID = 171,
				parentProfessionName = "Alchemy",
				profession = 3,
				professionID = 2937,
				professionName = "Alchemy",
				skillLevel = 0,
				skillModifier = 0,
				sourceCounter = 2,
			},
		},
		[2938] = {
			name = "Blacksmithing",
			parentId = 164,
			parentName = "Blacksmithing",
			professionId = 2938,
			raw = {
				expansionName = "Blacksmithing",
				isPrimaryProfession = true,
				maxSkillLevel = 0,
				parentProfessionID = 164,
				parentProfessionName = "Blacksmithing",
				profession = 1,
				professionID = 2938,
				professionName = "Blacksmithing",
				skillLevel = 0,
				skillModifier = 0,
				sourceCounter = 2,
			},
		},
		[2940] = {
			name = "Enchanting",
			parentId = 333,
			parentName = "Enchanting",
			professionId = 2940,
			raw = {
				expansionName = "Enchanting",
				isPrimaryProfession = true,
				maxSkillLevel = 0,
				parentProfessionID = 333,
				parentProfessionName = "Enchanting",
				profession = 9,
				professionID = 2940,
				professionName = "Enchanting",
				skillLevel = 0,
				skillModifier = 0,
				sourceCounter = 2,
			},
		},
		[2941] = {
			name = "Engineering",
			parentId = 202,
			parentName = "Engineering",
			professionId = 2941,
			raw = {
				expansionName = "Engineering",
				isPrimaryProfession = true,
				maxSkillLevel = 0,
				parentProfessionID = 202,
				parentProfessionName = "Engineering",
				profession = 8,
				professionID = 2941,
				professionName = "Engineering",
				skillLevel = 0,
				skillModifier = 0,
				sourceCounter = 2,
			},
		},
		[2945] = {
			name = "Leatherworking",
			parentId = 165,
			parentName = "Leatherworking",
			professionId = 2945,
			raw = {
				expansionName = "Leatherworking",
				isPrimaryProfession = true,
				maxSkillLevel = 0,
				parentProfessionID = 165,
				parentProfessionName = "Leatherworking",
				profession = 2,
				professionID = 2945,
				professionName = "Leatherworking",
				skillLevel = 0,
				skillModifier = 0,
				sourceCounter = 2,
			},
		},
		[2948] = {
			name = "Tailoring",
			parentId = 197,
			parentName = "Tailoring",
			professionId = 2948,
			raw = {
				expansionName = "Tailoring",
				isPrimaryProfession = true,
				maxSkillLevel = 0,
				parentProfessionID = 197,
				parentProfessionName = "Tailoring",
				profession = 7,
				professionID = 2948,
				professionName = "Tailoring",
				skillLevel = 0,
				skillModifier = 0,
				sourceCounter = 2,
			},
		},
	},
	skillLines = {
		2937,
		2938,
		2940,
		2941,
		2945,
		2948,
	},
	snapshots = {
		{
			cap = 16,
			class = "Druid",
			classToken = "DRUID",
			key = "Geo-Classic Beta PvP",
			level = 5,
			name = "Geo",
			professions = {
				{
					max = 75,
					name = "Herbalism",
					skill = 13,
					skillLineId = 182,
				},
				{
					max = 75,
					name = "Cooking",
					skill = 1,
					skillLineId = 185,
				},
			},
			professionsAt = 1790848168,
			realm = "Classic Beta PvP",
			spent = 0,
			takenAt = 1790848168,
			trees = {
				{
					name = "Professions",
					spent = 0,
					treeId = 1187,
				},
				{
					name = "Adventure",
					spent = 0,
					treeId = 1188,
				},
				{
					name = "Resourcefulness",
					spent = 0,
					treeId = 1189,
				},
			},
			treesAt = 1790848168,
			unspent = 0,
		},
		{
			cap = 16,
			class = "Shaman",
			classToken = "SHAMAN",
			key = "Bong-Classic Beta PvP",
			level = 1,
			name = "Bong",
			professions = {},
			professionsAt = 1790845303,
			realm = "Classic Beta PvP",
			spent = 0,
			takenAt = 1790845303,
			trees = {
				{
					name = "Professions",
					spent = 0,
					treeId = 1187,
				},
				{
					name = "Adventure",
					spent = 0,
					treeId = 1188,
				},
				{
					name = "Resourcefulness",
					spent = 0,
					treeId = 1189,
				},
			},
			treesAt = 1790845245,
			treesReason = "unspent points not read",
			unspent = 0,
		},
	},
}

--[==[ Rendered text, verbatim:
LegacyNext roster  1.60.1 (70124)
== STORE ==
attached=true loadedType=table loadedSessions=1 loadedCharacters=1 sessions=2 characters=2
this snapshot: roster command -> written
snapshots this session:
  45m ago  SKILL_LINES_CHANGED+PLAYER_LOGIN -> written
  43m ago  SKILL_LINES_CHANGED -> written
  42m ago  SKILL_LINES_CHANGED -> written
  42m ago  SKILL_LINES_CHANGED -> written
  42m ago  SKILL_LINES_CHANGED+PLAYER_LEVEL_UP -> written
  42m ago  SKILL_LINES_CHANGED -> written
  41m ago  SKILL_LINES_CHANGED -> written
  41m ago  SKILL_LINES_CHANGED -> written
  41m ago  SKILL_LINES_CHANGED -> written
  41m ago  SKILL_LINES_CHANGED -> written
  41m ago  SKILL_LINES_CHANGED -> written
  40m ago  SKILL_LINES_CHANGED -> written
  34m ago  PLAYER_LEVEL_UP+SKILL_LINES_CHANGED -> written
  32m ago  SKILL_LINES_CHANGED -> written
  30m ago  SKILL_LINES_CHANGED -> written
  30m ago  SKILL_LINES_CHANGED -> written
  30m ago  SKILL_LINES_CHANGED -> written
  30m ago  SKILL_LINES_CHANGED -> written
  29m ago  SKILL_LINES_CHANGED -> written
  29m ago  SKILL_LINES_CHANGED -> written
  28m ago  SKILL_LINES_CHANGED -> written
  27m ago  SKILL_LINES_CHANGED -> written
  27m ago  SKILL_LINES_CHANGED -> written
  26m ago  SKILL_LINES_CHANGED -> written
  26m ago  SKILL_LINES_CHANGED -> written
  25m ago  SKILL_LINES_CHANGED -> written
  25m ago  PLAYER_LEVEL_UP+SKILL_LINES_CHANGED -> written
  24m ago  SKILL_LINES_CHANGED -> written
  24m ago  SKILL_LINES_CHANGED -> written
  23m ago  SKILL_LINES_CHANGED -> written
  22m ago  SKILL_LINES_CHANGED -> written
  21m ago  SKILL_LINES_CHANGED -> written
  21m ago  SKILL_LINES_CHANGED -> written
  20m ago  SKILL_LINES_CHANGED -> written
  20m ago  SKILL_LINES_CHANGED -> written
  20m ago  SKILL_LINES_CHANGED -> written
  19m ago  SKILL_LINES_CHANGED -> written
  19m ago  SKILL_LINES_CHANGED -> written
  18m ago  SKILL_LINES_CHANGED -> written
  18m ago  SKILL_LINES_CHANGED -> written
  17m ago  SKILL_LINES_CHANGED -> written
  15m ago  SKILL_LINES_CHANGED -> written
  14m ago  SKILL_LINES_CHANGED -> written
  14m ago  SKILL_LINES_CHANGED -> written
  12m ago  PLAYER_LEVEL_UP+SKILL_LINES_CHANGED -> written
  12m ago  SKILL_LINES_CHANGED -> written
  11m ago  SKILL_LINES_CHANGED -> written
  11m ago  SKILL_LINES_CHANGED -> written
  6m ago  SKILL_LINES_CHANGED -> written
  3m ago  SKILL_LINES_CHANGED -> written
  3m ago  SKILL_LINES_CHANGED -> written
snapshots saved by earlier sessions:
  session 1  48m ago  SKILL_LINES_CHANGED+PLAYER_LOGIN -> written
  session 1  47m ago  PLAYER_LOGOUT -> written; trees: unspent points not read
== CHARACTERS (2) ==
* Geo-Classic Beta PvP  L5 Druid  0m ago
    Professions 0, Adventure 0, Resourcefulness 0 | unspent 0, cap 16
    Herbalism 13/75 [182], Cooking 1/75 [185]
  Bong-Classic Beta PvP  L1 Shaman  47m ago
    Professions 0, Adventure 0, Resourcefulness 0 | unspent 0, cap 16  (kept from 48m ago: unspent points not read)
    no professions
== TRADESKILL CANDIDATES ==
Journeyman Alchemist  [line 2937, parent 171, profession 2937]  need 150
    no stored character has this profession
Expert Alchemist  [line 2937, parent 171, profession 2937]  need 225
    no stored character has this profession
Artisan Alchemist  [line 2937, parent 171, profession 2937]  need 300
    no stored character has this profession
Journeyman Blacksmith  [line 2938, parent 164, profession 2938]  need 150
    no stored character has this profession
Expert Blacksmith  [line 2938, parent 164, profession 2938]  need 225
    no stored character has this profession
Artisan Blacksmith  [line 2938, parent 164, profession 2938]  need 300
    no stored character has this profession
Journeyman Enchanter  [line 2940, parent 333, profession 2940]  need 150
    no stored character has this profession
Expert Enchanter  [line 2940, parent 333, profession 2940]  need 225
    no stored character has this profession
Artisan Enchanter  [line 2940, parent 333, profession 2940]  need 300
    no stored character has this profession
Journeyman Engineer  [line 2941, parent 202, profession 2941]  need 150
    no stored character has this profession
Expert Engineer  [line 2941, parent 202, profession 2941]  need 225
    no stored character has this profession
Artisan Engineer  [line 2941, parent 202, profession 2941]  need 300
    no stored character has this profession
Journeyman Leatherworker  [line 2945, parent 165, profession 2945]  need 150
    no stored character has this profession
Expert Leatherworker  [line 2945, parent 165, profession 2945]  need 225
    no stored character has this profession
Artisan Leatherworker  [line 2945, parent 165, profession 2945]  need 300
    no stored character has this profession
Journeyman Tailor  [line 2948, parent 197, profession 2948]  need 150
    no stored character has this profession
Expert Tailor  [line 2948, parent 197, profession 2948]  need 225
    no stored character has this profession
Artisan Tailor  [line 2948, parent 197, profession 2948]  need 300
    no stored character has this profession
== RAW ==
]==]
