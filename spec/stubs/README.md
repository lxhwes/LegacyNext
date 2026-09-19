# Stubs

Reserved for a fixture-driven stub environment that `Api/` specs would run against. None
exists yet; this README is the only file here.

Today `spec/api/api_spec.lua` injects trivial stubs inline into `_G` to exercise the guard
layer, and asserts no captured response shape. `Model/` specs load `spec/fixtures/` directly
and touch no WoW globals.

If a stub layer is added, every return value must come from a capture in `spec/fixtures/`,
never from invented data.
