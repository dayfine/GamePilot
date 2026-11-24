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
the Switch backend only (no emulator), and story checkpoints on the engine as FRLG uses it. SwSh is
3D with a camera behind the player in towns: the movement model is PLZA's (timed legs, turns,
arrival checks), not the FRLG grid, so it comes after or with G.

## Steps

1. Readers from the frames of #571: dialog, choice arrow, menu, black and white fades, battle menu.
2. Gate A on console A or B: intro, options, bag, Hop's house, the walk to the station.
3. Gate B: starter, the Weald, Route 2, the Dynamax Band, the train to the Wild Area.
4. Box Link, Slowpoke catch, attendant menu check; save and stop.

## Open questions

- Which version and language first? The DLC Slowpoke scene differs by version.
- Is a fresh save needed, or can the user hand over a save already past part of this?
- New game needs the system keyboard for the name; the fork has a typer (fork #62) to port.
