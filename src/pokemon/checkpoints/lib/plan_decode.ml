open Grid_maps
module F = Json_field
open Plan_fields

let format = "gamepilot-checkpoint/1"
let old_format = "pokesim-authored-checkpoint/1"

let zone_pose ~where obj : Pose.zone =
  only ~where [ "place"; "spot"; "heading" ] obj;
  {
    place = F.string ~where "place" obj;
    spot = F.string_opt ~where "spot" obj;
    heading = optional ~where "heading" obj F.int;
  }

let declared_pose path value : Pose.declared =
  let obj = F.as_object path value and where = path ^ "." in
  match (F.has "map" obj, F.has "place" obj) with
  | true, false -> Pose.Grid (grid_pose ~where obj)
  | false, true -> Pose.Zone (zone_pose ~where obj)
  | _ -> F.fail "%s has a \"map\" or a \"place\", not both or neither." path

let target ~where args =
  grid_pose ~where:(where ^ "target.") (object_field ~where "target" args)

let fight_wild ~where args = F.bool_or ~where ~default:false "fight_wild" args

let leg ~where obj : Plan.leg =
  only ~where [ "direction"; "tiles" ] obj;
  {
    direction = F.direction ~where "direction" obj;
    tiles = F.int ~where "tiles" obj;
  }

let list_of ~where key args read =
  required ~where key args;
  F.records ~where key args read

let route ~where args =
  Plan.Route
    { target = target ~where args; fight_wild = fight_wild ~where args }

let legs ~where args =
  Plan.Legs
    {
      legs = list_of ~where "legs" args leg;
      fight_wild = fight_wild ~where args;
    }

let flag ~default key ~where args = F.bool_or ~where ~default key args
let ready ~where args = Plan.Ready (target ~where args)
let step ~where args = Plan.Step (F.direction ~where "direction" args)
let answer ~where args = Plan.Answer (flag ~default:true "yes" ~where args)

let battle ~where args =
  Plan.Battle { may_lose = flag ~default:false "may_lose" ~where args }

let train ~where args = Plan.Train (F.int ~where "battles" args)
let shop ~where args = Plan.Shop (list_of ~where "items" args item)
let no_args kind ~where:_ _ = kind

(* Each built-in kind: its name, the args it takes, and how to read them. *)
let builtin_kinds =
  [
    ("new_game", [], no_args Plan.New_game);
    ("options", [], no_args Plan.Options);
    ("talk", [], no_args Plan.Talk);
    ("scene", [], no_args Plan.Scene);
    ("heal", [], no_args Plan.Heal);
    ("save", [], no_args Plan.Save);
    ("route", [ "target"; "fight_wild" ], route);
    ("ready", [ "target" ], ready);
    ("legs", [ "legs"; "fight_wild" ], legs);
    ("step", [ "direction" ], step);
    ("answer", [ "yes" ], answer);
    ("battle", [ "may_lose" ], battle);
    ("train", [ "battles" ], train);
    ("shop", [ "items" ], shop);
  ]

let builtin_kind name =
  List.find_map
    (fun (named, allowed, read) ->
      if named = name then Some (allowed, read) else None)
    builtin_kinds

let kind ~where obj action : Plan.kind =
  let name = F.string ~where "kind" obj in
  let args = Option.value ~default:[] (F.object_opt ~where "args" obj) in
  let args_where = where ^ "args." in
  match (name, builtin_kind name) with
  | "game_action", _ when action = None ->
      F.fail "%saction is missing: a game_action names its action." where
  | "game_action", _ -> Plan.Game_action args
  | _, Some (allowed, read) ->
      only ~where:args_where allowed args;
      read ~where:args_where args
  | _, None -> F.fail "%skind \"%s\" is not a story event kind." where name

