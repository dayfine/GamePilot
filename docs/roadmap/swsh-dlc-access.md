# B. Sword/Shield: the least story that unlocks the DLC

Goal: from a new Sword or Shield save, play only as much story as the Expansion Pass needs, and stop
at Wedgehurst Station with the DLC destinations offered, saved. The use is Crown Tundra (the Max Lair
programs need a save that can get there).

## Source plans

- **Crown Tundra access**, fork PR #475 (`autostory/swsh/MAX_LAIR_ACCESS_PLAN.md`). Its completion
  condition, from Nintendo's support page and Bulbapedia's Wedgehurst Station page: reach the Wild
  Area Station, get the Pokemon Box Link from Sonia at the Meetup Spot, return to Wedgehurst Station,
  trigger the Klara (Sword) or Avery (Shield) scene and **catch** the Galarian Slowpoke, then talk
  to the attendant and **see "Crown Tundra Station" in the destination menu**. That last observation
  is the acceptance test; cancel, save, stop. Travelling into Crown Tundra (the Peony battle, which
  may be lost, and the walk to the Max Lair) is a follow-up slice.
- **Story work plan**, fork PR #516 (`docs/design/AutoStory-SwSh-Work-Plan.md`): Gate A is a new game
  to outside Wedgehurst Station before Leon (closed-loop movement in a free-moving game, no battles);
  Gate B continues through the starter, Slumbering Weald, Route 2 and the train to the Wild Area.
  It lists the upstream SwSh detectors to reuse (dialog boxes, menus, black screens, battle menu,
  `basic_catcher`) and treats upstream draft PR #1207's timed segments as route evidence, not code.
- **R0 evidence**, fork PR #571: frame captures and route evidence for the first segments.

## Mapping onto GamePilot

There is no SwSh code in GamePilot yet. This needs `src/games/swsh` (readers, actions, story plans),
the Switch backend only (no emulator), and story checkpoints on the engine. SwSh is 3D: the movement
model is PLZA's (timed legs, turns, arrival checks), not the FRLG grid.

**Decided (user, 2026-11-25).**

- **After PLZA 02-platform-to-plaza** (the fork's 01.01; `plza-autostory-port.md`). PLZA brings what SwSh lacks on GamePilot: the stick
  on the wire, the native viewport, walks without tiles on the agnostic engine, and the reload from
  HOME. SwSh starts when 02-platform-to-plaza passes on console B.
- **Shield**, on console B, a brand-new save. The Slowpoke scene is Avery's; Shield fixtures first.
- **Start after the name.** The user types the player name by hand once; checkpoint 00.00 starts at the
  Rose introduction. No keyboard port (fork #62).
- **Driven by programs, not a hand capture round.** The fork's R0 ledger (#571) is not filled in by
  hand. Each checkpoint starts as a guessed plan from #1207's inputs and the walkthrough, runs on
  console B, and is revised from where it fails: saved frames become reader fixtures, the failure a
  replay test. Every input goes through the wire, so the measured walks are the ones the program
  sends. A guessed plan bounds every walk and scene, and stops on an unknown screen.
- Tests as for every game with no emulator (AGENTS.md): reader and game tests, scripted runs, wire-log
  replay, then three console passes in a row.

## Steps

1. PLZA 02-platform-to-plaza passes on console B (its own page).
2. Gate A, 00.00-00.03: Rose introduction, bag, Hop's house, the walk to the station before Leon.
   Readers as the guessed plans need them: dialog, choice arrow, menu, fades, the control cue.
3. Gate B: starter, the Weald, Route 2, the Dynamax Band, the train to the Wild Area; the battle port.
4. Wild Area feasibility (camera, clock lighting), Box Link, Slowpoke catch, attendant menu check;
   save and stop.

## Open questions

- Is a save handed over later (past Gate A) worth adding as a second start, once Gate A passes?
- How the station menu is read: a template of "Crown Tundra Station" in one language, or text reading.
