local _, ns = ...

-- The only layer permitted to call WoW globals. Every read feature-detects the function,
-- wraps the call in pcall, guards the result with issecretvalue when that exists, and
-- returns plain Lua tables or nil plus a reason. No UI code lives here.
ns.Api = ns.Api or {}
