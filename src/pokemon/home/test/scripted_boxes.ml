(* A scripted Pokémon HOME box screen for Box_moves' tests: each screen's probe
   results come from a capture (fixtures/home.probes.jsonl), its cursor
   probes' results swapped to put the cursor elsewhere, and a reaction to
   each press shows the next screen. One frame per ms. A trimmed copy of
   core/switch_home/test/scripted_home.ml's player. *)

type screen =
  | Before  (** box 152, the game's row full, the cursor on HOME's first slot *)
  | Before_on_game of int
      (** the same, the cursor on the game's slot in that column *)
  | After  (** box 152 banked: HOME's slot (4, 4) filled, the game's emptied *)
  | After_home_first  (** the same, the cursor back on HOME's first slot *)

let fixtures = Wire.read_image_probes "home.probes.jsonl"

let capture name =
  match List.assoc_opt ("./" ^ name ^ ".png") fixtures with
  | Some probes -> probes
  | None -> failwith ("no fixture for " ^ name)

let swap a b probes =
  List.map
    (fun (id, r) ->
      if id = a then (id, List.assoc b probes)
      else if id = b then (id, List.assoc a probes)
      else (id, r))
    probes

let home_first = "home.cursor.home.0.0"
let game col = Printf.sprintf "home.cursor.game.0.%d" col

let probes = function
  | Before -> capture "boxes-152-before-bank-cursor-0-0"
  | Before_on_game col ->
      swap home_first (game col) (capture "boxes-152-before-bank-cursor-0-0")
  | After -> capture "boxes-152-after-bank"
  | After_home_first ->
      swap home_first "home.cursor.home.3.5" (capture "boxes-152-after-bank")

let screen_name = function
  | Before -> "before"
  | Before_on_game col -> Printf.sprintf "before, cursor on game slot %d" col
  | After -> "after"
  | After_home_first -> "after, cursor on HOME's first slot"

type t = {
  mutable clock_ms : int;
  mutable screen : screen;
  mutable presses : string list;
  react : t -> Wire.button -> unit;
}

let frame t : Wire.frame =
  { seq = t.clock_ms; t_ms = float_of_int t.clock_ms; probes = probes t.screen }

let rec run_frames t ms pred =
  if ms <= 0 then None
  else (
    t.clock_ms <- t.clock_ms + 1;
    let f = frame t in
    if pred f then Some f else run_frames t (ms - 1) pred)

let submit t commands =
  List.iter
    (fun (c : Wire.command) ->
      match c with
      | Press { buttons; hold_ms; cooldown_ms; _ } ->
          List.iter
            (fun b ->
              t.presses <- Wire.string_of_button b :: t.presses;
              t.react t b)
            buttons;
          ignore (run_frames t (hold_ms + cooldown_ms) (fun _ -> false))
      | Wait { wait_ms } -> ignore (run_frames t wait_ms (fun _ -> false)))
    commands;
  ({ batch_id = "scripted"; seq = t.clock_ms; t_ms = float_of_int t.clock_ms }
    : Wire.batch_done)

let await t pred timeout_ms : Effects.awaited =
  let now = frame t in
  if pred now then Holds now
  else
    match run_frames t timeout_ms pred with
    | Some f -> Holds f
    | None -> Timeout

let run t f =
  let open Effect.Deep in
  try_with f ()
    {
      effc =
        (fun (type a) (eff : a Effect.t) ->
          let answer (v : unit -> a) =
            Some (fun (k : (a, _) continuation) -> continue k (v ()))
          in
          match eff with
          | Effects.Submit commands -> answer (fun () -> submit t commands)
          | Effects.Await (pred, timeout_ms) ->
              answer (fun () -> await t pred timeout_ms)
          | Effects.Now -> answer (fun () -> float_of_int t.clock_ms)
          | Effects.Read -> answer (fun () -> Some (frame t))
          | Effects.Subscribe probes ->
              answer (fun () ->
                  List.map (fun (p : Wire.probe_spec) -> p.id) probes)
          | Effects.Unsubscribe ids -> answer (fun () -> ids)
          | Effects.Show_log _ -> answer (fun () -> ())
          | _ -> None);
    }

(* The presses, a run of one button counted ("Right x6"). *)
let counted presses =
  let rec runs acc = function
    | [] -> List.rev acc
    | b :: rest -> (
        match acc with
        | (b', n) :: acc' when b = b' -> runs ((b, n + 1) :: acc') rest
        | _ -> runs ((b, 1) :: acc) rest)
  in
  match runs [] (List.rev presses) with
  | [] -> "no press"
  | l ->
      String.concat ", "
        (List.map
           (fun (b, n) -> if n = 1 then b else Printf.sprintf "%s x%d" b n)
           l)

let play ~start react body =
  let t = { clock_ms = 0; screen = start; presses = []; react } in
  let outcome = run t body in
  Printf.sprintf "%s; %s; ends on %s" outcome (counted t.presses)
    (screen_name t.screen)
