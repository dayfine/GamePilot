module J = Json_field

type item = { slug : string; id : int; names : string list }
type t = { items : item list }

let asset = "src/games/pokemon/frlg/assets/ace_presets.json"
let source = "ace_presets.json: "
let boxes = 14

(* {"1": name, ...}: the box numbers and their names. *)
let box_names ~where obj =
  List.map
    (fun (key, v) ->
      match (int_of_string_opt key, v) with
      | Some b, `String name -> (b, name)
      | _ -> J.fail "%s%s is not a box number and a name." where key)
    obj

let check_name ~where (b, name) =
  match Frlg_text.Naming_keyboard.chars name with
  | Error e -> J.fail "%sBox %d: %s" where b e
  | Ok cs when cs = [] || List.length cs > Naming_entry.box_name_chars ->
      J.fail "%sBox %d: \"%s\" is not 1 to %d characters." where b name
        Naming_entry.box_name_chars
  | Ok cs when List.for_all (fun c -> c = " ") cs ->
      J.fail "%sBox %d: \"%s\" is only spaces." where b name
  | Ok _ -> ()

let all_boxes = List.init boxes (fun i -> i + 1)

(* Boxes 1 to 14 named once each, in box order. *)
let ordered ~where named =
  if List.sort compare (List.map fst named) <> all_boxes then
    J.fail "%sthe code and the item do not name Boxes 1 to %d once each." where
      boxes;
  List.iter (check_name ~where) named;
  List.map snd (List.sort compare named)

let box_number ~where = function
  | `Int b -> b
  | _ -> J.fail "%sitem_boxes holds a non-number." where

let code_of ~where name code =
  let where = where ^ "codes." ^ name ^ "." in
  let obj = J.as_object where code in
  let shared =
    box_names ~where (J.as_object where (J.field ~where "boxes" obj))
  in
  let listed = J.list_opt ~where "item_boxes" obj in
  (shared, List.map (box_number ~where) (Option.value listed ~default:[]))

let code_boxes ~where codes name =
  match J.find name codes with
  | None -> J.fail "%scode %s is not in codes." where name
  | Some code -> code_of ~where:source name code

let item codes (slug, json) =
  let where = source ^ "items." ^ slug ^ "." in
  let obj = J.as_object where json in
  let shared, item_boxes =
    code_boxes ~where codes (J.string ~where "code" obj)
  in
  let own = box_names ~where (J.as_object where (J.field ~where "boxes" obj)) in
  if List.sort compare (List.map fst own) <> List.sort compare item_boxes then
    J.fail "%sboxes are not its code's item_boxes." where;
  { slug; id = J.int ~where "id" obj; names = ordered ~where (shared @ own) }

let parse json =
  J.catch (fun () ->
      let obj = J.as_object source json in
      let codes = J.as_object source (J.field ~where:source "codes" obj) in
      let items = J.as_object source (J.field ~where:source "items" obj) in
      { items = List.map (item codes) items })

let read () =
  match Repo_io.Repo_files.locate asset with
  | None -> Error (asset ^ " not found from the working directory")
  | Some path -> Result.bind (Repo_io.Json_file.read path) parse

let table = lazy (read ())
let load () = Lazy.force table
let slugs t = List.map (fun i -> i.slug) t.items
let find t slug = List.find_opt (fun i -> i.slug = slug) t.items
let box_name item b = List.nth item.names (b - 1)

let known_names t b =
  List.sort_uniq compare
    (Printf.sprintf "BOX%d" b :: List.map (fun i -> box_name i b) t.items)

let item_of t slug =
  Option.to_result ~none:(slug ^ " is not in " ^ asset) (find t slug)
  |> Result.map (fun item -> (t, item))

let run_item options =
  let slug =
    Option.to_result
      ~none:"frlg.ace needs its item option (--options item=<slug>)"
      (Run_options.find options "item")
  in
  Result.bind (load ()) (fun t -> Result.bind slug (item_of t))
