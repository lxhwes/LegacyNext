-- Captured client data. Do not edit the table below by hand.
--
-- source:    /lgn dump trees (LegacyNext 0.0.1)
-- date:      2026-09-19
-- build:     1.60.1 (69913), buildDate Sep 17 2026, tocVersion 16001
-- pin:       70ef1b2 (1.60.1.69913)
-- character: fresh level 1 Shaman, no professions, zero Legacy points earned or spent
--
-- NOTE: configId 2938022 is THIS CHARACTER'S, not the client's. A second fresh character read
-- 4040613 on the same build [2026-09-19]. Assert the three trees share one configId; never
-- assert the number.
--
-- Captured on the build where Api's copy guard rejected any table holding a function, so
-- GetMajorFactionData failed and the reward track was unavailable. That bug affected only
-- what reached the dump, never what the client said, and no reward-track read feeds this
-- section -- treeSpend below is complete and unaffected.
--
-- The `failures` tally from the capture is omitted here: it records our guard's behaviour at
-- capture time, not client data, and preserving it would date the fixture to a bug we fixed.
-- It is quoted in docs/status.md instead.

return {
	meta = {
		addon = "LegacyNext",
		addonVersion = "0.0.1",
		build = "69913",
		buildDate = "Sep 17 2026",
		buildString = "1.60.1 (69913)",
		flags = {
			eventDrivenRefresh = false,
			followMetaChains = false,
		},
		section = "trees",
		tocVersion = 16001,
		version = "1.60.1",
		wowProjectId = 1,
	},
	treeSpend = {
		[1187] = {
			configId = 2938022,
			constant = "LEGACY_TREE_PROFESSIONS_ID",
			hasStagedChanges = false,
			maxQuantity = 0,
			name = "Professions",
			quantity = 0,
			spent = 0,
			spentInTree = 0,
			traitCurrencyId = 4225,
			treeId = 1187,
		},
		[1188] = {
			configId = 2938022,
			constant = "LEGACY_TREE_ADVENTURE_ID",
			hasStagedChanges = false,
			maxQuantity = 0,
			name = "Adventure",
			quantity = 0,
			spent = 0,
			spentInTree = 0,
			traitCurrencyId = 4225,
			treeId = 1188,
		},
		[1189] = {
			configId = 2938022,
			constant = "LEGACY_TREE_PROGRESSION_ID",
			hasStagedChanges = false,
			maxQuantity = 0,
			name = "Resourcefulness",
			quantity = 0,
			spent = 0,
			spentInTree = 0,
			traitCurrencyId = 4225,
			treeId = 1189,
		},
		cap = 16,
		capSource = "C_Traits.GetMaxAvailableTraitCurrency",
		currencyId = 4225,
		earnable = 65,
		spent = 0,
		treeIds = {
			1187,
			1188,
			1189,
		},
		unspent = 0,
	},
}
