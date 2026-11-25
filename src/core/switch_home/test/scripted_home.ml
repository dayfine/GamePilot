(* A scripted console B for the park and resume tests: each screen's probe
   results come from a capture (fixtures/switch.probes.jsonl), and a reaction
   to each press shows the next screens. One frame per ms. *)

type screen =
  | Game  (** FireRed's load menu *)
  | Home_fire_red_last
      (** HOME, FireRed played last (tile 0) and the cursor on it: synthesized
          from the BDSP-last capture by swapping tiles 0 and 1 *)
  | Home_bdsp_last  (** HOME, BDSP played last, the cursor on it *)
  | Home_on_fire_red  (** HOME, BDSP played last, the cursor on FireRed *)
  | Home_dimmed  (** HOME, dimmed after a while untouched *)
  | Home_scrolled_fire_red_out
      (** HOME scrolled, the cursor on Legends Z-A (tile 1), FireRed out of view
      *)
  | Home_row_start
      (** HOME, the cursor on tile 0, FireRed out of view: synthesized from the
          scrolled capture by swapping cursors 0 and 1 *)
  | Home_scrolled_on_fire_red
      (** HOME scrolled, a part tile at the left, the cursor on FireRed (tile 0)
      *)
  | Home_on_buttons  (** HOME, the cursor on the eShop button below the row *)
  | User_select
  | Black  (** a launch's loading screen: every probe black *)
  | Intro  (** the Game Freak logo *)

let screen_name = function
  | Game -> "game"
  | Home_fire_red_last -> "HOME (FireRed last)"
  | Home_bdsp_last -> "HOME (BDSP last)"
  | Home_on_fire_red -> "HOME (cursor on FireRed)"
  | Home_dimmed -> "HOME (dimmed)"
  | Home_scrolled_fire_red_out -> "HOME (scrolled, FireRed out of view)"
  | Home_row_start -> "HOME (row start, FireRed out of view)"
  | Home_scrolled_on_fire_red -> "HOME (scrolled, cursor on FireRed)"
  | Home_on_buttons -> "HOME (cursor on the buttons)"
  | User_select -> "user select"
  | Black -> "black"
  | Intro -> "intro"

let fixtures = Wire.read_image_probes "switch.probes.jsonl"

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

let black_probes =
  List.map
    (fun (id, r) ->
      match r with
      | Wire.Color_stats _ ->
          let zero : Wire.rgb = { r = 0.; g = 0.; b = 0. } in
          (id, Wire.Color_stats { mean = zero; stddev = zero })
      | other -> (id, other))
    (capture "firered-load-menu")

let scrolled_za = "home-scrolled-cursor-on-legends-za-firered-out-of-view"

let probes = function
  | Game -> capture "firered-load-menu"
  | Home_fire_red_last ->
      swap "home.tile0" "home.tile1" (capture "home-cursor-on-last-played")
  | Home_bdsp_last -> capture "home-cursor-on-last-played"
  | Home_on_fire_red -> capture "home-cursor-on-firered"
  | Home_dimmed -> capture "home-dimmed"
  | Home_scrolled_fire_red_out -> capture scrolled_za
  | Home_row_start -> swap "home.cursor0" "home.cursor1" (capture scrolled_za)
  | Home_scrolled_on_fire_red ->
      capture "home-scrolled-part-tile-left-cursor-on-firered"
  | Home_on_buttons -> capture "home-cursor-on-eshop-button"
  | User_select -> capture "user-select"
  | Black -> black_probes
  | Intro -> capture "launch-game-freak-intro"

type t = {
  mutable clock_ms : int;
  mutable shows : (int * screen) list;  (** latest first *)
  mutable presses : string list;  (** latest first *)
  react : t -> Wire.button -> screen -> unit;
}

let create ~start react =
  { clock_ms = 0; shows = [ (0, start) ]; presses = []; react }

let screen_at t ms = snd (List.find (fun (at, _) -> at <= ms) t.shows)

let show t ~after s =
  let at = t.clock_ms + after in
  t.shows <- List.sort (fun (a, _) (b, _) -> compare b a) ((at, s) :: t.shows)

let frame t : Wire.frame =
  {
    seq = t.clock_ms;
    t_ms = float_of_int t.clock_ms;
    probes = probes (screen_at t t.clock_ms);
  }

let rec run_frames t ms stop =
  if ms <= 0 then None
  else (
    t.clock_ms <- t.clock_ms + 1;
    let f = frame t in
    if stop f then Some f else run_frames t (ms - 1) stop)

let submit t commands : Wire.batch_done =
  List.iter
    (fun (c : Wire.command) ->
      match c with
      | Press { buttons; hold_ms; cooldown_ms; _ } ->
          List.iter
            (fun b ->
              t.presses <- Wire.string_of_button b :: t.presses;
              t.react t b (screen_at t t.clock_ms))
            buttons;
          ignore (run_frames t (hold_ms + cooldown_ms) (fun _ -> false))
      | Wait { wait_ms } -> ignore (run_frames t wait_ms (fun _ -> false)))
    commands;
  { batch_id = "scripted"; seq = t.clock_ms; t_ms = float_of_int t.clock_ms }

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
          | _ -> None);
    }

let presses_text t =
  match List.rev t.presses with [] -> "no press" | l -> String.concat ", " l
