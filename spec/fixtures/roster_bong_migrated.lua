-- Captured client data. Do not edit the table below by hand.
--
-- source:    /lgn roster, its `== RAW ==` block, from Bong's first login on v0.1.0-beta2.
--            The rendered text of that paste, of Bong's paste after a /reload, of Geo's paste
--            and of Geo's /lgn uidump are kept verbatim at the bottom of this file.
-- date:      2026-10-02
-- build:     1.60.1 (70170), from the paste's own first line
-- pin:       9a789c0 (1.60.1.70170)
-- character: Bong, Classic Beta PvP, level 1 Shaman, no professions, account at 0 Legacy
--            points. Session 23. Geo (level 7 Druid, Alchemy 19, Herbalism 28, Cooking 5) moved
--            to its GUID in session 21; session 22 was Geo after a /reload. Plymouth has not
--            logged in on a GUID build, so its row keeps its Name-Realm key. Queue row S2.
-- via:       Alex, in chat, 2026-10-02, night.
--
-- `snapshots` and `diagnostics` are our own Store shapes, written by the addon in game.
-- `parentsLive[*].raw` is the client's ProfessionInfo struct. No `now` and no this-session
-- log: the RAW block does not carry them. Indentation is the paste's.

return {
    diagnostics = {
        attached = true,
        characters = 3,
        globalIsOurs = true,
        loadedCharacters = 3,
        loadedLog = {
            {
                at = 1790983306,
                session = 19,
                text = "SKILL_LINES_CHANGED+PLAYER_LOGIN -> written",
            },
            {
                at = 1790983450,
                session = 19,
                text = "PLAYER_LOGOUT -> written; trees: unspent points not read; professions: empty read, kept stored",
            },
            {
                at = 1790983461,
                session = 20,
                text = "SKILL_LINES_CHANGED+PLAYER_LOGIN -> written",
            },
            {
                at = 1790983940,
                session = 20,
                text = "SKILL_LINES_CHANGED -> written",
            },
            {
                at = 1790983968,
                session = 20,
                text = "SKILL_LINES_CHANGED -> written",
            },
            {
                at = 1790984158,
                session = 20,
                text = "PLAYER_LOGOUT -> written; trees: unspent points not read; professions: empty read, kept stored",
            },
            {
                at = 1790989861,
                session = 21,
                text = "SKILL_LINES_CHANGED+PLAYER_LOGIN -> written; migrated from Geo-Classic Beta PvP",
            },
            {
                at = 1790990421,
                session = 21,
                text = "PLAYER_LOGOUT -> written",
            },
            {
                at = 1790990428,
                session = 22,
                text = "SKILL_LINES_CHANGED+PLAYER_LOGIN -> written",
            },
            {
                at = 1790990528,
                session = 22,
                text = "PLAYER_LOGOUT -> written; trees: unspent points not read; professions: empty read, kept stored",
            },
        },
        loadedSchema = 1,
        loadedSessions = 22,
        loadedType = "table",
        sessions = 23,
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
            guid = "Player-4619-012F81BC",
            key = "Player-4619-012F81BC",
            level = 7,
            name = "Geo",
            professions = {
                {
                    max = 75,
                    name = "Alchemy",
                    skill = 19,
                    skillLineId = 171,
                },
                {
                    max = 75,
                    name = "Herbalism",
                    skill = 28,
                    skillLineId = 182,
                },
                {
                    max = 75,
                    name = "Cooking",
                    skill = 5,
                    skillLineId = 185,
                },
            },
            professionsAt = 1790990428,
            professionsReason = "empty read, kept stored",
            realm = "Classic Beta PvP",
            spent = 0,
            takenAt = 1790990528,
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
            treesAt = 1790990428,
            treesReason = "unspent points not read",
            unspent = 0,
        },
        {
            cap = 16,
            class = "Shaman",
            classToken = "SHAMAN",
            guid = "Player-4619-00BADC1B",
            key = "Player-4619-00BADC1B",
            level = 1,
            name = "Bong",
            professions = {},
            professionsAt = 1790990552,
            realm = "Classic Beta PvP",
            spent = 0,
            takenAt = 1790990552,
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
            treesAt = 1790990552,
            unspent = 0,
        },
        {
            cap = 16,
            class = "Paladin",
            classToken = "PALADIN",
            key = "Plymouth-Classic Beta PvP",
            level = 1,
            name = "Plymouth",
            professions = {},
            professionsAt = 1790901914,
            realm = "Classic Beta PvP",
            spent = 0,
            takenAt = 1790901914,
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
            treesAt = 1790901871,
            treesReason = "unspent points not read",
            unspent = 0,
        },
    },
}

