module S = Plza_story.Steps
module L = Plza_story.Look

let reads = 5
let poll_ms = 250

let talk_or_battle (l : L.t) =
  L.text_shows l || l.choice_box || l.tutorial_card || l.battle
  || L.fade_shows l

(* Free control after the starter: the party bar with nothing over it and no
   battle HUD (the battle keeps the bar up). *)
let party_bar_free (l : L.t) = l.party_bar && L.overworld_free l && not l.battle

(* How a flag reads: on any of the reads, or on every one. *)
type reading = Any | Every

let flags =
  [
    ("talk_or_battle_shows", (Any, talk_or_battle));
    ("battle_shows", (Any, fun (l : L.t) -> l.battle));
    ("party_bar_free", (Every, party_bar_free));
  ]

let log_look steps (look : L.t) =
  S.(steps.log) (Printf.sprintf "[PLZA] resume: %s." (L.describe look))

(* Any of [n] reads, [poll_ms] apart, shows it. *)
let rec any steps shows n =
  let look = S.(steps.read_screen) () in
  if shows look then (
    log_look steps look;
    true)
  else if n <= 1 then false
  else (
    S.wait steps poll_ms;
    any steps shows (n - 1))

(* Every one of [n] reads, [poll_ms] apart, shows it. *)
let rec every steps shows n =
  let look = S.(steps.read_screen) () in
  if not (shows look) then false
  else if n <= 1 then (
    log_look steps look;
    true)
  else (
    S.wait steps poll_ms;
    every steps shows (n - 1))

(* "minimap:<name>": the minimap reads as that recorded one. *)
let minimap_prefix = "minimap:"

let minimap_flag flag =
  if String.starts_with ~prefix:minimap_prefix flag then
    let n = String.length minimap_prefix in
    let name = String.sub flag n (String.length flag - n) in
    Some (Every, fun (l : L.t) -> l.minimap = Some name)
  else None

let find flag =
  match List.assoc_opt flag flags with
  | Some f -> Some f
  | None -> minimap_flag flag

let known flag =
  match find flag with
  | None -> Error (Printf.sprintf "unknown skip_if flag %S" flag)
  | Some _ when String.starts_with ~prefix:minimap_prefix flag ->
      let n = String.length minimap_prefix in
      let name = String.sub flag n (String.length flag - n) in
      if List.mem name Plza_readers.Minimap.reference_names then Ok ()
      else
        Error (Printf.sprintf "skip_if %S: no minimap %S is recorded" flag name)
  | Some _ -> Ok ()

let holds steps flag =
  match find flag with
  | Some (reading, shows) -> (
      Plza_story.Screen_wake.run steps;
      match reading with
      | Any -> any steps shows reads
      | Every -> every steps shows reads)
  | None ->
      S.(steps.log)
        (Printf.sprintf "[PLZA] unknown skip_if flag %S: does not hold." flag);
      false
