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
| mg-04a | CH'DING's Knock Off (skipped when known), Escape Rope, Fly to Indigo Plateau, heal |
| mg-04b | One grind round, repeated: Indigo nurse → Victory Road 2F, up to 7 battles, back to heal |
| mg-04c | MIMIEN at Lv 33 with Recycle: Fly back to Lavender for mg-05 |
| mg-05a | Leppa Berry, Retro Mail and the party arranged for Lea & Jed |
| mg-05 | Lea & Jed's double battle: Knock Off, Recycle |
| mg-06 | Read the glitched mail, duplicate one Antidote |

mg-04b repeats (its plan's `metadata.repeat`): each round starts and ends at the Indigo Plateau
nurse and is saved there like any checkpoint, so a failure reloads the last round's save and only
that round runs again. The rounds end once MIMIEN is at least Lv 33 and knows Recycle (read after
each round, at most 20 rounds); a stopped run resumes with `--from mg-04b`. `--max-rounds N` caps
the rounds for a test, with `--grind-battles N` capping each round's battles.

What the save needs before a checkpoint (free party slots, field moves, money, items) comes from
the plans: `gamepilot programs` prints the program's needs, and
`gamepilot checkpoints --program frlg.mail_glitch --preflight --from ID` checks a save against them.
The port's history and the grinding options are in `docs/roadmap.md` (Phase 4).

The player's guides: `docs/guide/frlg.mail_glitch.md` (activation) and
`docs/guide/frlg.mail_glitch.item_duplication.md` (mg-06).
