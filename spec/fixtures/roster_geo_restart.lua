-- Captured client data. Do not edit the table below by hand.
--
-- source:    /lgn roster, its `== RAW ==` block. The rendered text above that block is kept
--            verbatim at the bottom of this file.
-- date:      2026-10-01
-- build:     1.60.1 (70124), from the paste's own first line
-- pin:       966519c (1.60.1.70124)
-- character: Geo Prizm (first name Geo, surname Prizm), Classic Beta PvP, level 6 Druid with
--            Alchemy 1/75, Herbalism 20/75 and Cooking 1/75, no Legacy points. Session 3, the
--            first login after a full client restart. Session 2 was Geo too, the session of
--            roster_geo.lua, where Alchemy was trained. Queue row S1, step 4 and the Alchemy
--            half of step 3.
-- via:       Alex's gist "lgn roster", the second one, 2026-10-01. The same login's
--            `/lgn uidump roster` (gist "lg uidump roster") is kept verbatim at the bottom too.
--
-- `snapshots` and `diagnostics` are our own Store shapes, written by the addon in game.
-- `parentsLive[*].raw` is the client's ProfessionInfo struct. No `now` and no this-session
-- log: the RAW block does not carry them.

return {
	diagnostics = {
		attached = true,
		characters = 2,
		globalIsOurs = true,
		loadedCharacters = 2,
		loadedLog = {
			{
				at = 1790848673,
				session = 2,
				text = "SKILL_LINES_CHANGED -> written",
			},
			{
				at = 1790848695,
				session = 2,
				text = "SKILL_LINES_CHANGED -> written",
			},
			{
				at = 1790848738,
				session = 2,
				text = "SKILL_LINES_CHANGED -> written",
			},
			{
				at = 1790848781,
				session = 2,
				text = "SKILL_LINES_CHANGED -> written",
			},
			{
				at = 1790848854,
				session = 2,
				text = "SKILL_LINES_CHANGED -> written",
			},
			{
				at = 1790848906,
				session = 2,
				text = "SKILL_LINES_CHANGED -> written",
			},
			{
				at = 1790848914,
				session = 2,
				text = "SKILL_LINES_CHANGED -> written",
			},
			{
				at = 1790849058,
				session = 2,
				text = "SKILL_LINES_CHANGED -> written",
			},
			{
				at = 1790849070,
				session = 2,
				text = "SKILL_LINES_CHANGED -> written",
			},
			{
				at = 1790849212,
				session = 2,
				text = "PLAYER_LOGOUT -> written; trees: unspent points not read; professions: empty read, kept stored",
			},
		},
		loadedSchema = 1,
		loadedSessions = 2,
		loadedType = "table",
		sessions = 3,
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
				sourceCounter = 0,
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
				sourceCounter = 0,
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
				sourceCounter = 0,
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
				sourceCounter = 0,
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
				sourceCounter = 0,
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
				sourceCounter = 0,
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
				sourceCounter = 0,
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
				sourceCounter = 0,
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
				sourceCounter = 0,
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
				sourceCounter = 0,
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
				sourceCounter = 0,
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
				sourceCounter = 0,
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
			level = 6,
			name = "Geo",
			professions = {
				{
					max = 75,
					name = "Alchemy",
					skill = 1,
					skillLineId = 171,
				},
				{
					max = 75,
					name = "Herbalism",
					skill = 20,
					skillLineId = 182,
				},
				{
					max = 75,
					name = "Cooking",
					skill = 1,
					skillLineId = 185,
				},
			},
			professionsAt = 1790849658,
			realm = "Classic Beta PvP",
			spent = 0,
			takenAt = 1790849658,
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
			treesAt = 1790849658,
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
attached=true loadedType=table loadedSessions=2 loadedCharacters=2 sessions=3 characters=2
this snapshot: roster command -> written
snapshots this session:
  0m ago  SKILL_LINES_CHANGED+PLAYER_LOGIN -> written
snapshots saved by earlier sessions:
  session 2  16m ago  SKILL_LINES_CHANGED -> written
  session 2  16m ago  SKILL_LINES_CHANGED -> written
  session 2  15m ago  SKILL_LINES_CHANGED -> written
  session 2  14m ago  SKILL_LINES_CHANGED -> written
  session 2  13m ago  SKILL_LINES_CHANGED -> written
  session 2  12m ago  SKILL_LINES_CHANGED -> written
  session 2  12m ago  SKILL_LINES_CHANGED -> written
  session 2  10m ago  SKILL_LINES_CHANGED -> written
  session 2  9m ago  SKILL_LINES_CHANGED -> written
  session 2  7m ago  PLAYER_LOGOUT -> written; trees: unspent points not read; professions: empty read, kept stored
== CHARACTERS (2) ==
* Geo-Classic Beta PvP  L6 Druid  0m ago
    Professions 0, Adventure 0, Resourcefulness 0 | unspent 0, cap 16
    Alchemy 1/75 [171], Herbalism 20/75 [182], Cooking 1/75 [185]
  Bong-Classic Beta PvP  L1 Shaman  72m ago
    Professions 0, Adventure 0, Resourcefulness 0 | unspent 0, cap 16  (kept from 73m ago: unspent points not read)
    no professions
== TRADESKILL CANDIDATES ==
Journeyman Alchemist  [line 2937, parent 171, profession 2937]  need 150
    Geo-Classic Beta PvP  skill 1, 149 to go
Expert Alchemist  [line 2937, parent 171, profession 2937]  need 225
    Geo-Classic Beta PvP  skill 1, 224 to go
Artisan Alchemist  [line 2937, parent 171, profession 2937]  need 300
    Geo-Classic Beta PvP  skill 1, 299 to go
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

--[==[ /lgn uidump roster, same login, verbatim:
LegacyNext uidump  1.60.1 (70124)  tab=roster
== HEADER (ok) ==
Legacy Track  ·  0 pts  ·  15 to next
Next: Replica Ironforge Air Rifle
== FILTERS ==

== ROWS (7) ==
     Character                         P/A/R  Free
* 1  Geo  L6 Druid                     0/0/0     0
  2  Bong  L1 Shaman                   0/0/0     0
     Tradeskill challenge              Skill      
  3  Journeyman Alchemist  ·  Geo     1/150   1pt
  4  Expert Alchemist  ·  Geo         1/225   1pt
  5  Artisan Alchemist  ·  Geo        1/300   1pt
== STATE ==
state=ok
note=15 tradeskill challenges have no saved character with the profession
longest name=29 chars "Journeyman Alchemist  ·  Geo"
names over 30 chars: 0
== CLIENT ==
read took 37 ms
frame { created = false, }
]==]
