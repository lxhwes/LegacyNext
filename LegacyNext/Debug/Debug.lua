local _, ns = ...

-- /legacynext dump: serializes Api output into a copyable multiline EditBox, so real client
-- data can be pasted back as spec fixtures. SavedVariables cannot do this job yet.
ns.Debug = ns.Debug or {}
