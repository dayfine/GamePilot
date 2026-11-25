(* Make_room: the Center nearest the save, and the generated checkpoint. *)

open Frlg_checkpoints
module R = Checkpoints_run.Room_policy

let table = Result.get_ok (Frlg_actions.Fly_towns.load ())

(* The maps of the world, with every standard Center's coded room. *)
let maps =
  let world = Result.get_ok (Checkpoint_run.load_world ()) in
  List.init (Grid_maps.Connected_maps.size world.maps) (fun i ->
      (Grid_maps.Connected_maps.map world.maps i).name)

(* Each Center of the world: a coded room (it has the "pc_front" point no map
   file has) or its map file. *)
let world_centers () =
  let world = Result.get_ok (Checkpoint_run.load_world ()) in
  List.init (Grid_maps.Connected_maps.size world.maps) (fun i ->
      Grid_maps.Connected_maps.map world.maps i)
  |> List.filter (fun (m : Grid_maps.Map_data.t) ->
         String.ends_with ~suffix:"_PokemonCenter_1F" m.name)
  |> List.partition (fun (m : Grid_maps.Map_data.t) ->
         Grid_maps.Map_data.String_map.mem "pc_front" m.points)
  |> fun (coded, mapped) ->
  Printf.sprintf "%d coded; mapped: %s" (List.length coded)
    (String.concat ", "
       (List.map (fun (m : Grid_maps.Map_data.t) -> m.name) mapped))

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
    Checkpoints_plan.Plan_decode.decode ~source:"00-make-room"
      (Make_room.plan_json room)
  with
  | Error e -> "error: " ^ e
  | Ok p ->
      String.concat "; "
        (List.map
           (fun (e : Checkpoints_plan.Plan.event) ->
             e.id ^ " " ^ Option.value e.action ~default:"")
           p.checkpoint.events)
      ^ " | ends "
      ^ Option.fold ~none:"?"
          ~some:(fun (g : Checkpoints_plan.Pose.grid) -> g.map)
          p.postconditions.position
      ^ " | party "
      ^ (match p.postconditions.party with
        | Some (Party_in_order l) -> String.concat ", " l
        | _ -> "?")
      ^ " | knows "
      ^ String.concat ", "
          (List.map
             (fun (k : Checkpoints_plan.Plan.knows) ->
               k.species ^ " " ^ String.concat "+" k.moves)
             p.postconditions.knows)

let case name input expectation : Table_test.case = { name; input; expectation }

let () =
  Table_test.run "make room"
    [
      case "the world's Centers: every standard one's coded room wins"
        world_centers
        "17 coded; mapped: IndigoPlateau_PokemonCenter_1F, \
         OneIsland_PokemonCenter_1F";
      case "Pallet Town: Viridian (Pallet has no Center)" (nearest "PalletTown")
        "ViridianCity";
      case "inside Pallet: the town of the map"
        (nearest "PalletTown_PlayersHouse_1F")
        "ViridianCity";
      case "Lavender: its own Center" (nearest "LavenderTown") "LavenderTown";
      case "Celadon: its own Center, a coded room" (nearest "CeladonCity")
        "CeladonCity";
      case "Indigo Plateau: not its own Center, which has no PC at (11, 2)"
        (nearest "IndigoPlateau") "PewterCity";
      case "a route: no Fly town" (nearest "Route16")
        "error: Route16 is in no Fly town: give a town's map";
      case "console B: the generated checkpoint" plan
        "fly_to_center fly; to_pc run; deposit pc_deposit; out_of_center run | \
         ends ViridianCity | party blastoise, pidgey, oddish, lapras | knows \
         oddish cut, pidgey fly";
    ]
