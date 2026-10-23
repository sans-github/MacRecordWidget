# Rule: Mocks Are Built on the Current UI

Every HTML mock under `projects/**/mocks/` starts from the live UI, not from a fresh drawing.

- Load `projects/master/mocks/kit/kit.js` (relative path, e.g. `../../master/mocks/kit/kit.js` from a feature folder) and render the panel with `MRW.panel()` / `MRW.row()`.
- Draw only the part under review yourself. Build new controls with `MRW.control()` and glyphs with `MRW.symbol()`, which use real SF Symbols from `kit/symbols/`.
- No emoji, unicode stand-ins or hand-drawn SVG for anything that is an SF Symbol in the app. A symbol the kit lacks is added to `kit/export-symbols.swift` and re-exported.
- The kit is ground truth only while it matches `kit/reference/*.png` (screenshots of the running app). `kit/check.html` shows them side by side. When the row changes in Swift, update `kit.js` and `kit.css` in the same commit and refresh the screenshots.

Enforced by `.claude/hooks/mock-kit-check.sh`, which blocks writing a mock that does not load the kit or that contains emoji.
