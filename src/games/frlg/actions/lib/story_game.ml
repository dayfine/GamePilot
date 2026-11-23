open Frlg_overworld

type config = {
  world : Frlg_steps.world;
  gait : Route_legs.gait;
  flee : unit -> unit;
  flags : string -> bool;
  party : Party_roster.t;
  center : string option;
  reload : unit -> (unit, Story.Failure.cause) result;
  log : string -> unit;
}

type t = {
  config : config;
  mutable at : Story.Pose.observed option;
  mutable world : Frlg_steps.world;
  party : Party_roster.t ref;
}

let create config ~start =
  { config; at = start; world = config.world; party = ref config.party }

let party t = !(t.party)
let default_fly_row = 2

let not_implemented what =
  Error (Story.Failure.cause ~repeats:true "not_implemented" what)

let route_from w (at : Story.Pose.observed) target =
  Result.bind (Route_target.place_of w at) (fun from ->
      Route_target.plan w ~from ~facing:at.faces target
      |> Result.map (fun legs -> (from, legs)))

let walker t : Route_walk.t =
  {
    world = t.world;
    gait = t.config.gait;
    flee = t.config.flee;
    log = t.config.log;
  }

let arrived t (ended : Route_walk.at) =
  t.at <- Some (Route_target.observed_of t.world ended.place ended.facing)

let walk_from t (at : Story.Pose.observed) target =
  match route_from t.world at target with
  | Error e -> Error (Story.Failure.cause ~repeats:true "no_route" e)
  | Ok (place, legs) ->
      Result.map (arrived t)
        (Route_walk.walk (walker t) { place; facing = at.faces } legs)

let walk_to t (target : Story.Pose.grid) =
  match t.at with
  | None ->
      Error (Story.Failure.cause "position_unknown" "no position to walk from")
  | Some at -> walk_from t at target

(* After an event that passed: its declared pose, when it names one tile. *)
let adopt_declared t (event : Story.Plan.event) =
  match event.declared_after with
  | Some (Grid { map; tiles = [ tile ]; facing }) ->
      t.at <- Some { at_map = map; at_tile = tile; faces = facing }
  | _ -> ()

let builtin t (event : Story.Plan.event) =
  let log = t.config.log in
  match event.kind with
  | Ready pose -> walk_to t pose
  | Talk -> Talk.talk ~log ()
  | Scene -> Talk.scene ~log ()
  | Heal -> Menu_input.run (Heal_and_save.heal_at_nurse ~log)
  | Save -> Menu_input.run (Heal_and_save.save ~log)
  | _ ->
      not_implemented
        ("event " ^ event.id ^ " of a kind FireRed does not run yet")

let map_now t = Option.map (fun (at : Story.Pose.observed) -> at.at_map) t.at

let regrowing t run =
  let before = map_now t in
  let outcome = run () in
  t.world <- Tree_cut.regrown t.world ~before ~after:(map_now t);
  outcome

let run_builtin t (event : Story.Plan.event) =
  regrowing t (fun () ->
      let outcome = builtin t event in
      if Result.is_ok outcome then adopt_declared t event;
      outcome)

let where = "fly: "

