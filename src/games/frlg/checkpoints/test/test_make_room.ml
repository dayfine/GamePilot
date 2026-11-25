(* Make_room: the Center nearest the save, and the generated checkpoint. *)

open Frlg_checkpoints
module R = Room_policy

let table = Result.get_ok (Frlg_actions.Fly_towns.load ())

(* The Centers in PokemonSimulation's maps on 2026-11-23. *)
let maps =
  List.map Make_room.center_map
    [
      "CeruleanCity";
      "IndigoPlateau";
      "LavenderTown";
      "PewterCity";
      "Route10";
      "Route4";
      "VermilionCity";
      "ViridianCity";
    ]

let nearest map () =
  match Make_room.nearest_center table ~maps map with
  | Ok town -> town.name
  | Error e -> "error: " ^ e

let member slot species level moves : R.member =
  { slot; species; level = Some level; moves = Some moves }

(* Console B's save, the moves as a plain run would have them. *)
let console_b =
  [
    member 1 "blastoise" 59 [ "surf"; "strength" ];
    member 2 "eevee" 25 [ "tackle" ];
    member 3 "pidgey" 24 [ "fly"; "gust" ];
    member 4 "oddish" 12 [ "cut"; "absorb" ];
    member 5 "lapras" 25 [ "surf"; "sing" ];
    member 6 "magikarp" 5 [ "splash" ];
  ]

let plan () =
  let center = Option.get (Frlg_actions.Fly_towns.find table "ViridianCity") in
  let room : Make_room.room =
    {
      center;
      fly_user = "pidgey";
      deposits =
        [ { slot = 2; species = "eevee" }; { slot = 6; species = "magikarp" } ];
      party = console_b;
      needed_moves = [ "cut"; "fly" ];
    }
  in
  match
    Pokemon_checkpoints.Plan_decode.decode ~source:"00-make-room"
      (Make_room.plan_json room)
  with
  | Error e -> "error: " ^ e
  | Ok p ->
      String.concat "; "
        (List.map
           (fun (e : Pokemon_checkpoints.Plan.event) ->
             e.id ^ " " ^ Option.value e.action ~default:"")
           p.checkpoint.events)
      ^ " | ends "
      ^ Option.fold ~none:"?"
          ~some:(fun (g : Pokemon_checkpoints.Pose.grid) -> g.map)
          p.postconditions.position
      ^ " | party "
      ^ (match p.postconditions.party with
        | Some (Party_in_order l) -> String.concat ", " l
        | _ -> "?")
      ^ " | knows "
      ^ String.concat ", "
          (List.map
             (fun (k : Pokemon_checkpoints.Postconditions.knows) ->
               k.species ^ " " ^ String.concat "+" k.moves)
             p.postconditions.knows)

let case name input expectation : Table_test.case = { name; input; expectation }

let () =
  Table_test.run "make room"
    [
      case "Pallet Town: Viridian (Pallet has no Center)" (nearest "PalletTown")
        "ViridianCity";
      case "inside Pallet: the town of the map"
        (nearest "PalletTown_PlayersHouse_1F")
        "ViridianCity";
      case "Lavender: its own Center" (nearest "LavenderTown") "LavenderTown";
      case "Celadon (no Center in the maps): Route 4's, nearest by cell"
        (nearest "CeladonCity") "Route4";
      case "a route: no Fly town" (nearest "Route16")
        "error: Route16 is in no Fly town: give a town's map";
      case "console B: the generated checkpoint" plan
        "fly_to_center fly; to_pc run; deposit pc_deposit; out_of_center run | \
         ends ViridianCity | party blastoise, pidgey, oddish, lapras | knows \
         oddish cut, pidgey fly";
    ]
