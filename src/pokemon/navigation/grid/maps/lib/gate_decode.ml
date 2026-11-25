open Json_field
open Grid_field
open Map_gates

let open_glyphs = ".~2468"

let openers =
  [
    ("card_key_face_a", Card_key);
    ("quiz_answer", Quiz_answer);
    ("cut", Cut);
    ("rock_smash", Rock_smash);
  ]

let tile_list ~where key obj =
  match list_opt ~where key obj with
  | Some (_ :: _ as tiles) ->
      List.mapi
        (fun i tile -> pair (Printf.sprintf "%s%s[%d]" where key i) tile)
        tiles
  | _ -> fail "%s%s is not a non-empty list of [x, y]." where key

let open_tile ~where obj =
  let glyph = string ~where "open_glyph" obj in
  let tile =
    if String.length glyph = 1 && String.contains open_glyphs glyph.[0] then
      Tile_kind.of_glyph glyph.[0]
    else None
  in
  match tile with
  | Some tile -> tile
  | None -> fail "%sopen_glyph \"%s\" is not one of %s." where glyph open_glyphs

let open_at_new_game ~where obj =
  match string ~where "new_game" obj with
  | "open" -> true
  | "closed" -> false
  | text -> fail "%snew_game \"%s\" is not open or closed." where text

let on_off ~where key obj =
  match string ~where key obj with
  | "on" -> true
  | "off" -> false
  | text -> fail "%s%s \"%s\" is not on or off." where key text

let flag_control ~where obj =
  let name = string ~where "opens_by" obj in
  match List.assoc_opt name openers with
  | Some opener -> Flag { opener; flag = string ~where "flag" obj }
  | None ->
      fail
        "%sopens_by \"%s\" is not card_key_face_a, quiz_answer, cut or \
         rock_smash."
        where name

let control ~where obj =
  let by_flag = has "opens_by" obj || has "flag" obj in
  let by_switch = has "switch" obj || has "open_when" obj in
  match (by_flag, by_switch) with
  | true, false -> flag_control ~where obj
  | false, true ->
      Switch
        {
          switch_id = string ~where "switch" obj;
          open_when_on = on_off ~where "open_when" obj;
        }
  | _ ->
      fail "%sneeds opens_by and flag, or switch and open_when, and not both."
        where

(* A flag gate starts closed; a switch gate starts as the switch is off. *)
let check_new_game ~where gate =
  let expected =
    match gate.control with
    | Flag _ -> false
    | Switch { open_when_on; _ } -> not open_when_on
  in
  if gate.open_at_new_game <> expected then
    fail "%snew_game is %s, but the gate starts %s." where
      (if gate.open_at_new_game then "open" else "closed")
      (if expected then "open" else "closed")

let gate ~where (gate_id, value) =
  let where = Printf.sprintf "%sgates.%s" where gate_id in
  let obj = as_object where value in
  let where = where ^ "." in
  let gate =
    {
      gate_id;
      gate_tiles = tile_list ~where "tiles" obj;
      open_tile = open_tile ~where obj;
      open_at_new_game = open_at_new_game ~where obj;
      control = control ~where obj;
    }
  in
  check_new_game ~where gate;
  gate

let gates ~where obj = List.map (gate ~where) (entries ~where "gates" obj)
let pair_field ~where key obj = pair (where ^ key) (field ~where key obj)

let statue ~where obj =
  {
    statue_tile = pair_field ~where "coord" obj;
    face_from = pair_field ~where "face_from" obj;
    facing = direction ~where "facing" obj;
  }

let non_empty ~where key = function
  | [] -> fail "%s%s is missing or empty." where key
  | items -> items

let press ~where obj =
  if bool_or ~where ~default:true "toggle" obj then
    Statues (non_empty ~where "statues" (records ~where "statues" obj statue))
  else
    let button ~where obj = pair_field ~where "coord" obj in
    Boulder_buttons
      {
        buttons =
          non_empty ~where "buttons" (records ~where "buttons" obj button);
        set_value = int ~where "set_value" obj;
      }

let floors ~where obj =
  match find "floors" obj with
  | Some (`List (_ :: _) as names) -> strings (where ^ "floors") names
  | _ -> fail "%sfloors is not a non-empty list of map names." where

let switch ~where (switch_name, value) =
  let where = Printf.sprintf "%sswitches.%s" where switch_name in
  let obj = as_object where value in
  let where = where ^ "." in
  {
    switch_name;
    switch_flag = string ~where "flag" obj;
    floors = floors ~where obj;
    press = press ~where obj;
  }

let switches ~where obj =
  List.map (switch ~where) (entries ~where "switches" obj)
