local _, ns = ...

-- Frames. Reads from Model, never from Api directly. v0 is a standalone frame; we do not
-- hook Blizzard frames.
ns.UI = ns.UI or {}