let event ~where obj : Plan.event =
  only ~where
    [
      "id";
      "kind";
      "why";
      "action";
      "args";
      "skip_if";
      "declared_after";
      "once_per_save";
    ]
    obj;
  let id = F.string ~where "id" obj in
  if id = "" then F.fail "%sid is empty." where;
  let action =
    match F.string_opt ~where "action" obj with
    | Some "" -> None
    | named -> named
  in
  {
    id;
    kind = kind ~where obj action;
    action;
    why = Option.value ~default:"" (F.string_opt ~where "why" obj);
    skip_if =
      Option.fold ~none:[]
        ~some:(F.strings (where ^ "skip_if"))
        (F.find "skip_if" obj);
    declared_after =
      Option.map
        (declared_pose (where ^ "declared_after"))
        (F.find "declared_after" obj);
    once_per_save = F.bool_or ~where ~default:false "once_per_save" obj;
  }

let check_unique_ids ~where (events : Plan.event list) =
  let check seen i (event : Plan.event) =
    match List.assoc_opt event.id seen with
    | Some first ->
        F.fail "%sevents[%d].id \"%s\" repeats events[%d]." where i event.id
          first
    | None -> (event.id, i) :: seen
  in
  ignore
    (List.fold_left (fun (seen, i) e -> (check seen i e, i + 1)) ([], 0) events)

let checkpoint ~where obj : Plan.checkpoint =
  only ~where [ "id"; "title"; "start"; "events"; "metadata" ] obj;
  let checkpoint_id = F.string ~where "id" obj in
  if checkpoint_id = "" then F.fail "%sid is empty." where;
  let events = list_of ~where "events" obj event in
  check_unique_ids ~where events;
  {
    checkpoint_id;
    title = F.string ~where "title" obj;
    start = Option.map (declared_pose (where ^ "start")) (F.find "start" obj);
    events;
  }

(* The metadata's "retries": attempts of a run after its first fails. *)
let retries ~where = function
  | None -> 0
  | Some metadata -> (
      match optional ~where "retries" metadata F.int with
      | None -> 0
      | Some n when n >= 0 -> n
      | Some n -> F.fail "%sretries is %d, not 0 or more." where n)

let repeat_of ~where obj : Plan.repeat =
  only ~where [ "until"; "max_rounds" ] obj;
  let max_rounds = F.int ~where "max_rounds" obj in
  if max_rounds < 1 then
    F.fail "%smax_rounds is %d, not 1 or more." where max_rounds;
  let until = object_field ~where "until" obj in
  {
    until = Postcondition_decode.postconditions ~where:(where ^ "until.") until;
    max_rounds;
  }

(* The metadata's "repeat": {"until": postconditions, "max_rounds": n}. *)
let repeat ~where metadata =
  Option.bind metadata (fun m ->
      Option.map
        (repeat_of ~where:(where ^ "repeat."))
        (F.object_opt ~where "repeat" m))

let plan ~where obj : Plan.t =
  only ~where [ "format"; "game"; "checkpoint"; "execution"; "metadata" ] obj;
  let named = F.string ~where "format" obj in
  if named <> format && named <> old_format then
    F.fail "%sformat is \"%s\", not %s." where named format;
  let inner = object_field ~where "checkpoint" obj in
  let inner_where = where ^ "checkpoint." in
  let metadata, metadata_where =
    match F.object_opt ~where:inner_where "metadata" inner with
    | Some metadata -> (Some metadata, inner_where)
    | None -> (F.object_opt ~where "metadata" obj, where)
  in
  {
    game = F.string ~where "game" obj;
    checkpoint = checkpoint ~where:inner_where inner;
    execution = object_field ~where "execution" obj;
    metadata;
    postconditions =
      Postcondition_decode.of_metadata ~where:metadata_where metadata;
    retries = retries ~where:(metadata_where ^ "metadata.") metadata;
    repeat = repeat ~where:(metadata_where ^ "metadata.") metadata;
  }

let decode ~source json =
  let where = source ^ ": " in
  try Ok (plan ~where (F.as_object source json))
  with F.Invalid message -> Error message

let load path =
  match Yojson.Safe.from_file path with
  | json -> decode ~source:(Filename.basename path) json
  | exception Yojson.Json_error message ->
      Error (Filename.basename path ^ ": " ^ message)
  | exception Sys_error message -> Error message
