module J = Grid_maps.Json_field
module P = Story.Plan

type need = { joins : (string * string) list; used : string list }

let party_size = 6
let field_moves = [ "cut"; "fly"; "surf"; "strength" ]

let member_keys =
  [ "species"; "sweeper"; "knock_off_species"; "recycle_species" ]

(* The members an action brings, and the arg keys naming them. *)
let joining ~where action args =
  match action with
  | "redeem_prize_mon" ->
      let slot = Frlg_actions.Game_corner.prize_slot_of_args ~where args in
      Option.to_list
        (List.nth_opt Frlg_actions.Game_corner.fire_red_prizes slot)
  | "capture" ->
      let species = J.string ~where "species" args in
      List.init (J.int ~where "catches" args) (fun _ -> species)
  | _ -> []

let brought_keys = function
  | "capture" -> [ "species" ]
  | "ingame_trade" -> [ "receive" ]
  | _ -> []

let named ~where action args =
  let brought = brought_keys action in
  List.filter_map
    (fun k -> if List.mem k brought then None else J.string_opt ~where k args)
    member_keys

let event id (joins, used) (e : P.event) =
  match (e.kind, e.action) with
  | Game_action args, Some action ->
      let where = id ^ " " ^ e.id ^ ": " in
      ( joins @ List.map (fun s -> (s, id)) (joining ~where action args),
        used @ named ~where action args )
  | _ -> (joins, used)

let promised (p : P.postconditions) =
  match p.party with
  | Some (P.Party_in_order l | P.Party_includes l) -> l
  | None -> []

let plan acc (p : P.t) =
  let id = p.checkpoint.checkpoint_id in
  let joins, used = List.fold_left (event id) acc p.checkpoint.events in
  (joins, used @ promised p.postconditions)

(* The species a trade brings ("receive"). *)
let traded (p : P.t) =
  List.filter_map
    (fun (e : P.event) ->
      match (e.kind, e.action) with
      | Game_action args, Some "ingame_trade" ->
          J.string_opt ~where:(e.id ^ ": ") "receive" args
      | _ -> None)
    p.checkpoint.events

let chain_need plans =
  let joins, used = List.fold_left plan ([], []) plans in
  let brought = List.map fst joins @ List.concat_map traded plans in
  let used = List.sort_uniq compare used in
  { joins; used = List.filter (fun s -> not (List.mem s brought)) used }

let free_needed need = List.length need.joins

type member = {
  species : string;
  level : int option;
  moves : string list option;
}

(* Why a member stays, or [None] when it may go. *)
let keeps need m =
  if List.mem m.species need.used then Some "the plans use it"
  else
    match m.moves with
    | None -> Some "its moves did not read"
    | Some moves -> (
        match List.filter (fun f -> List.mem f moves) field_moves with
        | [] -> None
        | f :: _ -> Some ("it knows " ^ f))

let level_order a b =
  compare
    (Option.value a.level ~default:max_int)
    (Option.value b.level ~default:max_int)

let deposits need party =
  let short = free_needed need - (party_size - List.length party) in
  let may_go = List.filter (fun m -> keeps need m = None) party in
  let kept =
    List.filter_map
      (fun m -> Option.map (fun why -> m.species ^ ": " ^ why) (keeps need m))
      party
  in
  if short <= 0 then Ok []
  else if List.length may_go < short then
    Error
      (Printf.sprintf "%d to deposit, %d may go; kept: %s" short
         (List.length may_go) (String.concat "; " kept))
  else
    Ok
      (List.filteri (fun i _ -> i < short) (List.stable_sort level_order may_go)
      |> List.map (fun m -> m.species))

let unread species =
  { species = Option.value species ~default:"?"; level = None; moves = None }

let joins_text need =
  String.concat ", " (List.map (fun (s, id) -> s ^ " " ^ id) need.joins)

let party_read need party =
  let free = Printf.sprintf "%d free" (party_size - List.length party) in
  match deposits need (List.map unread party) with
  | Ok [] -> (free, Some true)
  | Ok l -> (free ^ "; deposit " ^ String.concat ", " l, Some false)
  | Error why -> (free ^ "; " ^ why, Some false)

let report need party =
  let text =
    Printf.sprintf "%d free party slots (%s)" (free_needed need)
      (joins_text need)
  in
  match party with
  | None -> (text, "party not read", None)
  | Some party ->
      let read, ok = party_read need party in
      (text, read, ok)
