# Mail Glitch (FRLG)

Registry id `frlg.mail_glitch`, group FRLG / Glitches (`src/program_registry`). It sets up the Mail
Glitch from a post-game FireRed save, performs it in Lea & Jed's double battle on Route 16, and uses
the glitched mail to duplicate an item. It runs on mGBA and on the Switch.

Its checkpoints are the plans in `src/games/frlg/programs/mail_glitch/plans/`, run in order by the
checkpoint runner (`gamepilot checkpoints --program frlg.mail_glitch --from mg-01 --to mg-06`):

| Checkpoint | Content |
|---|---|
| mg-01 | Celadon: Coin Case, Retro Mail, 200 coins, Abra |
| mg-02 | Spearow on Route 16, Sitrus Berry on Route 6, trade for CH'DING |
| mg-03 | Abra for MIMIEN on Route 2, Revives at Lavender |
| mg-04 | Grind CH'DING to Knock Off and MIMIEN to Lv 33 for Recycle |
| mg-05a | Leppa Berry, Retro Mail and the party arranged for Lea & Jed |
| mg-05 | Lea & Jed's double battle: Knock Off, Recycle |
| mg-06 | Read the glitched mail, duplicate one Antidote |

What the save needs before a checkpoint (free party slots, field moves, money, items) comes from
the plans: `gamepilot programs` prints the program's needs, and
`gamepilot checkpoints --program frlg.mail_glitch --preflight --from ID` checks a save against them.
The port's history and the grinding options are in `docs/roadmap.md` (Phase 4).
