open Plza_readers

type rgb = { r : int; g : int; b : int }

let tile_low = { r = 0; g = 120; b = 120 }
let tile_high = { r = 120; g = 255; b = 255 }

let tile_color : Switch_home.Home_screen.tile_color =
  {
    min = (tile_low.r, tile_low.g, tile_low.b);
    max = (tile_high.r, tile_high.g, tile_high.b);
  }

let probes ~picture ~assets =
  List.concat
    [
      Switch_home.Home_screen.probes ~picture tile_color;
      Story_screen.probes ~picture ~assets;
      Frame_cells.probes ~picture;
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

(* The scene machine's [scene_under_way] (PokemonLZA_AutoStoryScreenPredicates.h):
   text, a box, a battle or a card; else, with no sign of control, a fade or a
   moving screen. *)
let scene_under_way ~still (s : Story_screen.t) =
  if
    s.dialog_box || s.advance_arrow || s.choice_box || s.battle
    || s.tutorial_card
  then true
  else if s.party_bar || s.controls_hint || s.interact_prompt then false
  else s.fade <> No_fade || not still

let look_of ~still (m : Effects.measurements) : Plza_walk.Screen.t =
  let s = Story_screen.read m in
  {
    at_ms = m.t_ms;
    home_menu = home m;
    screen_still = still;
    fade_black = s.fade = Black;
    fade_white = s.fade = White;
    dialog_box = s.dialog_box;
    advance_arrow = s.advance_arrow;
    player_can_move = s.party_bar;
    controls_hint = s.controls_hint;
    interact_prompt = s.interact_prompt;
    scene_under_way = scene_under_way ~still s;
    battle = s.battle;
    minimap_arrow = s.minimap_arrow;
    map_pin =
      Option.map
        (fun ({ x; y } : Map_pin.point) : Plza_walk.Map_leg.point -> { x; y })
        s.map_pin;
  }

let read_screen last () =
  match fresh () with
  | None -> Plza_walk.Screen.empty ~at_ms:(Effects.now ())
  | Some m ->
      let cells = Frame_cells.read m in
      let still =
        match (!last, cells) with
        | Some a, Some b -> Frame_cells.same a b
        | _ -> false
      in
      last := cells;
      look_of ~still m

let game_steps ~log ~log_detail : Plza_walk.Walk.game_steps =
  let last = ref None in
  {
    submit = (fun c -> ignore (Effects.submit [ c ] : Wire.batch_done));
    read_screen = read_screen last;
    log;
    log_detail;
  }
