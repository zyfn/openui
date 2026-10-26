# Native screenshot references

This source directory does not automatically approve screenshots. Actual native
captures always remain in the xcresult bundle. A versioned external `Baselines`
directory can be supplied through `--baselines-dir` for a repeatable pixel check.
Each set must record its SDK source revision, simulator/runtime, locale, content
size and image hashes. A technical regression reference is not human visual approval.

Record references only after functional and geometry checks pass and the native
images have been reviewed. Never overwrite a reference to make a failed run pass.
Use deterministic offline content for pixel comparison; live map tiles and web
pages need geometry/interaction assertions and raw screenshots instead.

The SDK review's bounded matrix supplies representative combinations. Reference
comparison protects their reviewed appearance; it does not prove every possible
model-generated composition is attractive or correct.
