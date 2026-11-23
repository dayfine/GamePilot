open Frlg_overworld

type config = {
  world : Frlg_steps.world;
  gait : Route_legs.gait;
  flee : unit -> unit;
  flags : string -> bool;
  log : string -> unit;
}

type t = { config : config; mutable at : Story.Pose.observed option }

let create config ~start = { config; at = start }
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

let plan_for town args =
  match Grid_maps.Json_field.int ~where "slot" args with
  | exception Grid_maps.Json_field.Invalid e -> Error e
  | slot -> Ok { Fly.town; slot; menu_row = menu_row args }

let town_named name =
  Result.bind (Fly_towns.load ()) (fun towns ->
      Option.to_result
        ~none:(name ^ " is no Fly destination")
        (Fly_towns.find towns name))

let fly_plan args =
  match Grid_maps.Json_field.string ~where "town" args with
  | exception Grid_maps.Json_field.Invalid e -> Error e
  | name -> Result.bind (town_named name) (fun town -> plan_for town args)

let fly t (_ : Story.Plan.event) args =
  match fly_plan args with
  | Error e -> Error (Story.Failure.cause ~repeats:true "bad_args" e)
  | Ok plan ->
      let outcome = Fly.fly ~log:t.config.log plan in
      if Result.is_ok outcome then t.at <- Some plan.town.landing;
      outcome

let game t : Story.Game.t =
  {
    walk_route = (fun _ route -> walk_to t route.target);
    run_builtin = run_builtin t;
    game_actions = [ ("fly", fly t) ];
    flag_holds = t.config.flags;
    position = (fun () -> t.at);
    heal = (fun () -> not_implemented "heal");
    save = (fun () -> not_implemented "save");
    reload = (fun () -> not_implemented "reload");
    log = t.config.log;
  }