let menu_row args =
  match Grid_maps.Json_field.find "menu_row" args with
  | Some (`Int row) -> row
  | _ -> default_fly_row

let flyer party args =
  match Grid_maps.Json_field.find "slot" args with
  | Some _ -> Ok (Grid_maps.Json_field.int ~where "slot" args)
  | None -> (
      let species = Grid_maps.Json_field.string ~where "species" args in
      match Party_roster.slot_of party species with
      | Some slot -> Ok slot
      | None -> Error (where ^ species ^ " is not in the party"))

let plan_for party town args =
  match flyer party args with
  | exception Grid_maps.Json_field.Invalid e -> Error e
  | Error e -> Error e
  | Ok slot -> Ok { Fly.town; slot; menu_row = menu_row args }

let town_named name =
  Result.bind (Fly_towns.load ()) (fun towns ->
      Option.to_result
        ~none:(name ^ " is no Fly destination")
        (Fly_towns.find towns name))

let fly_plan party args =
  match Grid_maps.Json_field.string ~where "town" args with
  | exception Grid_maps.Json_field.Invalid e -> Error e
  | name -> Result.bind (town_named name) (fun town -> plan_for party town args)

let fly t (_ : Story.Plan.event) args =
  match fly_plan (party t) args with
  | Error e -> Error (Story.Failure.cause ~repeats:true "bad_args" e)
  | Ok plan ->
      let outcome = Fly.fly ~log:t.config.log plan in
      if Result.is_ok outcome then t.at <- Some plan.town.landing;
      outcome

(* The ride leaves the player below the floor's lift door, as Fly does on the
   town's landing tile. *)
let lift t (_ : Story.Plan.event) args =
  Result.bind (Lift_ride.ride_of_args args) (fun ride ->
      let outcome =
        Menu_input.run (fun () -> Lift_ride.ride ~log:t.config.log ride)
      in
      if Result.is_ok outcome then t.at <- Some (Lift_ride.arrival ride);
      outcome)

(* Between loop rounds: to the configured Center's nurse, then the nurse. *)
let heal t () =
  match t.config.center with
  | None -> not_implemented "heal with no Center configured"
  | Some town ->
      let front =
        { Heal_and_save.nurse_front with map = Heal_and_save.center_map town }
      in
      Result.bind (walk_to t front) (fun () ->
          Menu_input.run (Heal_and_save.heal_at_nurse ~log:t.config.log))

let raise_cause = function
  | Ok () -> ()
  | Error cause -> raise (Menu_input.Action_failed cause)

let heal_at t : Grind_plan.heal -> unit =
  let log = t.config.log in
  function
  | Nurse front ->
      raise_cause (walk_to t front);
      Heal_and_save.heal_at_nurse ~log ()
  | Pad pad ->
      raise_cause (walk_to t pad);
      Menu_input.settle_back ~label:"heal pad" ~log

let faced t =
  Option.value
    (Option.bind t.at (fun at -> at.faces))
    ~default:Grid_maps.Direction.North

(* Turning ends facing a way the spin does not report. *)
let find_battle t () =
  Spin_for_encounter.spin ~log:t.config.log ~facing:(faced t)
    ~max_batches:Action_requests.default_spin_batches;
  t.at <- Option.map (fun at -> { at with Story.Pose.faces = None }) t.at

let battle t script =
  let module B = Frlg_battle in
  Effects.with_probes B.Battle_look.probes (fun () ->
      B.Scripted_battle.run ~log:t.config.log
        (B.Screen_driver.make ~read_offered_move:Summary_moves.read_offered ())
        script)

let grind_rig t : Grind.rig =
  let log = t.config.log in
  {
    slot_of = (fun species -> Party_roster.slot_of !(t.party) species);
    known_moves = (fun ~slot -> Summary_moves.read_known ~log ~slot);
    swap =
      (fun a b ->
        Party_actions.swap ~log a b;
        t.party := Party_roster.swap !(t.party) a b);
    go_to = (fun pose -> raise_cause (walk_to t pose));
    heal = heal_at t;
    find_battle = find_battle t;
    battle = battle t;
    log;
  }

let grind t (_ : Story.Plan.event) args =
  match Grind_plan.load_strategies () with
  | Error e -> Error (Story.Failure.cause ~repeats:true "no_grind_strategies" e)
  | Ok strategies ->
      Result.bind (Grind_plan.decode strategies args) (fun plan ->
          Menu_input.run (fun () -> Grind.run (grind_rig t) plan))

(* The catches that went to the party join it; the player faces a way the
   turning does not report. *)
let after_capture t (plan : Capture_plan.t) (result : Capture.result) =
  List.iter
    (fun (d : Capture.destination) ->
      if d = Party then t.party := Party_roster.add !(t.party) plan.species)
    result.caught;
  t.at <- Option.map (fun at -> { at with Story.Pose.faces = None }) t.at

let run_capture t (plan : Capture_plan.t) () =
  let log = t.config.log in
  log ("Capture: " ^ Capture_plan.describe plan ^ ".");
  let rig =
    Capture_steps.make ~log
      ~facing:(fun () -> faced t)
      ~target:plan.species
      ~max_spin_batches:Action_requests.default_spin_batches
  in
  let result =
    Effects.with_probes Frlg_battle.Battle_look.probes (fun () ->
        Capture.run rig plan ~party:(Party_roster.size !(t.party)))
  in
  after_capture t plan result;
  let message = Capture.message plan result in
  log message;
  match result.end_ with
  | All_caught -> ()
  | end_ -> Menu_input.fail ("capture_" ^ Capture.end_name end_) message

let capture t (_ : Story.Plan.event) args =
  Result.bind (Capture_plan.decode args) (fun plan ->
      Menu_input.run (run_capture t plan))

let action_context t : Game_actions.context =
  {
    log = t.config.log;
    party = t.party;
    facing = (fun () -> Option.bind t.at (fun at -> at.faces));
    stocks = Mart_plan.load;
  }

(* A game action that passed leaves the player where its [declared_after]
   says, as the fork's StoryStepRunner takes a step's declared pose when its
   outcome reports none (Engine/Pokemon_StoryStepRunner.cpp). *)
let adopting t (name, (handler : Story.Game.game_action)) =
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
      (Grid_maps.Json_field.direction ~where:"cut_tree: " "direction" args)
  in
  t.world <- world;
  t.at <- Some on_tree

let cutting t (name, (handler : Story.Game.game_action)) =
  let cut event args =
    let before = t.at in
    let outcome = handler event args in
    (match (outcome, before) with
    | Ok (), Some at -> tree_cut t at args
    | _ -> ());
    outcome
  in
  if name = "cut_tree" then (name, cut) else (name, handler)

let game t : Story.Game.t =
  {
    walk_route = (fun _ route -> regrowing t (fun () -> walk_to t route.target));
    run_builtin = run_builtin t;
    game_actions =
      List.map (adopting t)
        (("fly", fly t)
        :: ("grind", grind t)
        :: ("capture", capture t)
        :: ("lift_floor", lift t)
        :: List.map (cutting t) (Game_actions.handlers (action_context t)));
    flag_holds = t.config.flags;
    position = (fun () -> t.at);
    heal = heal t;
    save = (fun () -> Menu_input.run (Heal_and_save.save ~log:t.config.log));
    reload = t.config.reload;
    log = t.config.log;
  }
