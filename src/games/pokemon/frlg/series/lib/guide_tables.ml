(* FRLG's blocks of a program's user guide page (bin/guide_blocks.ml): each
   checkpoint's row, what the save must hold for a chain, and what the
   pre-flight checks before each checkpoint.

   The needs of a chain are its free party slots (Frlg_checkpoints.Party_room)
   and the pre-flight's needs (Frlg_checkpoints.Preflight.needs, the
   checkpoint before's promises included) of the chain's events taken as one
   plan: the members and field moves no earlier event brings, the money all
   its purchases cost, the items no earlier purchase or pickup brings, and the
   start. *)

let ( let* ) = Result.bind
let cell = Guide_page.cell

(* [f] of each id, in order; the first error otherwise. *)
let collect f ids =
  List.fold_left
    (fun acc id ->
      let* acc = acc in
      let* x = f id in
      Ok (acc @ [ x ]))
    (Ok []) ids

let load ~plan_dir ids = collect (Plan_dir.load_plan ~plan_dir) ids

let checkpoint_row (plan : Pokemon_engine.Plan.t) =
  let repeats =
    match plan.repeat with
    | Some { max_rounds; _ } ->
        Printf.sprintf " (repeats, at most %d rounds)" max_rounds
    | None -> ""
  in
  Printf.sprintf "| %s | %s%s |" plan.checkpoint.checkpoint_id
    (cell plan.checkpoint.title)
    repeats

let rows ~plan_dir ids =
  Result.map (List.map checkpoint_row) (load ~plan_dir ids)

let plural n one many = if n = 1 then one else many

(* No line when the chain needs no free slot at the start: a need of zero is no
   need (review rule R2). *)
let room_line (room : Frlg_checkpoints.Party_room.need) =
  let free = Frlg_checkpoints.Party_room.free_needed room in
  let joins =
    List.map
      (fun (species, cp) -> Printf.sprintf "%s in %s" species cp)
      room.joins
  in
  if free = 0 then []
  else
    [
      Printf.sprintf "- %d free party %s%s" free
        (plural free "slot" "slots")
        (if joins = [] then ""
         else " (joining: " ^ String.concat ", " joins ^ ")");
    ]

(* The chain as one plan: its events in order from the first checkpoint's
   start, so an item or member one checkpoint brings counts for the later
   ones, and the money is all its purchases'. *)
let as_one_plan (loaded : Pokemon_engine.Plan.t list) =
  let first = List.hd loaded in
  let events =
    List.concat_map
      (fun (p : Pokemon_engine.Plan.t) -> p.checkpoint.events)
      loaded
  in
  { first with checkpoint = { first.checkpoint with events } }

(* A member that joins on the way (a Game Corner prize, a capture) is not the
   save's; the money is said once for all the purchases. *)
let chain_need (room : Frlg_checkpoints.Party_room.need) =
  let module Need = Frlg_checkpoints.Need in
  function
  | Need.Member { species; _ } when List.mem_assoc species room.joins -> None
  | Need.Money_at_least { amount; _ } ->
      Some (Need.Money_at_least { amount; for_ = "all the purchases" })
  | n -> Some n

(* The chain's declared preconditions are its first checkpoint's: the save's
   state where it starts. *)
let chain_lines stocks ~before (loaded : Pokemon_engine.Plan.t list) =
  let room = Frlg_checkpoints.Party_room.chain_need loaded in
  let* needs =
    Frlg_checkpoints.Preflight.needs stocks ~before (as_one_plan loaded)
  in
  let line n = "- " ^ Frlg_checkpoints.Preflight.describe n in
  let needs =
    List.filter_map (chain_need room) needs
    |> List.filter Frlg_checkpoints.Preflight.asks_something
  in
  Ok (room_line room @ List.map line needs)

let needs ~plan_dir chain =
  let* loaded = load ~plan_dir chain in
  let* before = Plan_dir.promised_before ~plan_dir (List.hd chain) in
  let* stocks = Frlg_actions.Mart_plan.load () in
  match chain_lines stocks ~before loaded with
  | lines -> Result.map (String.concat "\n") lines
  | exception Json_field.Invalid e -> Error e

(* The needs any save meets left out (review rule R2). *)
let needs_text needs =
  let needs = List.filter Frlg_checkpoints.Preflight.asks_something needs in
  cell (String.concat "; " (List.map Frlg_checkpoints.Preflight.describe needs))

(* One row per checkpoint: what the pre-flight checks before resuming there. *)
let preflight_row stocks ~plan_dir id =
  let* plan = Plan_dir.load_plan ~plan_dir id in
  let* before = Plan_dir.promised_before ~plan_dir id in
  match Frlg_checkpoints.Preflight.needs stocks ~before plan with
  | needs ->
      Result.map
        (fun needs -> Printf.sprintf "| %s | %s |" id (needs_text needs))
        needs
  | exception Json_field.Invalid e -> Error e

let preflight ~plan_dir ids =
  let* stocks = Frlg_actions.Mart_plan.load () in
  let* rows = collect (preflight_row stocks ~plan_dir) ids in
  Ok
    (String.concat "\n"
       ([ "| Resume from | The pre-flight checks |"; "|---|---|" ] @ rows))
