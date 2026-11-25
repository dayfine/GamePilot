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

Open: the walk inside the Cinnabar Pokemon Center has no map yet.
`CinnabarIsland_PokemonCenter_1F` is not in PokemonSimulation's maps (its FRLG scope left Pokemon
Centers out). The plan names the tile west of Bill, (10, 5), until the map lands; then it becomes a place.

Celio's scene also turns off Bill's PC storage (`FLAG_SYS_PC_STORAGE_DISABLED`) until the player
reaches Three Island's port, which is the next checkpoint's way. After that come Celio's Ruby and
Sapphire errands and the legendary birds, from the walkthrough drafts.
