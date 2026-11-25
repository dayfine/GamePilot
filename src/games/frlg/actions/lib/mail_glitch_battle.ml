module J = Json_field
module M = Menu_input
module B = Frlg_battle

type plan = {
  knock_off_species : string;
  recycle_species : string;
  sweeper : string;
  depleted_move : string;
  step_direction : Grid_geometry.Direction.t;
}

let decode =
  Action_args.decode ~action:"mail_glitch_double_battle" (fun ~where args ->
      {
        knock_off_species = J.string ~where "knock_off_species" args;
        recycle_species = J.string ~where "recycle_species" args;
        sweeper = J.string ~where "sweeper" args;
        depleted_move = J.string ~where "depleted_move" args;
        step_direction =
          Grid_maps.Grid_field.direction ~where "step_direction" args;
      })

type slots = {
  knock_off : int;
  sand_attack : int;
  surf : int;
  bite : int;
  depleted : int;
  recycle : int;
}

let find_slots ~lead ~holder ~recycler ~depleted_move =
  let slot known move =
    match List.find_index (String.equal move) known with
    | Some i -> i
    | None -> raise (J.Invalid move)
  in
  match
    {
      knock_off = slot lead "knock-off";
      sand_attack = slot lead "sand-attack";
      surf = slot holder "surf";
      bite = slot holder "bite";
      depleted = slot holder depleted_move;
      recycle = slot recycler "recycle";
    }
  with
  | slots -> Ok slots
  | exception J.Invalid move -> Error ("no member knows " ^ move)

let sweep_menus = 20

let move slot target name =
  B.Battle_script.Move { slot; target; name = Some name }

(* The fork's sweep: Surf from the sweeper on the left, Recycle from MIMIEN on
   the right, menu after menu. *)
let sweep s =
  List.init sweep_menus (fun i ->
      if i mod 2 = 0 then move s.surf Default "surf"
      else move s.recycle Default "recycle")

let script s =
  let berry_turn =
    [ move s.sand_attack Foe_left "sand-attack"; move s.bite Foe_left "bite" ]
  in
  let setup =
    [
      move s.knock_off Ally "knock-off";
      Switch 2;
      Switch 2;
      move s.recycle Default "recycle";
    ]
  in
  B.Battle_script.make ~opening:(berry_turn @ setup @ sweep s) Stop

let check_before_first_switch check (game_steps : B.Battle.game_steps) =
  let checked = ref false in
  let switch_to ~slot =
    if not !checked then (
      checked := true;
      if not (check ()) then
        M.fail "double_battle_berry_not_consumed"
          "the depleted move shows no PP after the Berry turn");
    game_steps.switch_to ~slot
  in
  { game_steps with switch_to }

(* The fork's battle taps: D-pad 140 ms held, 260 ms after; A 160 ms. *)
let tap ?(hold_ms = 140) ?(cooldown_ms = 260) buttons =
  let press b = Wire.press ~hold_ms ~cooldown_ms [ b ] in
  ignore (Effects.submit (List.map press buttons) : Wire.batch_done)

let move_menu_timeout_ms = 4000

(* The fork's B back out of the move menu: 160 ms held, 500 ms after. *)
let back_hold_ms = 160
let back_cooldown_ms = 500

let pp_restored ~slot () =
  tap Frlg_battle.Battle_cursor.fight;
  tap (Frlg_battle.Battle_cursor.move ~slot);
  let restored =
    match
      Effects.await ~timeout_ms:move_menu_timeout_ms
        Frlg_readers.Battle_screen.move_menu
    with
    | Effects.Holds m -> not (Frlg_readers.Move_pp.no_pp_left m)
    | Effects.Timeout -> false
  in
  tap ~hold_ms:back_hold_ms ~cooldown_ms:back_cooldown_ms [ Wire.B ];
  restored

let step_tap_ms = 66
let step_release_ms = 700

(* The fork's advance_text() allows the trainers' text 30 s to reach the
   battle. *)
let battle_start_ms = 30_000

let step_into_sight ~log direction =
  tap ~hold_ms:step_tap_ms ~cooldown_ms:step_release_ms [ M.dpad direction ];
  (match Talk.scene ~log () with
  | Ok () -> ()
  | Error _ -> M.fail "double_battle_not_started" "Lea & Jed");
  ignore
    (Effects.with_probes Frlg_battle.Battle_look.probes (fun () ->
         M.await_screen ~timeout_ms:battle_start_ms
           ~code:"double_battle_not_started" "Lea & Jed's battle"
           Frlg_readers.Battle_screen.battle_shows)
      : Effects.measurements)

type game_steps = {
  species_at : int -> string option;
  known_moves : slot:int -> string list;
  start_battle : Grid_geometry.Direction.t -> unit;
  restored : slot:int -> unit -> bool;
  battle :
    (B.Battle.game_steps -> B.Battle.game_steps) ->
    B.Battle_script.t ->
    B.Scripted_battle.outcome;
  after_battle : unit -> unit;
  log : string -> unit;
}

let check_party game_steps plan =
  let want = [ plan.knock_off_species; plan.sweeper; plan.recycle_species ] in
  let ok = List.for_all2 (fun slot s -> game_steps.species_at slot = Some s) in
  if not (ok [ 1; 2; 3 ] want) then
    M.fail "double_battle_wrong_party"
      ("expected " ^ String.concat ", " want ^ " in slots 1-3")

let read_slots game_steps plan =
  let lead = game_steps.known_moves ~slot:1 in
  let holder = game_steps.known_moves ~slot:2 in
  let recycler = game_steps.known_moves ~slot:3 in
  match
    find_slots ~lead ~holder ~recycler ~depleted_move:plan.depleted_move
  with
  | Ok s -> s
  | Error e -> M.fail "double_battle_missing_move" e

let run game_steps plan =
  check_party game_steps plan;
  let s = read_slots game_steps plan in
  game_steps.log "Mail Glitch: starting Lea & Jed's double battle.";
  game_steps.start_battle plan.step_direction;
  let wrap = check_before_first_switch (game_steps.restored ~slot:s.depleted) in
  match game_steps.battle wrap (script s) with
  | B.Scripted_battle.Failed { why; _ } -> M.fail "double_battle_failed" why
  | B.Scripted_battle.Over _ as over ->
      game_steps.log
        ("Mail Glitch: Lea & Jed " ^ B.Scripted_battle.describe over);
      game_steps.after_battle ()

let live_game_steps ~log ~species_at ~known_moves ~battle =
  {
    species_at;
    known_moves;
    start_battle = step_into_sight ~log;
    restored = pp_restored;
    battle;
    after_battle = (fun () -> M.settle_back ~label:"after Lea & Jed" ~log);
    log;
  }
