# Mail Glitch (FRLG)

Registry id `frlg.mail_glitch`, group FRLG / Glitches (`src/program_registry`). It sets up the Mail
Glitch from a post-game FireRed save, performs it in Lea & Jed's double battle on Route 16, and uses
the glitched mail to duplicate an item. It runs on mGBA and on the Switch.

Its checkpoints are the plans in `src/games/frlg/programs/mail_glitch/plans/`, run in order by the
checkpoint runner (`gamepilot checkpoints --program frlg.mail_glitch --from 01-celadon-setup --to 08-activate-and-verify`):

| Checkpoint | Content |
|---|---|
| 01-celadon-setup | Celadon: Coin Case, Retro Mail, 200 coins, Abra |
| 02-trade-farfetchd | Spearow on Route 16, Sitrus Berry on Route 6, trade for CH'DING |
| 03-trade-mr-mime | Abra for MIMIEN on Route 2, Revives at Lavender |
| 04-grind-farfetchd | CH'DING's Knock Off (skipped when known), Escape Rope, Fly to Indigo Plateau, heal |
| 05-grind-mr-mime | One grind round, repeated: Indigo nurse → Victory Road 2F, up to 7 battles, back to heal |
| 06-grind-return | MIMIEN at Lv 33 with Recycle: Fly back to Lavender for 07-glitch-prep |
| 07-glitch-prep | Leppa Berry, Retro Mail and the party arranged for Lea & Jed |
| 08-activate-and-verify | Lea & Jed's double battle (Knock Off, Recycle), then read the glitched mail and duplicate one Antidote; the only save after the battle is at its end |

05-grind-mr-mime repeats (its plan's `metadata.repeat`): each round starts and ends at the Indigo Plateau
nurse and is saved there like any checkpoint, so a failure reloads the last round's save and only
that round runs again. The rounds end once MIMIEN is at least Lv 33 and knows Recycle (read after
each round, at most 20 rounds); a stopped run resumes with `--from 05-grind-mr-mime`. `--max-rounds N` caps
the rounds for a test, with `--grind-battles N` capping each round's battles.

What the save needs before a checkpoint (free party slots, field moves, money, items) comes from
the plans: `gamepilot programs` prints the program's needs, and
`gamepilot checkpoints --program frlg.mail_glitch --preflight --from ID` checks a save against them.
The port's history and the grinding options are in `docs/roadmap.md` (Phase 4).

The player's guides: `docs/guide/frlg.mail_glitch.md` (activation) and
`docs/guide/frlg.mail_glitch.item_duplication.md` (08-activate-and-verify).
