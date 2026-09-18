local helper = require("spec.spec_helper")

describe("Model", function()
	it("loads with no WoW globals present", function()
		local ns = helper.loadAddonFile("LegacyNext/Model/Model.lua")

		assert.is_table(ns.Model)
	end)
end)
