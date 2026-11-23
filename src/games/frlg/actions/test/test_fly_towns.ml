(* The fly map's towns, as the fork's PokemonFRLG_AutoStoryFieldMoves_Tests
   test_fly_map checks them: every cell on the map, no two towns on one cell
   or of one name; and the cursor's presses to a town. *)

open Frlg_actions

let table = Result.get_ok (Fly_towns.load ())

let cells_on_map () =
  List.filter
    (fun (t : Fly_towns.town) ->
      t.cell.x < 0 || t.cell.x >= table.columns || t.cell.y < 0
      || t.cell.y >= table.rows)
    table.towns
  |> List.map (fun (t : Fly_towns.town) -> t.name)
  |> String.concat ", "

let distinct key =
  let keys = List.map key table.towns in
  string_of_bool (List.length (List.sort_uniq compare keys) = List.length keys)

let presses town =
  Fly_towns.cursor_presses (Option.get (Fly_towns.find table town))
  |> List.map (function
       | Wire.Press { buttons; hold_ms; _ } ->
           String.concat "+" (List.map Wire.string_of_button buttons)
           ^ " " ^ string_of_int hold_ms
       | Wire.Wait { wait_ms } -> "wait " ^ string_of_int wait_ms)
  |> String.concat ", "

let bad json =
  match Fly_towns.parse (Yojson.Safe.from_string json) with
  | Ok _ -> "parsed"
  | Error e -> e

let case name input expectation = { Case_table.name; input; expectation }

let () =
  Case_table.run "fly_towns"
    [
      case "every town's cell is on the fly map" cells_on_map "";
      case "no two towns share a cell"
        (fun () -> distinct (fun (t : Fly_towns.town) -> (t.cell.x, t.cell.y)))
        "true";
      case "no two towns share a name"
        (fun () -> distinct (fun (t : Fly_towns.town) -> t.name))
        "true";
      case "to Viridian City: the corner, 4 right, 8 down"
        (fun () -> presses "ViridianCity")
        "Up+Left 3000, Right 80, Right 80, Right 80, Right 80, Down 80, Down \
         80, Down 80, Down 80, Down 80, Down 80, Down 80, Down 80";
      case "Indigo Plateau lands outside"
        (fun () ->
          match Fly_towns.find table "IndigoPlateau" with
          | Some t -> Story.Pose.observed_to_string t.landing
          | None -> "none")
        "IndigoPlateau_Exterior (11, 7) south";
      case "a cell that is not [x, y]"
        (fun () ->
          bad
            {|{"columns": 22, "rows": 15, "towns": [{"name": "A", "cell": [1], "landing": {"map": "A", "tile": [0, 0]}}]}|})
        "kanto_fly_towns.json: towns[0].cell is not [x, y].";
    ]
