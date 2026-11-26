(* The generated blocks of a user guide page (docs/guide/, Guide_page): what
   the code and the plans say, so the page cannot drift from them.

   - programs: every registered program, with its guide (the guides' index);
   - backends: where the program runs, on the Switch with its game picture
     (Program_registry's backends and viewport);
   - checkpoints [RANGE]: each checkpoint's id and its plan's title, a
     repeating one marked, and a digest of those plans' files, so a plan change
     makes the page stale until it is regenerated;
   - needs [RANGE]: what the save must hold for the whole chain, as the
     program's rules say it (Checkpoint_families);
   - preflight [RANGE]: per checkpoint, what the pre-flight checks before a
     run resumed there;
   - commands [RANGE]: the commands that run it on each backend.

   RANGE is FROM..TO or one id; default: every checkpoint. *)

module R = Program_registry

let ( let* ) = Result.bind
let guide_dir = "docs/guide"
let page_of (p : R.t) = Filename.concat guide_dir (p.id ^ ".md")

(* What a program's rules give its guide (Checkpoint_families): its
   checkpoints' rows, the needs and pre-flight blocks of a range of them, and
   how to run them ([args]: --program, --from, --to). *)
type rules_guide = {
  rows : plan_dir:string -> string list -> (string list, string) result;
  needs : plan_dir:string -> string list -> (string, string) result;
  preflight : plan_dir:string -> string list -> (string, string) result;
  commands : R.t -> args:string -> string;
}

type plans = { dir : string; ids : string list }

let plans_of (p : R.t) =
  match p.checkpoints with
  | None -> Error (p.id ^ " has no checkpoints")
  | Some path -> (
      match R.locate path with
      | None -> Error (path ^ " not found from here: run in the repo")
      | Some dir ->
          let* ids = Engine_series.Plan_folder.checkpoint_ids dir in
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
      Result.map fst
        (Engine_series.Plan_folder.select plans.ids ~from_id ~to_id)

let last l = List.nth l (List.length l - 1)
let read_file path = In_channel.with_open_bin path In_channel.input_all

(* Line endings dropped, so a checkout with CRLF digests the same. *)
let digest plans ids =
  ids
  |> List.map (fun id ->
         read_file (Engine_series.Plan_folder.plan_file ~plan_dir:plans.dir id)
         |> String.split_on_char '\r' |> String.concat "")
  |> String.concat "\n" |> Digest.string |> Digest.to_hex
  |> fun hex -> String.sub hex 0 12

let checkpoints ~guide p arg =
  let* plans = plans_of p in
  let* ids = range plans arg in
  let* rows = (guide p).rows ~plan_dir:plans.dir ids in
  Ok
    (String.concat "\n"
       ([ "| Checkpoint | What its plan does |"; "|---|---|" ]
       @ rows
       @ [ ""; Printf.sprintf "<!-- plans: %s -->" (digest plans ids) ]))

(* The needs or pre-flight block of the checkpoints [arg] names, from the
   program's rules ([block]). *)
let of_range block p arg =
  let* plans = plans_of p in
  let* ids = range plans arg in
  block ~plan_dir:plans.dir ids

let needs ~guide p arg = of_range (guide p).needs p arg
let preflight ~guide p arg = of_range (guide p).preflight p arg
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

let grid_commands (p : R.t) ~args =
  String.concat "\n\n"
    (List.map
       (fun b -> String.concat "\n" (backend_commands args b))
       p.backends)

(* gamepilot run's program, --from and --to for [ids]. *)
let program_args (p : R.t) ids =
  Printf.sprintf "%s --from %s --to %s" p.id (List.hd ids) (last ids)

let commands ~guide (p : R.t) arg =
  let body =
    match p.checkpoints with
    | None -> Ok ("cd src && opam exec -- dune exec -- gamepilot run " ^ p.id)
    | Some _ ->
        let* plans = plans_of p in
        let* ids = range plans arg in
        Ok ((guide p).commands p ~args:(program_args p ids))
  in
  Result.map (fun b -> "```sh\n" ^ b ^ "\n```") body

let program_row (p : R.t) =
  Printf.sprintf "| [%s](%s.md) | `%s` | %s | %s |" p.name p.id p.id
    (String.concat ", " (List.map backend_label p.backends))
    (Guide_page.cell p.description)

let programs () =
  Ok
    (String.concat "\n"
       ([ "| Program | Id | Runs on | What it does |"; "|---|---|---|---|" ]
       @ List.map program_row R.all))

let generate ~guide (p : R.t option) (b : Guide_page.block) =
  match (b.name, p) with
  | "programs", _ -> programs ()
  | "backends", Some p -> backends p
  | "checkpoints", Some p -> checkpoints ~guide p b.arg
  | "needs", Some p -> needs ~guide p b.arg
  | "preflight", Some p -> preflight ~guide p b.arg
  | "commands", Some p -> commands ~guide p b.arg
  | ("backends" | "checkpoints" | "needs" | "preflight" | "commands"), None ->
      Error (b.name ^ ": this page is not a program's")
  | name, _ -> Error ("no generated block " ^ name)
