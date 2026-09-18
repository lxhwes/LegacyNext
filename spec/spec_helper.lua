-- Addon files are chunks the client calls with (addonName, namespace) as varargs, so they
-- cannot be require()d. Load them the way the client does.
local helper = {}

function helper.loadAddonFile(path, ns)
	ns = ns or {}
	local chunk = assert(loadfile(path))
	chunk("LegacyNext", ns)
	return ns
end

return helper
