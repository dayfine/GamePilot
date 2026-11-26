(* The seed lookup against the C++'s golden vectors
   (fixtures/seeds_database.txt): the first 300 rows of FR_Eng.json, as the C++
   read them, and SeedsDatabase::find_seed's answers on them. *)

open Frlg_rng

let records = Fixture_lines.read "fixtures/seeds_database.txt"

let lines op =
  List.filter_map
    (fun (r : Fixture_lines.record) ->
      if r.op = op then Some (String.concat " " r.inputs, r.expected) else None)
    records

let database =
  let delays =
    List.assoc "" (lines "delays")
    |> String.split_on_char ' ' |> List.map int_of_string |> Array.of_list
  in
  let seeds = lines "seeds" in
  let columns =
    List.map
      (fun (index, name) ->
        (name, String.split_on_char ' ' (List.assoc index seeds)))
      (lines "column")
  in
  match Seeds_database.of_columns ~delays columns with
  | Ok t -> t
  | Error why -> failwith why

let enum_index values v =
  let rec go i = function
    | [] -> failwith "not in the enum"
    | x :: rest -> if x = v then i else go (i + 1) rest
  in
  string_of_int (go 0 values)

let match_text (m : Seeds_database.seed_match) =
  Printf.sprintf "%d %d %s %s %s %s | %s | %s" m.seed_position m.seed_delay
    (enum_index [ Seeds_database.A; Start; L ] m.seed_button)
    (enum_index [ Seeds_database.No_extra; Extra_l ] m.extra_button)
    (enum_index [ Seeds_database.Mono; Stereo ] m.sound)
    m.button_mode
    (String.concat " " (List.map (Printf.sprintf "%04x") m.seed_values))
    m.column_name

let find_seed = function
  | [ target; sound; radius ] -> (
      let sound = if sound = "0" then Seeds_database.Mono else Stereo in
      match
        Seeds_database.find_seed database ~target:(Fixture_lines.hex target)
          sound ~radius:(int_of_string radius)
      with
      | None -> "none"
      | Some m -> match_text m)
  | _ -> failwith "find_seed: target sound radius"

let column_names () =
  let bad = [ "Mono / Help"; "Loud / Help / A"; "Mono / Help / B" ] in
  if
    List.for_all
      (fun n -> Result.is_error (Seeds_database.parse_column_name n))
      bad
  then Ok ()
  else Error "a malformed column name parsed"

let () =
  Fixture_lines.check_op records "find_seed" find_seed;
  Table_test.report "parse_column_name rejects malformed names"
    (column_names ());
  Table_test.finish ()
