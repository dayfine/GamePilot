# Roadmap plans after the Mail Glitch

`docs/roadmap.md` covers the Mail Glitch (S0/S1). These pages are the plans that come after it,
carried over from the C++ fork (`dayfine/Arduino-Source`, its `agents` notes branch and its draft
PRs) where a plan exists, and written fresh where none does. Each page has one GitHub issue; the
issue tracks the work, the page holds the plan. Slices S2-S4 are the ones in
`docs/design/Layered-Automation-Stack.md` section 9.

| Item | Page | Slice | Prior plan on the fork |
|---|---|---|---|
| A. FRLG after the Elite Four | [frlg-post-e4.md](frlg-post-e4.md) | S4 | yes, per milestone below |
| A1. Rare Candies: duplicate, then level | [frlg-rare-candy-leveling.md](frlg-rare-candy-leveling.md) | S4 | partly (duplication only) |
| A2. Sevii Islands story | [frlg-sevii-islands.md](frlg-sevii-islands.md) | S4 | yes (table rows) |
| A3. ACE: Master Balls and Luxury Balls | [frlg-ace-balls.md](frlg-ace-balls.md) | S4 | yes (outline) |
| A4. Legendaries | [frlg-legendaries.md](frlg-legendaries.md) | S4 | yes |
| A5. Wild and static RNG port | [frlg-rng-port.md](frlg-rng-port.md) | S4 | partly (decisions only) |
| A6. Dex collection, FireRed exclusives first | [frlg-dex-exclusives.md](frlg-dex-exclusives.md) | S4 | yes |
| B. SwSh: story to the DLC | [swsh-dlc-access.md](swsh-dlc-access.md) | new | yes |
| C. BDSP legendary RNG | [bdsp-legendary-rng.md](bdsp-legendary-rng.md) | S2 | yes |
| D. BDSP Underground mining | [bdsp-underground-mining.md](bdsp-underground-mining.md) | new | no |
| E. SV isolated shiny hunts | [sv-isolated-shiny.md](sv-isolated-shiny.md) | S3 | yes (research + prototype) |
| F. SV Treasures of Ruin | [sv-ruinous-legendaries.md](sv-ruinous-legendaries.md) | S3 | no |
| G. PLZA story port | [plza-autostory-port.md](plza-autostory-port.md) | new | yes (C++ code) |

Rules every item follows (from `docs/roadmap.md` and R21): ports are transparent (same behaviour and
timings as the C++, each module names its C++ source), mGBA first where the game runs there, the
Switch in the end, and every live failure becomes a replay test before the fix.
