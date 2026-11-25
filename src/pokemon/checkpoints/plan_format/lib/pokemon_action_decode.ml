open Pokemon_rules
open Pokemon_action
open Engine_plan_format.Plan_fields
module F = Json_field

let target ~where args =
  Pose_decode.grid_pose ~where:(where ^ "target.")
    (object_field ~where "target" args)

let fight_wild ~where args = F.bool_or ~where ~default:false "fight_wild" args

let leg ~where obj : leg =
  known_fields_only ~where [ "direction"; "tiles" ] obj;
  {
    direction = Grid_maps.Grid_field.direction ~where "direction" obj;
    tiles = F.int ~where "tiles" obj;
  }

let item ~where obj : item =
  known_fields_only ~where [ "item"; "quantity" ] obj;
  { item = F.string ~where "item" obj; quantity = F.int ~where "quantity" obj }

let list_of ~where key args read =
  required ~where key args;
  F.records ~where key args read

let route ~where args =
  Route
    {
      target = target ~where args;
      fight_wild = fight_wild ~where args;
      fight_trainers = F.bool_or ~where ~default:false "fight_trainers" args;
    }

let legs ~where args =
  Legs
    {
      legs = list_of ~where "legs" args leg;
      fight_wild = fight_wild ~where args;
    }

let ready ~where args = Ready (target ~where args)

let step ~where args =
  Step (Grid_maps.Grid_field.direction ~where "direction" args)

let battle ~where args =
  Battle { may_lose = F.bool_or ~where ~default:false "may_lose" args }

let train ~where args = Train (F.int ~where "battles" args)
let shop ~where args = Shop (list_of ~where "items" args item)
let no_args kind ~where:_ _ = kind

(* Each kind: its name, the args it takes, and how to read them. *)
let kinds =
  [
    ("new_game", [], no_args New_game);
    ("game_settings", [], no_args Game_settings);
    ("heal", [], no_args Heal);
    ("route", [ "target"; "fight_wild"; "fight_trainers" ], route);
    ("ready", [ "target" ], ready);
    ("legs", [ "legs"; "fight_wild" ], legs);
    ("step", [ "direction" ], step);
    ("battle", [ "may_lose" ], battle);
    ("train", [ "battles" ], train);
    ("shop", [ "items" ], shop);
  ]

(* A kind's decoder: its args checked against the ones it takes, then read. *)
let checked allowed read ~where args =
  known_fields_only ~where allowed args;
  read ~where args

let decoder name =
  List.find_map
    (fun (named, allowed, read) ->
      if named = name then Some (checked allowed read) else None)
    kinds
