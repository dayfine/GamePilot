let checkpoint_row (plan : Pokemon_checkpoints.Plan.t) =
  let repeats =
    match plan.repeat with
    | Some { max_rounds; _ } ->
        Printf.sprintf " (repeats, at most %d rounds)" max_rounds
    | None -> ""
  in
  Printf.sprintf "| %s | %s%s |" plan.checkpoint.checkpoint_id
    (cell plan.checkpoint.title)
    repeats

let plural n one many = if n = 1 then one else many

let room_line (room : Frlg_checkpoints.Party_room.need) =
  let free = Frlg_checkpoints.Party_room.free_needed room in
  let joins =
    List.map
      (fun (species, cp) -> Printf.sprintf "%s in %s" species cp)
      room.joins
  in
  Printf.sprintf "- %d free party %s%s" free
    (plural free "slot" "slots")
    (if joins = [] then "" else " (joining: " ^ String.concat ", " joins ^ ")")

(* The chain as one plan: its events in order from the first checkpoint's
   start, so an item or member one checkpoint brings counts for the later
   ones, and the money is all its purchases'. *)
let as_one_plan (loaded : Pokemon_checkpoints.Plan.t list) =
  let first = List.hd loaded in
  let events =
    List.concat_map
      (fun (p : Pokemon_checkpoints.Plan.t) -> p.checkpoint.events)
      loaded
  in
  { first with checkpoint = { first.checkpoint with events } }

(* A member that joins on the way (a Game Corner prize, a capture) is not the
   save's; the money is said once for all the purchases. *)
let chain_need (room : Frlg_checkpoints.Party_room.need) =
  let module Pf = Frlg_checkpoints.Preflight in
  function
  | Pf.Member { species; _ } when List.mem_assoc species room.joins -> None
  | Pf.Money_at_least { amount; _ } ->
      Some (Pf.Money_at_least { amount; for_ = "all the purchases" })
  | n -> Some n

(* The chain's declared preconditions are its first checkpoint's: the save's
   state where it starts. *)
let chain_lines stocks ~before (loaded : Pokemon_checkpoints.Plan.t list) =
  let room = Frlg_checkpoints.Party_room.chain_need loaded in
  let* needs =
    Frlg_checkpoints.Preflight.needs stocks ~before (as_one_plan loaded)
  in
  let line n = "- " ^ Frlg_checkpoints.Preflight.describe n in
  Ok (room_line room :: List.map line (List.filter_map (chain_need room) needs))

let needs p arg =
  let* plans = plans_of p in
  let* chain = range plans arg in
  let* loaded = load plans chain in
  let* before = Frlg_series.Plan_dir.promised_before ~plan_dir:plans.dir (List.hd chain) in
  let* stocks = Frlg_actions.Mart_plan.load () in
  match chain_lines stocks ~before loaded with
  | lines -> Result.map (String.concat "\n") lines
  | exception Json_field.Invalid e -> Error e

let needs_text needs =
  cell (String.concat "; " (List.map Frlg_checkpoints.Preflight.describe needs))

(* One row per checkpoint: what the pre-flight checks before resuming there. *)
let preflight_row stocks plans id =
  let* plan = Frlg_series.Plan_dir.load_plan ~plan_dir:plans.dir id in
  let* before = Frlg_series.Plan_dir.promised_before ~plan_dir:plans.dir id in
  match Frlg_checkpoints.Preflight.needs stocks ~before plan with
  | needs ->
      Result.map
        (fun needs -> Printf.sprintf "| %s | %s |" id (needs_text needs))
        needs
  | exception Json_field.Invalid e -> Error e

let preflight p arg =
  let* plans = plans_of p in
  let* ids = range plans arg in
  let* stocks = Frlg_actions.Mart_plan.load () in
  let* rows = collect (preflight_row stocks plans) ids in
  Ok
    (String.concat "\n"
       ([ "| Resume from | The pre-flight checks |"; "|---|---|" ] @ rows))
