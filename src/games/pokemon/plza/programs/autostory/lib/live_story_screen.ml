open Plza_readers
module L = Plza_story.Story_look

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
    battle = s.battle;
    story_dialog = s.story_dialog;
    moves = List.map (Option.map effectiveness) s.moves;
    confirm_row = Confirm_choices.read m;
  }

let read_screen last () =
  match fresh () with
  | None -> L.empty ~at_ms:(Effects.now ())
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

let race_then c check next =
  raced
    (Effects.race_then [ c ]
       ~stop:(fun m -> check (look_of_frame m))
       ~then_:(fun m -> next (look_of_frame m)))

let game_steps ~picture:_ ~log ~log_detail : Plza_story.Story_steps.game_steps =
  let last = ref None in
  {
    submit = (fun c -> ignore (Effects.submit [ c ] : Wire.batch_done));
    submit_batch = (fun cs -> ignore (Effects.submit cs : Wire.batch_done));
    read_screen = read_screen last;
    race;
    race_then;
    log;
    log_detail;
  }
