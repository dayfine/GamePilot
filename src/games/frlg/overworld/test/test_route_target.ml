(* Route planning on FireRed's maps: the step rules of the fork's
   PokemonFRLG_OverworldRoute_Tests (doors, exit mats, ledges, map edges)
   on Pallet Town, the player's house and Route 1. *)

open Grid_maps
open Frlg_overworld_fixtures
open Frlg_world
module Route_target = Frlg_overworld.Route_target

let target ?facing map tiles : Story.Pose.grid =
  { map; tiles = List.map (fun (x, y) -> { Tile_pos.x; y }) tiles; facing }

let plan ~from goal () =
  legs_text pallet (Route_target.plan pallet ~from ~facing:None goal)

let case name input expectation = { Case_table.name; input; expectation }
let celadon_names = [ "CeladonCity"; "Route16" ]

(* mg-02's "west 11" from Celadon City (4, 24) onto Route 16 (41, 14): how
   long it is held, and its stalled steps. *)
let west_onto_route16 w () =
  let from = place w "CeladonCity" 4 24 in
  match
    Route_target.plan w ~from ~facing:None (target "Route16" [ (41, 14) ])
  with
  | Error e -> "error: " ^ e
  | Ok legs -> (
      let leg = List.hd (List.rev legs) in
      match
        Frlg_overworld.Route_legs.move_of w Running ~facing:(Some West) leg
      with
      | Ok (Hold { spec; _ }) ->
          Printf.sprintf "%s: held %d ms, stalled steps [%s]" (leg_text w leg)
            (Grid_walker.Leg_timing.hold_ms spec spec.tiles)
            (String.concat "; " (List.map string_of_int spec.stalled_steps))
      | Ok (Turn _) -> "a turn"
      | Error e -> "error: " ^ e)

let () =
  Case_table.run "route_target"
    [
      case "out of the house: the exit mat warps, the door walks the player out"
        (plan
           ~from:(place pallet "PalletTown_PlayersHouse_1F" 4 6)
           (target "PalletTown" [ (6, 8) ]))
        "south 3 (warp) -> PalletTown (6, 8) south";
      case "into the house: north into the door, onto the exit mat facing north"
        (plan
           ~from:(place pallet "PalletTown" 6 10)
           (target "PalletTown_PlayersHouse_1F" []))
        "north 3 (warp) -> PalletTown_PlayersHouse_1F (4, 8) north";
      case "north over the edge onto Route 1"
        (plan
           ~from:(place pallet "PalletTown" 12 3)
           (target "Route1" [ (12, 35) ]))
        "north 8 -> Route1 (12, 35) north";
      case "down Route 1: holds over ledges hop them"
        (plan
           ~from:(place pallet "Route1" 12 5)
           (target "PalletTown" [ (12, 2) ]))
        "north 2 -> Route1 (12, 3) north; west 5 -> Route1 (7, 3) west; south \
         17 (to wall) -> Route1 (7, 24) south; east 5 -> Route1 (12, 24) east; \
         south 17 -> PalletTown (12, 2) south";
      case "a facing to end on"
        (plan
           ~from:(place pallet "PalletTown" 6 10)
           (target ~facing:Direction.West "PalletTown" [ (6, 12) ]))
        "east 6 (to wall) -> PalletTown (12, 10) east; south 2 -> PalletTown \
         (12, 12) south; west 6 -> PalletTown (6, 12) west";
      case "console: the step onto Route 16 stalls a tile"
        (west_onto_route16 (world celadon_names))
        "west 11 -> Route16 (41, 14) west: held 1529 ms, stalled steps [5]";
      case
        "mGBA: no stall at the edge (mg-02 run 1 ended on (40, 12), a tile \
         past)"
        (west_onto_route16 (world ~edge_stalls:false celadon_names))
        "west 11 -> Route16 (41, 14) west: held 1396 ms, stalled steps []";
      case "a map not loaded"
        (plan ~from:(place pallet "PalletTown" 6 10) (target "CeladonCity" []))
        "error: map CeladonCity is not loaded";
      case "a tile no walk reaches"
        (plan
           ~from:(place pallet "PalletTown" 6 10)
           (target "PalletTown" [ (0, 0) ]))
        "error: no walk reaches PalletTown (0, 0)";
    ]
