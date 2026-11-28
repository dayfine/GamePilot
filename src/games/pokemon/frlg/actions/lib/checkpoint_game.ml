open Frlg_overworld
module Failure = Pokemon_engine.Failure

type config = {
  world : Frlg_steps.world;
  gait : Route_legs.gait;
  flee : unit -> unit;
  flags : string -> bool;
  party : Party_roster.t option;
  grind_cap : int option;
  center : Pokemon_engine.Pose.grid option;
  reload : unit -> (unit, Failure.cause) result;
  program_options : Run_options.t;
  default_frame_model : string;
  rng_reset_mode : Rng_reset.mode;
  log : string -> unit;
}

type t = {
  config : config;
  mutable at : Pokemon_engine.Pose.observed option;
  mutable world : Frlg_steps.world;
  party : Party_roster.t ref;
  reading : Party_reading.t;
}

let create config ~start =
  let reading = Party_reading.create ~log:config.log config.party in
  {
    config;
    at = start;
    world = config.world;
    party = Party_reading.roster reading;
    reading;
  }

let party t = !(t.party)

let not_implemented what =
  Error (Failure.cause ~repeats:true "not_implemented" what)

let route_from w (at : Pokemon_engine.Pose.observed) target =
  Result.bind (Route_target.place_of w at) (fun from ->
      Route_target.plan w ~from ~facing:at.faces target
      |> Result.map (fun legs -> (from, legs)))

let known_moves_count = 4

let read_forget_list () : Frlg_battle.Level_up.forget_list =
  {
    offered = Summary_moves.read_offered ();
    known = List.init known_moves_count Summary_moves.read_row;
  }

let battle_game_steps ~log () =
  Frlg_battle.Battle_steps.make ~log ~read_forget_list
    ~is_switch_offer:Switch_offer.read ()

let battle_on t wrap script =
  Effects.with_probes Frlg_battle.Battle_look.probes (fun () ->
      Frlg_battle.Scripted_battle.run ~log:t.config.log
        (wrap (battle_game_steps ~log:t.config.log ()))
        script)

let battle t script = battle_on t Fun.id script

let walker ?(watch_trainers = false) t : Route_walk.t =
  {
    world = t.world;
    gait = t.config.gait;
    flee = t.config.flee;
    fight_trainer =
      (fun () ->
        Trainer_battles.play ~log:t.config.log ~fight:(battle t) ~battles:1);
    watch_trainers;
    log = t.config.log;
  }

let arrived t (ended : Route_walk.at) =
  t.at <- Some (Route_target.observed_of t.world ended.place ended.facing)

let walk_from ?watch_trainers t (at : Pokemon_engine.Pose.observed) target =
  match route_from t.world at target with
  | Error e -> Error (Failure.cause ~repeats:true "no_route" e)
  | Ok (place, legs) ->
      Result.map (arrived t)
        (Route_walk.walk (walker ?watch_trainers t)
           { place; facing = at.faces }
           legs)

let no_position = Failure.cause "position_unknown" "no position to walk from"

let walk_to ?watch_trainers t (target : Pokemon_engine.Pose.grid) =
  match t.at with
  | None -> Error no_position
  | Some at -> walk_from ?watch_trainers t at target

