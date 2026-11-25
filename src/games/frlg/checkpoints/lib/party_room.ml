module J = Grid_maps.Json_field
module P = Checkpoints_plan.Plan

type need = {
  joins : (string * string) list;
  used : string list;
  moves : string list;
}

let party_size = 6
let field_moves = [ "cut"; "fly"; "surf"; "strength" ]

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

let field_move_users = Frlg_actions.Action_args.field_move_users

(* A field move's user is any member that knows it ([moves]): the action
   names none the plans use. *)
let named ~where action args =
  let brought = brought_keys action in
  if List.mem_assoc action field_move_users then []
  else
    List.filter_map
      (fun k -> if List.mem k brought then None else J.string_opt ~where k args)
      Frlg_actions.Action_args.member_keys

let event id (joins, used) (e : P.event) =
  match (e.kind, e.action) with
  | Game_action args, Some action ->
      let where = id ^ " " ^ e.id ^ ": " in
      ( joins @ List.map (fun s -> (s, id)) (joining ~where action args),
        used @ named ~where action args )
  | _ -> (joins, used)

let promised (p : P.postconditions) =
  match p.party with
  | Some (P.Party_in_order l) -> l
  | Some (P.Party_includes { members; slots }) ->
      members @ List.map (fun (s : P.slot) -> s.species) slots
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

(* The field moves the plans' events need some member to know. *)
let needed_moves (p : P.t) =
  List.filter_map
    (fun (e : P.event) ->
      match (e.kind, e.action) with
      | Game_action _, Some action -> List.assoc_opt action field_move_users
      | _ -> None)
    p.checkpoint.events

let chain_need plans =
  let joins, used = List.fold_left plan ([], []) plans in
  let brought = List.map fst joins @ List.concat_map traded plans in
  let used = List.sort_uniq compare used in
  {
    joins;
    used = List.filter (fun s -> not (List.mem s brought)) used;
    moves = List.sort_uniq compare (List.concat_map needed_moves plans);
  }

let free_needed need = List.length need.joins

type member = Checkpoints_run.Room_policy.member

let lead_stays = true

let rules need : Checkpoints_run.Room_policy.rules =
  {
    party_size;
    used = need.used;
    field_moves;
    needed_moves = need.moves;
    lead_stays;
  }

let precondition need : Checkpoints_run.Room_policy.precondition =
  { free_slots = free_needed need }

let deposits need party =
  Result.map
    (List.map (fun (d : Checkpoints_run.Room_policy.deposit) -> d.species))
    (Checkpoints_run.Room_policy.choose (rules need) (precondition need) party)

let unread slot species : member =
  {
    slot = slot + 1;
    species = Option.value species ~default:"?";
    level = None;
    moves = None;
  }

let joins_text need =
  String.concat ", " (List.map (fun (s, id) -> s ^ " " ^ id) need.joins)

let party_read need members =
  let free = Printf.sprintf "%d free" (party_size - List.length members) in
  match deposits need members with
  | Ok [] -> (free, Some true)
  | Ok l -> (free ^ "; deposit " ^ String.concat ", " l, Some false)
  | Error why -> (free ^ "; " ^ why, Some false)

let report need ~members party =
  let text =
    Printf.sprintf "%d free party slots (%s)" (free_needed need)
      (joins_text need)
  in
  match (members, party) with
  | Some members, _ ->
      let read, ok = party_read need members in
      (text, read, ok)
  | None, Some party ->
      let read, ok = party_read need (List.mapi unread party) in
      (text, read, ok)
  | None, None -> (text, "party not read", None)
