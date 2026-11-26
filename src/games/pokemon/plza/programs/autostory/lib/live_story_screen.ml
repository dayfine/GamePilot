open Plza_readers
module L = Plza_story.Look

let probes ~picture ~assets =
  List.concat
    [
      Switch_home.Home_screen.probes ~picture Game_reload.tile_color;
      Story_screen.probes ~picture ~assets;
      Confirm_choices.probes ~picture;
      Frame_cells.probes ~picture;
      Game_loading.probes ~picture;
      Choice_arrow.backup_save_probes ~picture ~assets;
    ]

let fresh_frame_ms = 500

(* A frame newer than now, else the latest one. *)
let fresh () =
  let t0 = Effects.now () in
  match
    Effects.await ~timeout_ms:fresh_frame_ms (fun (m : Effects.measurements) ->
        m.t_ms > t0)
  with
  | Holds m -> Some m
  | Timeout -> Effects.read ()

let home m =
  match Switch_home.Home_screen.read m with
  | Home _ | Home_dimmed | User_select -> true
  | Elsewhere -> false

let effectiveness : Move_symbols.symbol -> L.effectiveness = function
  | No_effect -> No_effect
  | Not_very_effective -> Not_very_effective
  | Effective -> Effective
  | Super_effective -> Super_effective

let look_of ~still (m : Effects.measurements) : L.t =
  let s = Story_screen.read m in
  {
    at_ms = m.t_ms;
    frame_read = true;
    home_menu = home m;
    screen_still = still;
    fade_black = s.fade = Black;
    fade_white = s.fade = White;
    dialog_box = s.dialog_box;
    choice_box = s.choice_box;
    choice_rows =
      Option.map
        (fun (r : Choice_rows.t) -> (r.selected, r.count))
        s.choice_rows;
    advance_arrow = s.advance_arrow;
    controls_hint = s.controls_hint;
    autosave = s.autosave;
    tutorial_card = s.tutorial_card;
    interact_prompt = s.interact_prompt;
    party_bar = s.party_bar;
    minimap = s.minimap;
    map_pin =
      Option.map
        (fun ({ x; y } : Map_pin.point) : L.map_point -> { x; y })
        s.map_pin;
    minimap_arrow = s.minimap_arrow;
    run_prompt = s.run_prompt;
    main_menu = s.main_menu;
    alert_eye = s.alert_eye;
    battle = s.battle;
    lead_hp = s.lead_hp;
    story_dialog = s.story_dialog;
    moves = List.map (Option.map effectiveness) s.moves;
    confirm_row = Confirm_choices.read m;
  }

let read_screen last () =
  match fresh () with
  | None -> L.no_frame ~at_ms:(Effects.now ())
  | Some m ->
      let cells = Frame_cells.read m in
      let still =
        match (!last, cells) with
        | Some a, Some b -> Frame_cells.same a b
        | _ -> false
      in
      last := cells;
      look_of ~still m

let look_of_frame m = look_of ~still:false m

let raced = function
  | Effects.Stopped m -> Some (look_of_frame m)
  | Finished _ -> None

let race c check =
  raced (Effects.race [ c ] ~stop:(fun m -> check (look_of_frame m)))

let race_batch cs check =
  raced (Effects.race cs ~stop:(fun m -> check (look_of_frame m)))

let race_then c check next =
  raced
    (Effects.race_then [ c ]
       ~stop:(fun m -> check (look_of_frame m))
       ~then_:(fun m -> next (look_of_frame m)))

(* The second frame of a party count: the bars' tests made from the first
   frame's cards, subscribed for one read. *)
let count_bars ~picture ~sent_out cards =
  Effects.with_probes (Party_slots.bar_probes ~picture cards) (fun () ->
      Option.bind (fresh ()) (fun m ->
          Option.map (Party_slots.filled ~sent_out) (Party_slots.bars m)))

(* The caught mark over [bar], on the next frame. *)
let caught_mark ~picture bar =
  Effects.with_probes (Lock_plate.mark_probes ~picture bar) (fun () ->
      Option.bind (fresh ()) (fun m -> Lock_plate.caught m bar))

let target_of ~picture bar : Plza_story.Catch_plan.target =
  let x, y = Lock_plate.centre bar in
  { x; y; caught = caught_mark ~picture bar }

(* The plate's bar on one frame, the caught mark over it on the next. *)
let read_lock_target ~picture () =
  Option.map (target_of ~picture) (Option.bind (fresh ()) Lock_plate.bar)

(* No input until the clock reaches [at]; the queued inputs run on. *)
let wait_until at =
  let left = int_of_float (Float.ceil (at -. Effects.now ())) in
  if left > 0 then
    ignore
      (Effects.await ~timeout_ms:(left + fresh_frame_ms)
         (fun (m : Effects.measurements) -> m.t_ms >= at)
        : Effects.awaited)

let read_party_slots ~picture () =
  let count m =
    match Party_slots.cards m with
    | Some cards when Party_bar.shown m ->
        count_bars ~picture ~sent_out:(Party_marker.down_slot m) cards
    | Some _ | None -> None
  in
  match Option.bind (fresh ()) count with
  | Some n when n > 0 -> Some n
  | Some _ | None -> None

let game_steps ~picture ~log ~log_detail : Plza_story.Steps.game_steps =
  let last = ref None in
  {
    submit = (fun c -> ignore (Effects.submit [ c ] : Wire.batch_done));
    submit_batch = (fun cs -> ignore (Effects.submit cs : Wire.batch_done));
    read_screen = read_screen last;
    race;
    race_batch;
    race_then;
    queue = Effects.queue;
    now = Effects.now;
    wait_until;
    read_lock_target = read_lock_target ~picture;
    read_party_slots = read_party_slots ~picture;
    log;
    log_detail;
  }