(* After an event that passed: its declared pose, when it names one tile. A
   pose with no facing on the tile already reckoned keeps the facing reckoned
   (a Fly's landing faces south). *)
let adopt_declared t (event : Pokemon_engine.Plan.event) =
  let kept map tile =
    match t.at with
    | Some at when at.at_map = map && at.at_tile = tile -> at.faces
    | _ -> None
  in
  match event.declared_after with
  | Some (Grid { map; tiles = [ tile ]; facing }) ->
      let faces = if facing = None then kept map tile else facing in
      t.at <- Some { at_map = map; at_tile = tile; faces }
  | _ -> ()

let builtin t (event : Pokemon_engine.Plan.event) =
  let log = t.config.log in
  match event.kind with
  | Game (Ready pose) -> walk_to t pose
  | Talk -> Talk.talk ~log ()
  | Answer yes -> Talk.answer ~log ~yes ()
  | Scene -> Talk.scene ~log ()
  | Game Heal -> Menu_input.run (Heal_and_save.heal_at_nurse ~log)
  | Save -> Menu_input.run (Heal_and_save.save ~log)
  | _ ->
      not_implemented
        ("event " ^ event.id ^ " of a kind FireRed does not run yet")

let map_now t = Option.map (fun at -> at.Pokemon_engine.Pose.at_map) t.at

let regrowing t run =
  let before = map_now t in
  let outcome = run () in
  t.world <- Tree_cut.regrown t.world ~before ~after:(map_now t);
  outcome

let run_builtin t (event : Pokemon_engine.Plan.event) =
  regrowing t (fun () ->
      let outcome = builtin t event in
      if Result.is_ok outcome then adopt_declared t event;
      outcome)

let lands t at outcome =
  if Result.is_ok outcome then t.at <- Some at;
  outcome

(* The plan's slot, else the first member that knows Fly, read. *)
let fly_user t (request : Fly_args.request) =
  match request.user with
  | Some user -> Ok user
  | None -> Fly_user.read ~log:t.config.log

let fly t (_ : Pokemon_engine.Plan.event) args =
  match Fly_args.decode args with
  | Error e -> Error (Failure.cause ~repeats:true "bad_args" e)
  | Ok request ->
      Result.bind (fly_user t request) (fun user ->
          let plan = Fly_args.plan request user in
          Fly.fly ~log:t.config.log plan |> lands t plan.town.landing)

let lift t (_ : Pokemon_engine.Plan.event) args =
  Result.bind (Lift_ride.ride_of_args args) (fun ride ->
      Menu_input.run (fun () -> Lift_ride.ride ~log:t.config.log ride)
      |> lands t (Lift_ride.arrival ride))

(* Between loop rounds: to the configured Center's nurse, then the nurse. *)
let heal t () =
  match t.config.center with
  | None -> not_implemented "heal with no Center configured"
  | Some nurse ->
      Result.bind (walk_to t nurse) (fun () ->
          Menu_input.run (Heal_and_save.heal_at_nurse ~log:t.config.log))

let find_battle t ~pace ~patch () =
  Paced_battle.find ~log:t.config.log ~pace ~patch
    ~stands:(fun at -> t.at <- Some at)
    (Paced_battle.reckoned t.at)

let grind_game_steps t (plan : Grind_plan.t) =
  (* Grind_plan reads one *)
  let patch = List.hd plan.strategy.spot.tiles in
  let find_battle = find_battle t ~pace:plan.strategy.pace ~patch in
  Grind_steps.make ~log:t.config.log ~party:t.party ~walk_to:(walk_to t)
    ~find_battle ~battle:(battle t)

let run_grind t ?cap plan () = Grind.run ?cap (grind_game_steps t plan) plan

let grind t (_ : Pokemon_engine.Plan.event) args =
  let cap = t.config.grind_cap in
  match Grind_plan.load_strategies () with
  | Error e -> Error (Failure.cause ~repeats:true "no_grind_strategies" e)
  | Ok strategies ->
      Result.bind (Grind_plan.decode strategies args) (fun plan ->
          let plan = Grind_plan.apply_options t.config.program_options plan in
          Menu_input.run (run_grind t ?cap plan))

(* The catches that went to the party join it; the player stands where the
   pacing left them: the patch's tile, or one tile [pace] from it. *)
let after_capture t (plan : Capture_plan.t) (spot : Pacing.spot) result =
  t.party := Capture.party_after !(t.party) result;
  let stands (at : Pokemon_engine.Pose.observed) =
    let at_tile = Pacing.stands_on ~pace:plan.pace spot at.at_tile in
    { at with at_tile; faces = spot.facing }
  in
  t.at <- Option.map stands t.at

let run_capture t (plan : Capture_plan.t) () =
  let log = t.config.log in
  log ("Capture: " ^ Capture_plan.describe plan ^ ".");
  let spot = ref (Pacing.on_patch (Option.bind t.at (fun at -> at.faces))) in
  let game_steps = Capture_steps.make ~log ~spot plan in
  let result =
    Effects.with_probes Frlg_battle.Battle_look.probes (fun () ->
        Capture.run game_steps plan ~party:(Party_roster.size !(t.party)))
  in
  after_capture t plan !spot result;
  let message = Capture.message plan result in
  log message;
  match result.end_ with
  | All_caught -> ()
  | end_ -> Menu_input.fail ("capture_" ^ Capture.end_name end_) message

let capture t (_ : Pokemon_engine.Plan.event) args =
  Result.bind (Capture_plan.decode args) (fun plan ->
      let plan = Capture_plan.apply_options t.config.program_options plan in
      Menu_input.run (run_capture t plan))

(* The wild RNG catch ({!Wild_rng}): the target searched for, then either the
   legacy throw-only capture or optional visual shiny detection + policy catch
   ({!Battle_catch_steps}), and finally the summary's star. *)
let run_wild_rng t (plan : Wild_rng_plan.t) () =
  let log = t.config.log in
  let target =
    match Wild_rng_plan.target plan with
    | Ok target -> target
    | Error e -> Menu_input.fail "wild_rng_no_target" e
  in
  let game_steps =
    Wild_rng_steps.live_calibrated_game_steps ~log
      ~reset_mode:t.config.rng_reset_mode plan target
  in
  let r =
    Wild_rng.run game_steps plan.capture ~party:(Party_roster.size !(t.party))
  in
  Option.iter (fun c -> t.party := Capture.party_after !(t.party) c) r.capture;
  log (Wild_rng.message r);
  Option.iter
    (fun code -> Menu_input.fail code (Wild_rng.message r))
    (Wild_rng.failure_code r.end_)

let apply_switch_calibration ~frame_model ~apply plan =
  if frame_model <> "switch" then Ok plan
  else
    Frlg_rng.Switch_rng_calibration.load_console ()
    |> Result.map_error (Failure.cause ~repeats:true "bad_args")
    |> Result.map (function Some entry -> apply entry plan | None -> plan)

let load_wild_rng_fallback options =
  match (Run_options.int options "tid", Run_options.int options "sid") with
  | Some _, Some _ -> Ok Wild_rng_plan.no_trainer_ids
  | _ ->
      Wild_rng_plan.load_trainer_ids ()
      |> Result.map_error (Failure.cause ~repeats:true "bad_args")

let wild_rng t (_ : Pokemon_engine.Plan.event) args =
  let ( let* ) = Result.bind in
  let options = t.config.program_options in
  let default_frame_model = t.config.default_frame_model in
  let* fallback = load_wild_rng_fallback options in
  let* plan =
    Wild_rng_plan.decode ~options ~fallback ~default_frame_model args
  in
  let* plan =
    apply_switch_calibration ~frame_model:plan.frame_model
      ~apply:Wild_rng_plan.apply_calibration plan
  in
  Menu_input.run (run_wild_rng t plan)

let run_gift_rng t (plan : Gift_rng.plan) () =
  let log = t.config.log in
  let target =
    match Gift_rng.target plan with
    | Ok target -> target
    | Error e -> Menu_input.fail "gift_rng_no_target" e
  in
  let steps =
    Gift_rng.live_calibrated_game_steps ~log ~reset_mode:t.config.rng_reset_mode
      plan target
  in
  let r =
    Gift_rng.run steps ~attempts:plan.attempts
      ~party:(Party_roster.size !(t.party))
  in
  if r.end_ = Gift_rng.Shiny then
    t.party := Party_roster.add !(t.party) plan.species;
  log (Gift_rng.message r);
  Option.iter
    (fun code -> Menu_input.fail code (Gift_rng.message r))
    (Gift_rng.failure_code r.end_)

let gift_rng t (_ : Pokemon_engine.Plan.event) args =
  let ( let* ) = Result.bind in
  let options = t.config.program_options in
  let default_frame_model = t.config.default_frame_model in
  let* fallback = load_wild_rng_fallback options in
  let* plan = Gift_rng.decode ~options ~fallback ~default_frame_model args in
  let* plan =
    apply_switch_calibration ~frame_model:plan.frame_model
      ~apply:Gift_rng.apply_calibration plan
  in
  Menu_input.run (run_gift_rng t plan)

let run_static_rng t (plan : Static_rng.plan) () =
  let log = t.config.log in
  let target =
    match Static_rng.target plan with
    | Ok target -> target
    | Error e -> Menu_input.fail "static_rng_no_target" e
  in
  let steps =
    Static_rng.live_calibrated_game_steps ~log
      ~reset_mode:t.config.rng_reset_mode plan target
  in
  let r =
    Static_rng.run steps ~attempts:plan.attempts plan.capture
      ~party:(Party_roster.size !(t.party))
  in
  Option.iter (fun c -> t.party := Capture.party_after !(t.party) c) r.capture;
  log (Static_rng.message r);
  Option.iter
    (fun code -> Menu_input.fail code (Static_rng.message r))
    (Static_rng.failure_code r.end_)

let static_rng t (_ : Pokemon_engine.Plan.event) args =
  let ( let* ) = Result.bind in
  let options = t.config.program_options in
  let default_frame_model = t.config.default_frame_model in
  let* fallback = load_wild_rng_fallback options in
  let* plan = Static_rng.decode ~options ~fallback ~default_frame_model args in
  let* plan =
    apply_switch_calibration ~frame_model:plan.frame_model
      ~apply:Static_rng.apply_calibration plan
  in
  Menu_input.run (run_static_rng t plan)

(* The game saved from the Start menu, as between loop rounds: what a hard
   reset ({!Effects.reset}) boots from. *)
let save_game t (_ : Pokemon_engine.Plan.event) (_ : Json_field.obj) =
  Game_save.save_game ~log:t.config.log ()

let known_moves t ~slot = Summary_moves.read_known ~log:t.config.log ~slot
let species_at t slot = List.nth_opt (Party_roster.to_list !(t.party)) (slot - 1)

(* The battles paced for from the tile the action starts on, and the player
   back on it afterwards, facing [pace] (mg-05a declares it so). *)
let run_berry_pp t (plan : Berry_pp.plan) () =
  let start = Paced_battle.reckoned t.at in
  let game_steps : Berry_pp.game_steps =
    {
      lead = (fun () -> species_at t 1);
      known_moves = known_moves t;
      find_battle = find_battle t ~pace:plan.pace ~patch:start.at_tile;
      battle = battle t;
      log = t.config.log;
    }
  in
  Berry_pp.run game_steps plan;
  Menu_input.raise_error
    (walk_to t (Paced_battle.back_on_patch ~pace:plan.pace start))

let prepare_berry_pp t (_ : Pokemon_engine.Plan.event) args =
  Result.bind (Berry_pp.decode args) (fun plan ->
      let plan = Berry_pp.apply_options t.config.program_options plan in
      Menu_input.run (run_berry_pp t plan))

let double_battle t (_ : Pokemon_engine.Plan.event) args =
  let game_steps =
    Mail_glitch_battle.live_game_steps ~log:t.config.log
      ~species_at:(species_at t) ~known_moves:(known_moves t)
      ~battle:(battle_on t)
  in
  Result.bind (Mail_glitch_battle.decode args) (fun plan ->
      let plan =
        Mail_glitch_battle.apply_options t.config.program_options plan
      in
      Menu_input.run (fun () -> Mail_glitch_battle.run game_steps plan))

let action_context t : Game_actions.context =
  {
    log = t.config.log;
    party = t.party;
    facing = (fun () -> Option.bind t.at (fun at -> at.faces));
    stocks = Mart_plan.load;
    options = t.config.program_options;
  }

(* A game action that passed leaves the player where its [declared_after]
   says, as the fork's StoryStepRunner takes a step's declared pose when its
   outcome reports none (Engine/Pokemon_StoryStepRunner.cpp). *)
let adopting t (name, (handler : Pokemon_engine.Game.game_action)) =
  let adopted event args =
    regrowing t (fun () ->
        let outcome = handler event args in
        if Result.is_ok outcome then adopt_declared t event;
        outcome)
  in
  (name, adopted)

(* The fork's tree_cut, after its cut_tree event passed. *)
let tree_cut t at args =
  let world, on_tree =
    Tree_cut.cut t.world at
      (Grid_maps.Grid_field.direction ~where:"cut_tree: " "direction" args)
  in
  t.world <- world;
  t.at <- Some on_tree

let cutting t (name, (handler : Pokemon_engine.Game.game_action)) =
  let cut event args =
    let before = t.at in
    let outcome = handler event args in
    (match (outcome, before) with
    | Ok (), Some at -> tree_cut t at args
    | _ -> ());
    outcome
  in
  if name = "cut_tree" then (name, cut) else (name, handler)

let ferry t (_ : Pokemon_engine.Plan.event) args =
  Seagallop.run ~log:t.config.log ~from:(map_now t) args
  |> Result.map (fun at -> t.at <- Some at)

let declared t event = Result.map (fun () -> adopt_declared t event)

(* The plan's [step] (Route_walk.step), [train] (Trainer_battles) and
   [battle] (Scene_battle). *)
let step_from t (at : Pokemon_engine.Pose.observed) direction =
  match Route_target.place_of t.world at with
  | Error e -> Error (Failure.cause ~repeats:true "no_route" e)
  | Ok place ->
      Route_walk.step (walker t) { place; facing = at.faces } direction

let step t event direction =
  Result.bind (Option.to_result ~none:no_position t.at) (fun at ->
      step_from t at direction)
  |> Result.map (arrived t)
  |> declared t event

let train t event battles =
  declared t event
    (Trainer_battles.play ~log:t.config.log ~fight:(battle t) ~battles)

let story_battle t event may_lose =
  declared t event
    (Scene_battle.play ~log:t.config.log ~fight:(battle t) ~may_lose)

let run_own t event : Pokemon_engine.Pokemon_action.t -> _ = function
  | Route route ->
      regrowing t (fun () ->
          walk_to ~watch_trainers:route.fight_trainers t route.target)
  | Step direction -> step t event direction
  | Train battles -> train t event battles
  | Battle { may_lose } -> story_battle t event may_lose
  | _ -> run_builtin t event

let game t : Pokemon_engine.Game.t =
  {
    run_own = run_own t;
    run_builtin = run_builtin t;
    game_actions =
      List.map
        (fun a -> Party_reading.guard t.reading (adopting t a))
        (("fly", fly t)
        :: ("ferry", ferry t)
        :: ("grind", grind t)
        :: ("capture", capture t)
        :: ("wild_rng", wild_rng t)
        :: ("gift_rng", gift_rng t)
        :: ("static_rng", static_rng t)
        :: ("save_game", save_game t)
        :: ("lift_floor", lift t)
        :: ("prepare_berry_pp", prepare_berry_pp t)
        :: ("mail_glitch_double_battle", double_battle t)
        :: List.map (cutting t) (Game_actions.handlers (action_context t)));
    flag_holds = t.config.flags;
    position = (fun () -> t.at);
    between_rounds = heal t;
    save = (fun () -> Menu_input.run (Heal_and_save.save ~log:t.config.log));
    reload = t.config.reload;
    log = t.config.log;
  }
