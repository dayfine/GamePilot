module P = Pokemon_engine.Plan
module Postconditions = Pokemon_engine.Postconditions
module A = Frlg_actions

type need = {
  joins : (string * string) list;
  used : string list;
  moves : string list;
  free : int;
}

let party_size = 6
let field_moves = [ "cut"; "fly"; "surf"; "strength" ]
let field_move_users = A.Action_args.field_move_users

type event_effect = {
  eff_joined : string list;
  eff_used : string list;
  eff_freed : int;
  eff_traded : string option;
  eff_moves : string list;
}

let no_effect =
  {
    eff_joined = [];
    eff_used = [];
    eff_freed = 0;
    eff_traded = None;
    eff_moves = [];
  }

let member_species = function
  | A.Action_args.Species s -> [ s ]
  | A.Action_args.Slot _ -> []

let of_request : A.Action_requests.t -> event_effect = function
  | Redeem_prize_mon slot ->
      {
        no_effect with
        eff_joined =
          Option.to_list (List.nth_opt A.Game_corner.fire_red_prizes slot);
      }
  | Pc_deposit (Members species) ->
      { no_effect with eff_used = species; eff_freed = List.length species }
  | Pc_deposit Holding_no_mail -> { no_effect with eff_freed = 1 }
  | Ingame_trade { offer; receive } ->
      { no_effect with eff_used = [ offer ]; eff_traded = receive }
  | Use_item { on = Some m; _ } ->
      { no_effect with eff_used = member_species m }
  | Give_bag_item { to_; _ } -> { no_effect with eff_used = member_species to_ }
  | Party_swap (By_species (s, _)) -> { no_effect with eff_used = [ s ] }
  | Verify_mail_glitch m -> { no_effect with eff_used = member_species m }
  | Cut_tree _ -> { no_effect with eff_moves = [ "cut" ] }
  | Surf -> { no_effect with eff_moves = [ "surf" ] }
  | Mart _
  | Use_item { on = None; _ }
  | Party_swap (Slots _)
  | Buy_coins _ | Spin_for_encounter _ | Pc_withdraw | Pick_up_item _
  | Read_caught _ ->
      no_effect

(* Collecting uncaught species needs no room: a full party sends them to the
   PC. *)
let of_capture ~single (plan : A.Capture_plan.t) =
  let eff_joined =
    match plan.target with
    | Species s -> List.init (if single then 1 else plan.catches) (fun _ -> s)
    | Uncaught _ -> []
  in
  { no_effect with eff_joined }

let decode_error ~where (cause : Pokemon_engine.Failure.cause) =
  where ^ cause.detail

let action_effect ~where action args =
  let map f r = Result.map f (Result.map_error (decode_error ~where) r) in
  if action = "mart" then Ok no_effect
  else if List.mem action A.Action_requests.names then
    map of_request (A.Action_requests.decode A.Mart_plan.empty action args)
  else
    match (action, List.assoc_opt action field_move_users) with
    | _, Some move -> Ok { no_effect with eff_moves = [ move ] }
    | "capture", _ ->
        map (of_capture ~single:false) (A.Capture_plan.decode args)
    | "wild_rng", _ | "static_rng", _ ->
        map (of_capture ~single:true) (A.Capture_plan.decode args)
    | "gift_rng", _ ->
        let decode ~where a = Json_field.string ~where "species" a in
        map
          (fun s -> { no_effect with eff_joined = [ s ] })
          (A.Action_args.decode ~action decode args)
    | _ ->
        map
          (fun eff_used -> { no_effect with eff_used })
          (A.Action_args.decode ~action A.Action_args.named_species args)

type scan = {
  scan_joins : (string * string) list;
  scan_used : string list;
  scan_traded : string list;
  scan_moves : string list;
  delta : int;
  peak : int;
}

let empty_scan =
  {
    scan_joins = [];
    scan_used = [];
    scan_traded = [];
    scan_moves = [];
    delta = 0;
    peak = 0;
  }

(* Unconditional [pc_deposit] frees party slots: 1 for a role deposit
   ("member": "holding_no_mail"), or one per species in ["species"]. *)
let apply_effect id ~skippable acc eff =
  let freed = if skippable then 0 else eff.eff_freed in
  let delta = acc.delta + List.length eff.eff_joined - freed in
  {
    scan_joins = acc.scan_joins @ List.map (fun s -> (s, id)) eff.eff_joined;
    scan_used = acc.scan_used @ eff.eff_used;
    scan_traded = Option.to_list eff.eff_traded @ acc.scan_traded;
    scan_moves = eff.eff_moves @ acc.scan_moves;
    delta;
    peak = max acc.peak delta;
  }

let event id acc (e : P.event) =
  match (e.kind, e.way) with
  | Named_action args, Some action ->
      let where = id ^ " " ^ e.id ^ ": " in
      Result.map
        (apply_effect id ~skippable:(e.skip_if <> []) acc)
        (action_effect ~where action args)
  | _ -> Ok acc

let promised (p : Postconditions.t) =
  match p.party with
  | Some (Postconditions.Party_in_order l) -> l
  | Some (Postconditions.Party_includes { members; slots }) ->
      members @ List.map (fun (s : Postconditions.slot) -> s.species) slots
  | None -> []

let plan acc (p : P.t) =
  let id = p.checkpoint.checkpoint_id in
  let step acc e = Result.bind acc (fun acc -> event id acc e) in
  Result.map
    (fun acc ->
      {
        acc with
        scan_used =
          acc.scan_used @ promised (Postconditions.stated p.postconditions);
      })
    (List.fold_left step (Ok acc) p.checkpoint.events)

let chain_need plans =
  let step acc p = Result.bind acc (fun acc -> plan acc p) in
  Result.map
    (fun acc ->
      let brought = List.map fst acc.scan_joins @ acc.scan_traded in
      let used = List.sort_uniq compare acc.scan_used in
      {
        joins = acc.scan_joins;
        used = List.filter (fun s -> not (List.mem s brought)) used;
        moves = List.sort_uniq compare acc.scan_moves;
        free = acc.peak;
      })
    (List.fold_left step (Ok empty_scan) plans)

let free_needed need = need.free

type member = Room_policy.member

let lead_stays = true

let rules need : Room_policy.rules =
  {
    party_size;
    used = need.used;
    field_moves;
    needed_moves = need.moves;
    lead_stays;
  }

let precondition need : Room_policy.precondition =
  { free_slots = free_needed need }

let deposits need party =
  Result.map
    (List.map (fun (d : Room_policy.deposit) -> d.species))
    (Room_policy.choose (rules need) (precondition need) party)

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
