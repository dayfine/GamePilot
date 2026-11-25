type user = { slot : int; menu_row : int }

let fly = "fly"

let field_moves =
  [
    "flash";
    "cut";
    fly;
    "strength";
    "surf";
    "rock-smash";
    "waterfall";
    "teleport";
    "dig";
    "milk-drink";
    "soft-boiled";
    "sweet-scent";
  ]

(* SUMMARY is row 1; the field moves follow it. *)
let first_field_row = 2

let menu_row moves =
  let rows = List.filter (fun m -> List.mem m field_moves) moves in
  Option.map (( + ) first_field_row) (List.find_index (( = ) fly) rows)

let first party =
  List.find_mapi
    (fun i moves ->
      Option.map (fun menu_row -> { slot = i + 1; menu_row }) (menu_row moves))
    party

let read_moves ~log slot =
  Summary_paging.to_page Summary_moves.moves_page;
  let known = Summary_moves.settled_rows () in
  log (Printf.sprintf "Fly: slot %d knows %s." slot (String.concat ", " known));
  Summary_paging.to_page Summary_paging.info_page;
  known

let no_user =
  Pokemon_engine.Failure.cause ~repeats:true "no_fly_user"
    "no party member knows Fly"

let read ~log =
  let found = ref None in
  let read_party () =
    found :=
      first
        (Summary_paging.until_member ~label:"fly user" ~log ~stop:(List.mem fly)
           (read_moves ~log))
  in
  Result.bind (Menu_input.run read_party) (fun () ->
      Option.to_result ~none:no_user !found)
