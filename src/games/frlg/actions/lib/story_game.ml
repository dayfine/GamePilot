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
  party : Party_roster.t ref;
}

let create config ~start = { config; at = start; party = ref config.party }
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
    world = t.config.world;
    gait = t.config.gait;
    flee = t.config.flee;
    log = t.config.log;
  }

let arrived t (ended : Route_walk.at) =
  t.at <-
    Some (Route_target.observed_of t.config.world ended.place ended.facing)

let walk_from t (at : Story.Pose.observed) target =
  match route_from t.config.world at target with
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

let run_builtin t (event : Story.Plan.event) =
  let outcome = builtin t event in
  if Result.is_ok outcome then adopt_declared t event;
  outcome

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

let action_context t : Game_actions.context =
  {
    log = t.config.log;
    party = t.party;
    facing = (fun () -> Option.bind t.at (fun at -> at.faces));
    stocks = Mart_plan.load;
  }

let game t : Story.Game.t =
  {
    walk_route = (fun _ route -> walk_to t route.target);
    run_builtin = run_builtin t;
    game_actions = ("fly", fly t) :: Game_actions.handlers (action_context t);
    flag_holds = t.config.flags;
    position = (fun () -> t.at);
    heal = heal t;
    save = (fun () -> Menu_input.run (Heal_and_save.save ~log:t.config.log));
    reload = t.config.reload;
    log = t.config.log;
  }
