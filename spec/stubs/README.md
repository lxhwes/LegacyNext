# Stubs

The fake WoW global environment that `Api/` specs run against. Stubs return values loaded
from `spec/fixtures/`; they do not invent data.

`Model/` specs need nothing from here — that layer touches no WoW globals, which is the
point of the split.
