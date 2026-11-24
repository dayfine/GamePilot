# F. SV Treasures of Ruin

Goal: collect SV's legendaries, starting with the four Treasures of Ruin (Wo-Chien, Chien-Pao,
Ting-Lu, Chi-Yu): pull the stakes that open each shrine, then catch the legendary inside.

**Assumption.** The request said "desert legendary collection". No fork source has an SV legendary
plan; GamePilot's stack design only names "legendary collection" in slice S3. We read it as the
Treasures of Ruin, whose shrines open after the stakes across Paldea are pulled. If one specific
shrine or another legendary was meant, narrow this page.

## What exists

- No prior plan. The isolated-encounter research (E) excluded shrine fly points on purpose.
- Upstream PA/CC SV programs give reusable pieces: AutoStory for the main story, fly-to, battle and
  catch handling, the box tools. Which of them reach the post-game is to be checked.

## Steps

1. **Facts first**: the stake count and colours per shrine, the stake and shrine locations, what
   unlocks them (story point), the legendaries' levels. From Serebii or Bulbapedia, written down as
   data with a source per row, nothing from memory.
2. **Stake route**: fly point plus a short approach per stake, as data; an interact action with a
   prompt reader and a check that the stake was pulled.
3. **Shrine and catch**: walk in, battle, catch with the shared catch loop (save before the battle;
   reload on a knockout).
4. **Program** `sv.ruinous_legendaries`: one checkpoint per shrine (all its stakes, then the catch).

## Prerequisites

An SV save past the point that enables the stakes; SV readers and fly-to shared with E; Switch
backend with free-camera movement (slice S3).

## Open questions

- Which legendary was meant, and are the other SV legendaries (Paradox, DLC) in scope later?
- Are the Treasures of Ruin shiny-locked? Check before planning any shiny path.
