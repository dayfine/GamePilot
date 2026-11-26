module C = Gift_catalog
module F = Json_field

let ( let* ) = Result.bind
let path = "src/games/pokemon/plza/gift_catalog/gifts.json"
let format = "gamepilot-gifts/1"
let where = "gifts.json: "

let fields =
  [
    "id";
    "name";
    "how";
    "code";
    "expires";
    "box_slot";
    "home_boxes";
    "home_order";
    "source";
  ]

let known_fields ~where obj =
  List.iter
    (fun (k, _) ->
      if not (List.mem k fields) then F.fail "%s%s is not a field" where k)
    obj

let how ~where = function
  | "code" -> C.Code
  | "internet" -> C.Internet
  | "home" -> C.Home
  | s -> F.fail "%show is %S, not code, internet or home" where s

let date ~where obj =
  match C.date_of_string (F.string ~where "expires" obj) with
  | Ok d -> d
  | Error e -> F.fail "%sexpires: %s" where e

let box_slot ~where obj : C.box_slot =
  let where = where ^ "box_slot." in
  { box = F.int ~where "box" obj; slot = F.int ~where "slot" obj }

let home_order ~where = function
  | "left_to_right" -> Pokemon_home.Box_view.Left_to_right
  | "right_to_left" -> Pokemon_home.Box_view.Right_to_left
  | s -> F.fail "%shome_order is %S, not left_to_right or right_to_left" where s

let home_boxes ~where obj =
  List.map
    (function
      | `Int b -> b | _ -> F.fail "%shome_boxes holds box numbers" where)
    (Option.value ~default:[] (F.list_opt ~where "home_boxes" obj))

let pokemon ~where obj =
  match (F.object_opt ~where "box_slot" obj, F.find "home_boxes" obj) with
  | None, None when not (F.has "home_order" obj) -> None
  | Some slot, Some _ ->
      Some
        {
          C.box_slot = box_slot ~where slot;
          home_boxes = home_boxes ~where obj;
          home_order = home_order ~where (F.string ~where "home_order" obj);
        }
  | _ -> F.fail "%sbox_slot, home_boxes and home_order go together" where

let gift ~where obj : C.gift =
  known_fields ~where obj;
  {
    id = F.string ~where "id" obj;
    name = F.string ~where "name" obj;
    how = how ~where (F.string ~where "how" obj);
    code = F.string_opt ~where "code" obj;
    expires = date ~where obj;
    pokemon = pokemon ~where obj;
    source = F.string ~where "source" obj;
  }

let decode json =
  F.catch (fun () ->
      let top = F.as_object where json in
      let given = F.string ~where "format" top in
      if given <> format then F.fail "%sformat is %S, not %S" where given format;
      F.records ~where "gifts" top gift)

(* The checks no one field shows. *)
let max_slot = 30
let home_box_most = 300
let max_id = 40
let id_char c = (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c = '-'
let code_char c = (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')

let sources =
  [ "dittobase.com/"; "nintendolife.com/"; "videogameschronicle.com/" ]

let on_source url =
  List.exists
    (fun host ->
      String.starts_with ~prefix:("https://" ^ host) url
      || String.starts_with ~prefix:("https://www." ^ host) url)
    sources

let check_id (g : C.gift) =
  if g.id <> "" && String.length g.id <= max_id && String.for_all id_char g.id
  then Ok ()
  else Error "the id is 1 to 40 of a-z, 0-9 and -"

let check_code (g : C.gift) =
  match (g.how, g.code) with
  | Code, Some c when c <> "" && String.for_all code_char c -> Ok ()
  | Code, Some _ -> Error "the code is upper-case letters and digits"
  | Code, None -> Error "a code gift needs its code"
  | (Internet | Home), Some _ -> Error "only a code gift has a code"
  | (Internet | Home), None -> Ok ()

let check_slot (g : C.gift) =
  match g.pokemon with
  | Some { box_slot = { box; slot }; home_boxes; _ }
    when box < 1 || slot < 1 || slot > max_slot || home_boxes = []
         || List.exists (fun b -> b < 1 || b > home_box_most) home_boxes ->
      Error "box is 1 or more, slot 1 to 30, home_boxes some of 1 to 300"
  | Some _ | None -> Ok ()

let check_source (g : C.gift) =
  if on_source g.source then Ok ()
  else Error "the source is a Dittobase, Nintendo Life or VGC page"

let check_gift (g : C.gift) =
  Result.map_error
    (fun e -> Printf.sprintf "%sgift %s: %s" where g.id e)
    (List.fold_left
       (fun acc check -> Result.bind acc (fun () -> check g))
       (Ok ())
       [ check_id; check_code; check_slot; check_source ])

let twice what keys =
  let sorted = List.sort compare keys in
  let rec first = function
    | a :: (b :: _ as rest) -> if a = b then Some a else first rest
    | [] | [ _ ] -> None
  in
  match first sorted with
  | Some k -> Error (Printf.sprintf "%s%s %s is given twice" where what k)
  | None -> Ok ()

let slot_name (p : C.pokemon) =
  Printf.sprintf "box %d slot %d" p.box_slot.box p.box_slot.slot

let check (catalog : C.t) =
  let* () =
    List.fold_left
      (fun acc g -> Result.bind acc (fun () -> check_gift g))
      (Ok ()) catalog
  in
  let* () = twice "id" (List.map (fun (g : C.gift) -> g.id) catalog) in
  twice "the"
    (List.filter_map
       (fun (g : C.gift) -> Option.map slot_name g.pokemon)
       catalog)

let of_json json =
  let* catalog = decode json in
  let* () = check catalog in
  Ok catalog
