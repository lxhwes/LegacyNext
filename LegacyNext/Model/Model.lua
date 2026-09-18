local _, ns = ...

-- Pure Lua: challenge ranking, reward-track math, roster mapping. No WoW globals at all,
-- which is what makes this layer testable under busted.
ns.Model = ns.Model or {}
