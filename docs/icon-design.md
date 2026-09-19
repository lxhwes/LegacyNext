# Addon icon

Drafted 2026-09-19. Owns the icon decision for Phase 3c: what the client accepts, the concepts,
the recommendation, and what is sitting in `docs/icon-drafts/` ready to ship.

## What the client does with `## IconTexture` [verified at the pin]

Read from `vendor/wow-ui-source` at `70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e` (the pin in
`vendor/PINS.md`). `Interface/AddOns/Blizzard_AddOnList` was not in the sparse checkout, so it was
added at the same SHA with `git -C vendor/wow-ui-source sparse-checkout add
Interface/AddOns/Blizzard_AddOnList`; `rev-parse HEAD` was unchanged before and after. That
directory is not yet listed in `vendor/PINS.md` (this task did not own that file).

- Both keys are read, texture first: `C_AddOns.GetAddOnMetadata(addonIndex, "IconTexture")` and
  `(addonIndex, "IconAtlas")` at `Blizzard_AddOnList/AddonList.lua:390-391`.
- With neither set, the list falls back to `Interface\ICONS\INV_Misc_QuestionMark`
  (`AddonList.lua:393-395`). That is what LegacyNext shows today.
- The icon is not a Texture widget. It is inline text markup prepended to the title:
  `CreateSimpleTextureMarkup(iconTexture, 20, 20) .. " " .. titleText` (`AddonList.lua:397-401`),
  which expands to `|T<path>:20:20:0:0|t` (`Blizzard_SharedXMLBase/TextureUtil.lua:279-287`).
  So the value is a texture path, the draw size is 20 x 20, and there is no way to draw it larger.
- `## IconAtlas` is accepted and loses to `IconTexture` when both are set (`AddonList.lua:397-401`).
  Atlases are Blizzard's own art, so it is not an option for us anyway.
- The path is relative to the WoW directory with no extension, the same form as every other
  texture path in the source. A file data ID would also satisfy `|T|t` markup, but we ship a file.
- The addon compartment (minimap dropdown) also reads `IconTexture` on retail. That code lives
  outside the sparse checkout and was not checked here; it does not change the file we ship.

## File format

- BLP and TGA are certain. TGA at 32 bpp uncompressed with alpha is the one every tool writes and
  the client has loaded since 2004. The draft below is exactly that.
- PNG: warcraft.wiki.gg (`API_TextureBase_SetTexture`) says PNG support arrived in 10.0.7 and that
  PNG paths must include the `.png` extension, unlike BLP and TGA. Forever is a 12.x-derived
  client so it very likely applies, but nothing in the vendored source or the generated API docs
  mentions a format at all (grep for `.png`, `.tga`, `.blp` in `Blizzard_APIDocumentationGenerated`
  returns nothing). Treat PNG as unverified on this client and ship TGA.
- Dimensions must be powers of two. 64 x 64 is plenty for a 20 px draw and keeps the file at 16 KB.

## CurseForge avatar [from web search, not fetched from the page]

