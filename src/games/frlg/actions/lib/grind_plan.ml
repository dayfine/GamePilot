module J = Json_field
module B = Frlg_battle

type lead = Switch_to_sweeper

type heal =
  | Nurse of Pokemon_checkpoints.Pose.grid
  | Pad of Pokemon_checkpoints.Pose.grid

type strategy = {
  name : string;
  spot : Pokemon_checkpoints.Pose.grid;
  pace : Grid_maps.Direction.t;
  lead : lead;
  heal : heal;
  heal_every : int;
}

type goal = {
  species : string;
  target_level : int;
  learn_move : string;
  learn_slot : int;
}

type t = {
  goal : goal;
  strategy : strategy;
  sweeper : string;
  sweeper_moves : int list;
  max_battles : int;
  round : bool;
}

let default_strategy = "victory_road_2f"
let asset = "src/games/frlg/assets/grind_strategies.json"

let tile ~where obj : Grid_maps.Tile_pos.t =
  match J.field ~where "tile" obj with
  | `List [ `Int x; `Int y ] -> { x; y }
  | _ -> J.fail "%stile is not [x, y]." where

let pose ~where key obj : Pokemon_checkpoints.Pose.grid =
  let p = J.as_object (where ^ key ^ ": ") (J.field ~where key obj) in
  let where = where ^ key ^ "." in
  {
    map = J.string ~where "map" p;
    tiles = [ tile ~where p ];
    facing = Some (Grid_maps.Grid_field.direction ~where "facing" p);
  }

let lead ~where obj =
  match J.string ~where "lead" obj with
  | "switch" -> Switch_to_sweeper
  | "solo_when_sure" ->
      J.fail
        "%slead solo_when_sure needs a foe species reader and the grinder's \
         level, which FireRed lacks."
        where
  | other -> J.fail "%slead %s is not switch." where other

let heal ~where obj =
  let h = J.as_object (where ^ "heal: ") (J.field ~where "heal" obj) in
  let where = where ^ "heal." in
  if J.has "nurse" h then Nurse (pose ~where "nurse" h)
  else if J.has "pad" h then Pad (pose ~where "pad" h)
  else J.fail "%s needs nurse or pad." where

let strategy i json =
  let where = J.item_where "grind_strategies.json: " "strategies" i in
  let obj = J.as_object where json in
  {
    name = J.string ~where "name" obj;
    spot = pose ~where "spot" obj;
    pace = Grid_maps.Grid_field.direction ~where "pace" obj;
    lead = lead ~where obj;
    heal = heal ~where obj;
    heal_every = J.int ~where "heal_every" obj;
  }

let strategies_of_json json =
  let where = "grind_strategies.json: " in
  match
    let obj = J.as_object where json in
    List.mapi strategy
      (Option.value (J.list_opt ~where "strategies" obj) ~default:[])
  with
  | list -> Ok list
  | exception J.Invalid e -> Error e

let read () =
  match Repo_io.Repo_files.locate asset with
  | None -> Error (asset ^ " not found from the working directory")
  | Some path -> (
      match Yojson.Safe.from_file path with
      | json -> strategies_of_json json
      | exception Yojson.Json_error e -> Error (path ^ ": " ^ e))

let table = lazy (read ())
let load_strategies () = Lazy.force table
let where = "grind: "
let move_slots = 4

let move_slot key obj =
  let n = J.int ~where key obj in
  if n < 1 || n > move_slots then
    J.fail "%s%s is %d, not a move slot (1-4)." where key n
  else n - 1

let move_slot_list obj =
  match J.list_opt ~where "sweeper_moves" obj with
  | Some (_ :: _ as l) ->
      List.map
        (function
          | `Int n when n >= 1 && n <= move_slots -> n - 1
          | _ -> J.fail "%ssweeper_moves holds a non move slot." where)
        l
  | _ -> J.fail "%ssweeper_moves must list move slots (1-4)." where

let named strategies obj =
  let name =
    Option.value (J.string_opt ~where "strategy" obj) ~default:default_strategy
  in
  match List.find_opt (fun s -> s.name = name) strategies with
  | Some s -> s
  | None -> J.fail "%sstrategy %s is not in grind_strategies.json." where name

let goal obj =
  {
    species = J.string ~where "species" obj;
    target_level = J.int ~where "target_level" obj;
    learn_move = J.string ~where "learn_move" obj;
    learn_slot = move_slot "learn_slot" obj;
  }

let decode strategies obj =
  match
    {
      goal = goal obj;
      strategy = named strategies obj;
      sweeper = J.string ~where "sweeper" obj;
      sweeper_moves = move_slot_list obj;
      max_battles = J.int ~where "max_battles" obj;
      round = J.bool_or ~where ~default:false "round" obj;
    }
  with
  | t -> Ok t
  | exception J.Invalid e ->
      Error (Pokemon_checkpoints.Failure.cause ~repeats:true "bad_args" e)

let met goal ~known = List.mem goal.learn_move known
let heal_due s ~since_heal = since_heal >= s.heal_every

(* The sweeper's place: party slot 1 counted from 0 (the grinder leads). *)
let sweeper_slot = 1

let battle_script t =
  let opening =
    match t.strategy.lead with
    | Switch_to_sweeper -> [ B.Battle_script.Switch sweeper_slot ]
  in
  B.Battle_script.make ~opening
    ~send_ins:[ { slot = sweeper_slot; then_ = None } ]
    ~switch_refused:Flee
    ~learn:(Forget_for { move = t.goal.learn_move; slot = t.goal.learn_slot })
    (Attack { slots = t.sweeper_moves; target = Default })

let describe t =
  Printf.sprintf "%s to Lv %d for %s (into move %d) at %s, %s fighting"
    t.goal.species t.goal.target_level t.goal.learn_move (t.goal.learn_slot + 1)
    t.strategy.name t.sweeper
  ^ if t.round then ", one round" else ""
