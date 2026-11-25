(* The generated blocks of a user guide page (docs/guide/, Guide_page): what
   the code and the plans say, so the page cannot drift from them.

   - programs: every registered program, with its guide (the guides' index);
   - backends: where the program runs, on the Switch with its game picture
     (Program_registry's backends and viewport);
   - checkpoints [RANGE]: each checkpoint's id and its plan's title, a
     repeating one marked, and a digest of those plans' files, so a plan change
     makes the page stale until it is regenerated;
   - needs [RANGE]: what the save must hold for the whole chain: its free
     party slots (Frlg_checkpoints.Party_room) and the pre-flight's needs
     (Frlg_checkpoints.Preflight.needs, the checkpoint before's promises included)
     of the chain's events taken as one plan: the members and field moves no
     earlier event brings, the money all its purchases cost, the items no
     earlier purchase or pickup brings, and the start;
   - preflight [RANGE]: per checkpoint, what the pre-flight checks before a
     run resumed there;
   - commands [RANGE]: the commands that run it on each backend.

   RANGE is FROM..TO or one id; default: every checkpoint. *)

module R = Program_registry

let ( let* ) = Result.bind
let guide_dir = "docs/guide"
let page_of (p : R.t) = Filename.concat guide_dir (p.id ^ ".md")

type plans = { dir : string; ids : string list }

let plans_of (p : R.t) =
  match p.checkpoints with
  | None -> Error (p.id ^ " has no checkpoints")
  | Some path -> (
      match R.locate path with
      | None -> Error (path ^ " not found from here: run in the repo")
      | Some dir ->
          let* ids = Plan_dir.checkpoint_ids dir in
          Ok { dir; ids })

(* FROM..TO's two ids; one id is both. *)
let bounds a =
  match String.index_opt a '.' with
  | Some i when i + 1 < String.length a && a.[i + 1] = '.' ->
      (String.sub a 0 i, String.sub a (i + 2) (String.length a - i - 2))
  | _ -> (a, a)

(* The ids a block's arg names: FROM..TO, one id, or all. *)
let range plans = function
  | None -> Ok plans.ids
  | Some a ->
      let from_id, to_id = bounds a in
      Result.map fst (Plan_dir.select plans.ids ~from_id ~to_id)

let last l = List.nth l (List.length l - 1)

(* [f] of each id, in order; the first error otherwise. *)
let collect f ids =
  List.fold_left
    (fun acc id ->
      let* acc = acc in
      let* x = f id in
      Ok (acc @ [ x ]))
    (Ok []) ids

let load plans ids = collect (Plan_dir.load_plan ~plan_dir:plans.dir) ids
let read_file path = In_channel.with_open_bin path In_channel.input_all

(* Line endings dropped, so a checkout with CRLF digests the same. *)
let digest plans ids =
  ids
  |> List.map (fun id ->
         read_file (Plan_dir.plan_file ~plan_dir:plans.dir id)
         |> String.split_on_char '\r' |> String.concat "")
  |> String.concat "\n" |> Digest.string |> Digest.to_hex
  |> fun hex -> String.sub hex 0 12

(* A table cell: no pipe ends it. *)
let cell s = String.concat "\\|" (String.split_on_char '|' s)

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

(* PLZA's plans are over its own rules (Plza_checkpoints). *)
let is_plza (p : R.t) = p.game.game_id = "plza"

let plza_row plans id =
  Result.map
    (fun (plan : Plza_checkpoints.Plan.t) ->
      Printf.sprintf "| %s | %s |" plan.checkpoint.checkpoint_id
        (cell plan.checkpoint.title))
    (Plza_series.load_plan ~plan_dir:plans.dir id)

let checkpoint_rows p plans ids =
  if is_plza p then collect (plza_row plans) ids
  else Result.map (List.map checkpoint_row) (load plans ids)

let checkpoints p arg =
  let* plans = plans_of p in
  let* ids = range plans arg in
  let* rows = checkpoint_rows p plans ids in
  Ok
    (String.concat "\n"
       ([ "| Checkpoint | What its plan does |"; "|---|---|" ]
       @ rows
       @ [ ""; Printf.sprintf "<!-- plans: %s -->" (digest plans ids) ]))

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
  let* before = Plan_dir.promised_before ~plan_dir:plans.dir (List.hd chain) in
  let* stocks = Frlg_actions.Mart_plan.load () in
  match chain_lines stocks ~before loaded with
  | lines -> Result.map (String.concat "\n") lines
  | exception Json_field.Invalid e -> Error e

let needs_text needs =
  cell (String.concat "; " (List.map Frlg_checkpoints.Preflight.describe needs))

(* One row per checkpoint: what the pre-flight checks before resuming there. *)
let preflight_row stocks plans id =
  let* plan = Plan_dir.load_plan ~plan_dir:plans.dir id in
  let* before = Plan_dir.promised_before ~plan_dir:plans.dir id in
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

let backend_label = function R.Mgba -> "mGBA" | R.Switch -> "the Switch"

(* The Switch with where its game picture is (the descriptor's viewport). *)
let backend_with_picture (p : R.t) = function
  | R.Switch when p.viewport = R.Nso_gba -> "the Switch (in its GBA app)"
  | b -> backend_label b

let backends (p : R.t) =
  Ok
    ("Runs on: "
    ^ String.concat ", " (List.map (backend_with_picture p) p.backends)
    ^ ".")

let mgba_note =
  "# mGBA: each checkpoint three times from its start state, two must pass"

let switch_note =
  "# the Switch: check the save first, then run (each checkpoint once, saved \
   when it passes)"

let script backend args =
  Printf.sprintf "sh run/run_checkpoints_on_%s.sh %s" backend args

let backend_commands args = function
  | R.Mgba -> [ mgba_note; script "mgba" args ^ " --mode verification" ]
  | R.Switch ->
      [
        switch_note;
        script "switch" args ^ " --preflight-only";
        script "switch" args;
      ]

(* PLZA runs through gamepilot checkpoints itself (Plza_series). *)
let plza_commands args =
  String.concat "\n"
    [
      "# the Switch: each checkpoint once, from where the console is";
      "cd src && opam exec -- dune exec -- gamepilot checkpoints " ^ args
      ^ " --mode testing --backend switch --serial PORT --capture DEVICE \\";
      "    --watch";
    ]

let checkpoint_commands (p : R.t) ~from_id ~to_id =
  let args =
    Printf.sprintf "--program %s --from %s --to %s" p.id from_id to_id
  in
  if is_plza p then plza_commands args
  else
    String.concat "\n\n"
      (List.map
         (fun b -> String.concat "\n" (backend_commands args b))
         p.backends)

let commands (p : R.t) arg =
  let body =
    match p.checkpoints with
    | None -> Ok ("cd src && opam exec -- dune exec -- gamepilot run " ^ p.id)
    | Some _ ->
        let* plans = plans_of p in
        let* ids = range plans arg in
        Ok (checkpoint_commands p ~from_id:(List.hd ids) ~to_id:(last ids))
  in
  Result.map (fun b -> "```sh\n" ^ b ^ "\n```") body

let program_row (p : R.t) =
  Printf.sprintf "| [%s](%s.md) | `%s` | %s | %s |" p.name p.id p.id
    (String.concat ", " (List.map backend_label p.backends))
    (cell p.description)

let programs () =
  Ok
    (String.concat "\n"
       ([ "| Program | Id | Runs on | What it does |"; "|---|---|---|---|" ]
       @ List.map program_row R.all))

let generate (p : R.t option) (b : Guide_page.block) =
  match (b.name, p) with
  | "programs", _ -> programs ()
  | "backends", Some p -> backends p
  | "checkpoints", Some p -> checkpoints p b.arg
  | "needs", Some p -> needs p b.arg
  | "preflight", Some p -> preflight p b.arg
  | "commands", Some p -> commands p b.arg
  | ("backends" | "checkpoints" | "needs" | "preflight" | "commands"), None ->
      Error (b.name ^ ": this page is not a program's")
  | name, _ -> Error ("no generated block " ^ name)
