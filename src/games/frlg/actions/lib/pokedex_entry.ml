type entry = Not_seen | Seen | Caught

let entry_name = function
  | Not_seen -> "not seen"
  | Seen -> "seen"
  | Caught -> "caught"

type shown = { row : int; number : int }

type game_steps = {
  open_list : unit -> unit;
  look : unit -> shown option;
  tap : Wire.button -> unit;
  entry_on : row:int -> name:string -> entry option;
  close_list : unit -> unit;
  log : string -> unit;
}

let kanto_count = 151
let page = 9
let max_taps = 40
let max_still = 2

let number_of species slug =
  let rec find i = function
    | [] -> None
    | (s, _) :: _ when s = slug -> if i <= kanto_count then Some i else None
    | _ :: rest -> find (i + 1) rest
  in
  find 1 species

(* Toward the target: a page while it is a page or more away. *)
let direction ~from ~target =
  let gap = target - from in
  if gap >= page then Wire.Right
  else if gap > 0 then Wire.Down
  else if gap <= -page then Wire.Left
  else Wire.Up

(* [Ok (Some row)] once the arrow is on [number]; [Ok None] when taps toward
   it below move nothing: the list ends above it. *)
let rec seek steps ~number ~taps ~still last =
  match steps.look () with
  | None -> Error "the list's arrow and number did not read"
  | Some shown when shown.number = number -> Ok (Some shown.row)
  | Some shown ->
      let still = if last = Some shown.number then still + 1 else 0 in
      if shown.number < number && still >= max_still then Ok None
      else if taps >= max_taps then
        Error (Printf.sprintf "No%03d not reached in %d taps" number max_taps)
      else (
        steps.tap (direction ~from:shown.number ~target:number);
        seek steps ~number ~taps:(taps + 1) ~still (Some shown.number))

let unread_row number name =
  Printf.sprintf "No%03d's row shows neither %s nor dashes" number name

let on_row steps ~number ~name row =
  Option.to_result (steps.entry_on ~row ~name) ~none:(unread_row number name)

let entry steps ~number ~name =
  match seek steps ~number ~taps:0 ~still:0 None with
  | Error e -> Error e
  | Ok None -> Ok Not_seen
  | Ok (Some row) -> on_row steps ~number ~name row

let read_with steps ~number ~name =
  steps.open_list ();
  let read = entry steps ~number ~name in
  steps.log
    (match read with
    | Ok e ->
        Printf.sprintf "Pokedex: %s (No%03d) %s." name number (entry_name e)
    | Error e -> Printf.sprintf "Pokedex: %s (No%03d) unread: %s." name number e);
  steps.close_list ();
  read