--[==[ Verbatim, as pasted. The TRADESKILL CANDIDATES block was identical in all three roster
pastes; it is kept once, in the first.

=== 1. Bong, first login (session 23): the paste the table above came from ===

LegacyNext roster  1.60.1 (70170)
== STORE ==
attached=true loadedType=table loadedSessions=22 loadedCharacters=3 sessions=23 characters=3
this snapshot: roster command -> written
snapshots this session:
  0m ago  SKILL_LINES_CHANGED+PLAYER_LOGIN -> written; migrated from Bong-Classic Beta PvP
snapshots saved by earlier sessions:
  session 19  120m ago  SKILL_LINES_CHANGED+PLAYER_LOGIN -> written
  session 19  118m ago  PLAYER_LOGOUT -> written; trees: unspent points not read; professions: empty read, kept stored
  session 20  118m ago  SKILL_LINES_CHANGED+PLAYER_LOGIN -> written
  session 20  110m ago  SKILL_LINES_CHANGED -> written
  session 20  109m ago  SKILL_LINES_CHANGED -> written
  session 20  106m ago  PLAYER_LOGOUT -> written; trees: unspent points not read; professions: empty read, kept stored
  session 21  11m ago  SKILL_LINES_CHANGED+PLAYER_LOGIN -> written; migrated from Geo-Classic Beta PvP
  session 21  2m ago  PLAYER_LOGOUT -> written
  session 22  2m ago  SKILL_LINES_CHANGED+PLAYER_LOGIN -> written
  session 22  0m ago  PLAYER_LOGOUT -> written; trees: unspent points not read; professions: empty read, kept stored
== CHARACTERS (3) ==
* Bong-Classic Beta PvP  L1 Shaman  0m ago
    Professions 0, Adventure 0, Resourcefulness 0 | unspent 0, cap 16
    no professions
  Geo-Classic Beta PvP  L7 Druid  0m ago
    Professions 0, Adventure 0, Resourcefulness 0 | unspent 0, cap 16  (kept from 2m ago: unspent points not read)
    Alchemy 19/75 [171], Herbalism 28/75 [182], Cooking 5/75 [185]  (kept from 2m ago: empty read, kept stored)
  Plymouth-Classic Beta PvP  L1 Paladin  1477m ago
    Professions 0, Adventure 0, Resourcefulness 0 | unspent 0, cap 16  (kept from 1478m ago: unspent points not read)
    no professions
== TRADESKILL CANDIDATES ==
Journeyman Alchemist  [line 2937, parent 171, profession 2937]  need 150
    Geo-Classic Beta PvP  skill 19, 131 to go
Expert Alchemist  [line 2937, parent 171, profession 2937]  need 225
    Geo-Classic Beta PvP  skill 19, 206 to go
Artisan Alchemist  [line 2937, parent 171, profession 2937]  need 300
    Geo-Classic Beta PvP  skill 19, 281 to go
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

=== 2. Bong after /reload (session 24): STORE and CHARACTERS ===
RAW differed from the table above only in the log window (sessions 20 to 23), sessions = 24,
and Bong's professionsAt, takenAt and treesAt, all 1790990590.

LegacyNext roster  1.60.1 (70170)
== STORE ==
attached=true loadedType=table loadedSessions=23 loadedCharacters=3 sessions=24 characters=3
this snapshot: roster command -> written
snapshots saved by earlier sessions:
  session 20  118m ago  SKILL_LINES_CHANGED+PLAYER_LOGIN -> written
  session 20  110m ago  SKILL_LINES_CHANGED -> written
  session 20  110m ago  SKILL_LINES_CHANGED -> written
  session 20  107m ago  PLAYER_LOGOUT -> written; trees: unspent points not read; professions: empty read, kept stored
  session 21  12m ago  SKILL_LINES_CHANGED+PLAYER_LOGIN -> written; migrated from Geo-Classic Beta PvP
  session 21  2m ago  PLAYER_LOGOUT -> written
  session 22  2m ago  SKILL_LINES_CHANGED+PLAYER_LOGIN -> written
  session 22  1m ago  PLAYER_LOGOUT -> written; trees: unspent points not read; professions: empty read, kept stored
  session 23  0m ago  SKILL_LINES_CHANGED+PLAYER_LOGIN -> written; migrated from Bong-Classic Beta PvP
  session 23  0m ago  PLAYER_LOGOUT -> written
== CHARACTERS (3) ==
* Bong-Classic Beta PvP  L1 Shaman  0m ago
    Professions 0, Adventure 0, Resourcefulness 0 | unspent 0, cap 16
    no professions
  Geo-Classic Beta PvP  L7 Druid  1m ago
    Professions 0, Adventure 0, Resourcefulness 0 | unspent 0, cap 16  (kept from 2m ago: unspent points not read)
    Alchemy 19/75 [171], Herbalism 28/75 [182], Cooking 5/75 [185]  (kept from 2m ago: empty read, kept stored)
  Plymouth-Classic Beta PvP  L1 Paladin  1477m ago
    Professions 0, Adventure 0, Resourcefulness 0 | unspent 0, cap 16  (kept from 1478m ago: unspent points not read)
    no professions

=== 3. Geo, first login on v0.1.0-beta2 (session 21): STORE and CHARACTERS ===
RAW held three snapshots: Geo under Player-4619-012F81BC with professionsAt, takenAt and
treesAt 1790989895 and no reasons; Bong and Plymouth under their Name-Realm keys.

LegacyNext roster  1.60.1 (70170)
== STORE ==
attached=true loadedType=table loadedSessions=20 loadedCharacters=3 sessions=21 characters=3
this snapshot: roster command -> written
snapshots this session:
  0m ago  SKILL_LINES_CHANGED+PLAYER_LOGIN -> written; migrated from Geo-Classic Beta PvP
snapshots saved by earlier sessions:
  session 17  161m ago  SKILL_LINES_CHANGED+PLAYER_LOGIN -> written
  session 17  132m ago  PLAYER_LOGOUT -> written; trees: unspent points not read; professions: empty read, kept stored
  session 18  113m ago  SKILL_LINES_CHANGED+PLAYER_LOGIN -> written
  session 18  110m ago  PLAYER_LOGOUT -> written; trees: unspent points not read; professions: empty read, kept stored
  session 19  109m ago  SKILL_LINES_CHANGED+PLAYER_LOGIN -> written
  session 19  107m ago  PLAYER_LOGOUT -> written; trees: unspent points not read; professions: empty read, kept stored
  session 20  107m ago  SKILL_LINES_CHANGED+PLAYER_LOGIN -> written
  session 20  99m ago  SKILL_LINES_CHANGED -> written
  session 20  98m ago  SKILL_LINES_CHANGED -> written
  session 20  95m ago  PLAYER_LOGOUT -> written; trees: unspent points not read; professions: empty read, kept stored
== CHARACTERS (3) ==
* Geo-Classic Beta PvP  L7 Druid  0m ago
    Professions 0, Adventure 0, Resourcefulness 0 | unspent 0, cap 16
    Alchemy 19/75 [171], Herbalism 28/75 [182], Cooking 5/75 [185]
  Bong-Classic Beta PvP  L1 Shaman  2409m ago
    Professions 0, Adventure 0, Resourcefulness 0 | unspent 0, cap 16  (kept from 2410m ago: unspent points not read)
    no professions
  Plymouth-Classic Beta PvP  L1 Paladin  1466m ago
    Professions 0, Adventure 0, Resourcefulness 0 | unspent 0, cap 16  (kept from 1467m ago: unspent points not read)
    no professions

=== 4. Geo, /lgn uidump, the same session (U8, U10, U11) ===

LegacyNext uidump  1.60.1 (70170)  filter=all
== HEADER (ok) ==
Legacy Track  ·  0 pts  ·  15 to next
Next: Replica Ironforge Air Rifle
== FILTERS ==
[All 41] | Classes 3 | Tradeskills 18 | Dungeons 3 | Raids 3 | Player vs. Player 12 | Adventure 2
== ROWS (44) ==
     ----- in progress -----
  1  Journeyman Alchemist             19/150   1pt
  2  Expert Alchemist                 19/225   1pt
  3  Artisan Alchemist                19/300   1pt
     ----- not started -----
  4  Journeyman Blacksmith             0/150   1pt
  5  Expert Blacksmith                 0/225   1pt
  6  Artisan Blacksmith                0/300   1pt
  7  Master of Alterac Valley        0/42000   1pt
  8  Master of Arathi Basin          0/42000   1pt
  9  Master of Warsong Gulch         0/42000   1pt
 10  Master of Darkspear Islands     0/42000   1pt
 11  Journeyman Enchanter              0/150   1pt
 12  Expert Enchanter                  0/225   1pt
 13  Artisan Enchanter                 0/300   1pt
 14  Field of Honor: Week 4              0/1   1pt
 15  Field of Honor: Week 7              0/1   1pt
 16  Field of Honor: Week 10             0/1   1pt
 17  Journeyman Engineer               0/150   1pt
 18  Expert Engineer                   0/225   1pt
 19  Artisan Engineer                  0/300   1pt
 20  Journeyman Leatherworker          0/150   1pt
 21  Expert Leatherworker              0/225   1pt
 22  Artisan Leatherworker             0/300   1pt
 23  Novice Spelunker                    0/6   1pt
 24  Experienced Spelunker              0/10   1pt
 25  Master Spelunker                   0/17   1pt
 26  Journeyman Tailor                 0/150   1pt
 27  Expert Tailor                     0/225   1pt
 28  Artisan Tailor                    0/300   1pt
 29  Conqueror of the Wilds             0/13   1pt
 30  Conqueror of the Deeps              0/8   1pt
 31  Explorer                            0/1   1pt
     ----- no progress shown -----
 32  Novice Druid                              1pt
 33  Experienced Druid                         1pt
 34  Master Druid                              1pt
 35  Rank 3                                    1pt
 36  Rank 7                                    1pt
 37  Rank 10                                   1pt
 38  Rank 13                                   1pt
 39  Rank 14                                   1pt
 40  Conqueror of the Lair                     1pt
 41  Lord Valthalak Laid to Rest               1pt
== STATE ==
state=ok
total=111 ranked=41 measurable=31 measureless=10 completed=0 zeroPoint=46 otherClass=24 partialRead=0 pointsUnknown=0
note=24 other-class challenges hidden
longest name=27 chars "Master of Darkspear Islands"
names over 30 chars: 0
== CLIENT ==
read took 24 ms
frame { created = true, escapeCloses = true, frameTemplate = "BasicFrameTemplateWithInset", grip = "PanelResizeButtonTemplate", height = 684, resizable = true, resize = "SetResizeBounds", rows = 41, scrollTemplate = "UIPanelScrollFrameTemplate", shown = false, tab = "nextup", tabTemplate = "PanelTopTabButtonTemplate", width = 961, }
minimap { angle = 228, created = true, locked = false, masked = true, shown = true, }
options { registered = true, }
]==]
