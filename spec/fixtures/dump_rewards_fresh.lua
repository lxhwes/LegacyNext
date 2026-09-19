-- Captured client data. Do not edit the table below by hand.
--
-- source:    /lgn dump rewards (LegacyNext 0.0.1), queue row D6
-- date:      2026-09-19
-- build:     1.60.1 (69913), tocVersion 16001
-- pin:       70ef1b2 (1.60.1.69913)
-- character: fresh level 1 Shaman "Bong Wrip", realm "Classic Beta PvP", 0 Legacy points
--
-- First successful reward-track read. On the pre-fix build this section returned
-- `rewardTrack = { unavailable = "GetMajorFactionData unavailable" }` because the copy guard
-- rejected the whole struct over factionFontColor's ColorMixin methods.
--
-- Two things here that the ranking and UI code must respect:
--
--   * isCollected is TRUE on the level 40 Tabard, which is NOT reached (reached = false,
--     locked = true, and the account has 0 points). It is account collection state, not
--     progress. Never render it as "claimed".
--   * `rawName` is present on the 25/40/55 entries and absent on 15. `name` happens to be
--     present on all four here, but the documented field list is a floor -- keep reading
--     `reward.name or reward.toastDescription`.
--
-- Pipes arrive escaped as \124 because Debug's serializer escapes them; that is the addon's
-- encoding of a real `|` in the client string, not client data.

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
		section = "rewards",
		tocVersion = 16001,
		version = "1.60.1",
		wowProjectId = 1,
	},
	rewardTrack = {
		earned = 0,
		factionId = 2802,
		isHidden = false,
		isUnlocked = true,
		level = 0,
		maxLevel = 90,
		name = "Legacy Track",
		nextRewards = {
			{
				description = "Join a shootout with your air rifle. You and other players with this rifle can Stun each other. Even keeps score!\124n\124n\124cFFFFFFFFVisit Innkeeper Wiley in Ratchet to claim your reward.\124R",
				icon = 135614,
				isAccountUnlock = false,
				isCollected = false,
				itemID = 276236,
				name = "Replica Ironforge Air Rifle",
				rewardType = 1,
				toastDescription = "Replica Ironforge Air Rifle",
				uiOrder = 0,
			},
		},
		nextThreshold = 15,
		pointsToNext = 15,
		thresholds = {
			{
				isCapstone = false,
				isMilestone = false,
				level = 15,
				locked = true,
				reached = false,
				rewards = {
					{
						description = "Join a shootout with your air rifle. You and other players with this rifle can Stun each other. Even keeps score!\124n\124n\124cFFFFFFFFVisit Innkeeper Wiley in Ratchet to claim your reward.\124R",
						icon = 135614,
						isAccountUnlock = false,
						isCollected = false,
						itemID = 276236,
						name = "Replica Ironforge Air Rifle",
						rewardType = 1,
						toastDescription = "Replica Ironforge Air Rifle",
						uiOrder = 0,
					},
				},
			},
			{
				isCapstone = false,
				isMilestone = false,
				level = 25,
				locked = true,
				reached = false,
				rewards = {
					{
						description = "Summons a tiny spectral bear cub as your companion.\124n\124n\124cFFFFFFFFVisit Innkeeper Wiley in Ratchet to claim your reward.\124R",
						icon = 294471,
						isAccountUnlock = false,
						isCollected = false,
						itemID = 277714,
						name = "Spectral Bear Cub",
						rawName = "Spectral Bear Cub",
						rewardType = 1,
						toastDescription = "Spectral Bear Cub",
						uiOrder = 0,
					},
				},
			},
			{
				isCapstone = false,
				isMilestone = false,
				level = 40,
				locked = true,
				reached = false,
				rewards = {
					{
						description = "Show your dedication with this spectral bear themed tabard.\124n\124n\124cFFFFFFFFVisit Innkeeper Wiley in Ratchet to claim your reward.\124R",
						icon = 7941423,
						isAccountUnlock = false,
						isCollected = true,
						itemID = 277717,
						name = "Spectral Bear Tabard",
						rawName = "Spectral Bear Tabard",
						rewardType = 1,
						toastDescription = "Spectral Bear Tabard",
						uiOrder = 0,
					},
				},
			},
			{
				isCapstone = false,
				isMilestone = false,
				level = 55,
				locked = true,
				reached = false,
				rewards = {
					{
						description = "Summons and dismisses an Epic rideable spectral bear mount that moves at 100% increased speed.\124n\124n\124cFFFFFFFFVisit Innkeeper Wiley in Ratchet to claim your reward.\124R",
						icon = 3753812,
						isAccountUnlock = false,
						isCollected = false,
						itemID = 277718,
						name = "Reins of the Spectral Bear",
						rawName = "Reins of the Spectral Bear",
						rewardType = 1,
						toastDescription = "Reins of the Spectral Bear",
						uiOrder = 0,
					},
				},
			},
		},
		thresholdsReached = 0,
	},
}
