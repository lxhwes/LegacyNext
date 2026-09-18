local _, ns = ...

-- SavedVariables access behind an interface, so the workaround for the client bug where
-- SavedVariables are written but never loaded back stays a one-file change.
ns.Store = ns.Store or {}