CurseForge's Project Submission Guide asks for a square PNG of at least 400 x 400, original
artwork, not a blank colour or a game logo, and warns that WebP breaks the upload
(https://support.curseforge.com/support/solutions/articles/9000199552-project-submission-guide-and-tips).
`almost-full-512.png` covers that.

## IP

No Blizzard artwork, atlas, icon or logo goes into our file, and no `## IconAtlas` line. The
icon is original vector art authored in this repo, MIT like the rest. CurseForge moderation
rejects reused game graphics, so this is a listing requirement as well as a licence one.

## Concepts

Palette shared by all of them: navy `#1B2740` backplate, gold `#F2B33D`, pale gold `#FFD98A`
highlight, slate `#4A5878` for "not yet". Two colours plus a highlight on a dark plate, which is
what survives 20 px next to a line of gold title text.

**A. Almost full** (recommended). A thick gold ring that is 300 degrees complete, the last 60
degrees in slate, with a bold gold chevron in the centre pointing at the gap. It says "this one
is nearly done, go finish it", which is the whole product. At 20 px it is a gold ring with a
notch and a right-pointing mark; at 256 px the slate remainder and the pale end cap read as a
progress track. Rendered and checked at 24 px: ring and chevron both survive.

**B. Ranked stack** (runner-up, drafted). Three left-aligned rounded bars of decreasing length,
the top one gold with a pale triangle beside it, the rest slate. It says "a list, first item
lit". At 256 px it is clean and obviously a list. At 24 px the bars merge into a smear and the
triangle vanishes, which is why it lost.

**C. Three from one root.** One gold stem splitting into three branches for the three Legacy
trees, growing from a shared base for the account-wide pool. Communicates the domain rather
than the addon's job. Reads as a generic tree or fork at 20 px, and Blizzard's own Legacy UI
already leans on tree imagery, so it invites confusion with the game's frame.

**D. The last point.** A gold hexagonal coin (a Legacy Point) with one wedge cut out in slate.
Same message as A in a flatter shape. At 20 px a hexagon with a notch is hard to tell from a
damaged circle, and it lacks the "next" direction A's chevron gives.

**E. Next step.** Three ascending steps, the top step gold with a small pale mark on it. Says
"next up" through the podium metaphor. It brushes against the trophy cliche, and at 20 px the
step edges are thin diagonals that alias badly.

### Recommendation

Ship A. It is the only concept whose 24 px render still says something specific (nearly done,
and pointing at what is left), and the ring is one strong shape with no thin lines. B is the
better picture at 256 px but fails at the size the AddOn list draws it, and the AddOn list is
the only place the icon is guaranteed to be seen.

## What was produced

All in `docs/icon-drafts/`:

| File | What |
|---|---|
| `almost-full.svg` | Concept A source, 256 viewBox, hand-authored, no fonts |
| `almost-full-512.png`, `-256.png`, `-64.png`, `-24.png` | Renders of A. 512 is the CurseForge avatar |
| `icon.tga` | A at 64 x 64, 32 bpp uncompressed TGA, alpha, descriptor 0x08. The in-game candidate |
| `ranked-stack.svg` and `-256/-64/-24.png` | Concept B, for comparison |
| `render-svg.js` | The rasteriser (JavaScript for Automation over AppKit) |
| `png2tga.py` | Stdlib-only PNG to TGA converter, checks the PNG is 8-bit RGBA first |

No rasteriser was installed: `rsvg-convert`, `magick`, `convert`, `inkscape`, `cairosvg` and
`PIL` are all absent, pip has no network here, `qlmanage` hangs, and `swiftc` refuses its own
SDK. macOS can still render SVG through `NSImage`, so `render-svg.js` does that with no install:

```sh
cd docs/icon-drafts
osascript -l JavaScript render-svg.js "$PWD/almost-full.svg" "$PWD/almost-full-64.png" 64
python3 png2tga.py almost-full-64.png icon.tga
```

`icon.tga` was checked by reading its header back: type 2, 64 x 64, 32 bpp, 16402 bytes, alpha
values from 0 to 255, gold at the centre pixel.

## Shipping it

1. `mkdir LegacyNext/Media` and copy `docs/icon-drafts/icon.tga` to `LegacyNext/Media/icon.tga`.
2. In `LegacyNext/LegacyNext.toc` uncomment the line so it reads
   `## IconTexture: Interface\AddOns\LegacyNext\Media\icon` (no extension, backslashes).
3. The packager needs no change. `.pkgmeta` lifts `LegacyNext/` to the package root and ignores
   only `docs`, `spec`, `tools`, `vendor` and dotfiles, so `Media/icon.tga` ships as is.
4. In-game check: the AddOns list on the character select screen or the Escape menu. The icon
   should replace the question mark beside "LegacyNext" at 20 px. That is the one thing this
   change needs Alex in the client for.
5. Upload `almost-full-512.png` as the CurseForge project avatar when the project is created.
