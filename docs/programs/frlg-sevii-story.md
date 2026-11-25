# Sevii Story (FRLG)

Registry id `frlg.sevii_story`, group FRLG / Story (`src/program_registry`). It plays the Sevii
Islands story from a save past the Hall of Fame (roadmap `docs/roadmap/frlg-sevii-islands.md`). Its
first checkpoint declares the save's eight badges and the Hall of Fame as preconditions, read off the
Trainer Card. It runs on mGBA.

| Checkpoint | Content |
|---|---|
| 01-to-one-island | Fly to Cinnabar, YES to Bill in the Pokemon Center: out with him, the Seagallop, One Island, Celio's Tri-Pass |

The game decides the first trip. Bill offers it when you leave Cinnabar Gym with the seventh badge;
a player who said no finds him waiting in the Cinnabar Pokemon Center, even after the Hall of Fame
(pokefirered `CinnabarIsland_EventScript_DeclineSailToOneIsland`). The Vermilion harbor's sailor
sails only once that trip is done (`VermilionCity_EventScript_FerrySailor`), and the Tri-Pass comes
from Celio at its end. The walkthrough drafts (#41) started at Vermilion and assumed the Tri-Pass;
this checkpoint replaces their sb-01.

The YES runs one script to its end: one `answer` event, then a `scene` that ends below Bill in
One Island's Center. On FireRed an `answer` event starts its own talk: a `talk` event's settle
presses B, and B answers NO.

The Cinnabar Pokemon Center has no map in PokemonSimulation, and needs none: 17 of FireRed's 19
Centers share one layout, and `Frlg_overworld.Standard_center` codes that room as the fork's story
does (`PokemonFRLG_CodedRooms`), with each Center's people (`Frlg_overworld.Center_people`, from
pret) as obstacles. The world loader uses it for every standard Center, so the `cinnabar_center_bill`
place and the route reach it. Where PokemonSimulation also has a map of a standard Center, the
coded room wins and the map file is not read: `heal_at` and `make_room` walk the same room in every
standard Center. Only the Indigo Plateau's and One Island's Centers, with layouts of their own, come
from their map files.

The walk goes from the Center's door mat straight to Bill. A room entered by its door comes up dim
and holds still for about 600ms before it fades in; the walk waits for that fade-in to finish
(`Warp_fade_in`) before its first step, so no step is lost.

Celio's scene also turns off Bill's PC storage (`FLAG_SYS_PC_STORAGE_DISABLED`) until the player
reaches Three Island's port, which is the next checkpoint's way. After that come Celio's Ruby and
Sapphire errands and the legendary birds, from the walkthrough drafts.
