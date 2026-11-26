type shown = Seen | Always | Game_clear | National
type group = { id : int; shown : shown; name : string; words : string list }
type t = group list

let shown_of_string = function
  | "seen" -> Ok Seen
  | "always" -> Ok Always
  | "game_clear" -> Ok Game_clear
  | "national" -> Ok National
  | s -> Error ("unknown shown " ^ s)

let group_of_fields id shown rest =
  match (int_of_string_opt id, shown_of_string shown) with
  | Some id, Ok shown -> (
      match String.split_on_char '|' rest with
      | name :: words -> Ok { id; shown; name; words }
      | [] -> Error "no group name")
  | None, _ -> Error ("bad group id " ^ id)
  | _, Error e -> Error e

let line l =
  match String.split_on_char ' ' l with
  | id :: shown :: rest -> group_of_fields id shown (String.concat " " rest)
  | _ -> Error ("bad line: " ^ l)

let of_string text =
  let lines =
    List.filter
      (fun l -> l <> "" && l.[0] <> '#')
      (String.split_on_char '\n' text)
  in
  List.fold_right
    (fun l acc ->
      Result.bind acc (fun groups -> Result.map (fun g -> g :: groups) (line l)))
    lines (Ok [])

let load path = of_string (In_channel.with_open_bin path In_channel.input_all)
let group t name = List.find_opt (fun g -> g.name = name) t
let names t = List.map (fun g -> g.name) t
let first_letter word = if word = "" then None else Some word.[0]

let look_alikes g word =
  List.filter (fun w -> first_letter w = first_letter word) g.words
