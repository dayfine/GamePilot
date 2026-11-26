module J = Json_field

type target = Species of string | Uncaught of string list

type t = {
  target : target;
  catches : int;
  max_encounters : int;
  max_balls : int;
  ball : string;
  pace : Grid_geometry.Direction.t;
}

let balls = [ "poke-ball"; "great-ball"; "ultra-ball" ]
let default_ball = "poke-ball"
let default_catches = 1
let default_encounters = 20
let default_balls = 5
let max_catches = 999
let max_encounter_bound = 9999
let max_ball_bound = 999

let bounded ~where name ~default ~max args =
  match J.find name args with
  | None -> default
  | Some _ ->
      let n = J.int ~where name args in
      if n < 1 || n > max then J.fail "%s%s is %d, not 1..%d" where name n max
      else n

let not_ported ~where args =
  List.iter
    (fun name ->
      if J.has name args then
        J.fail "%s%s: the weakening move is not ported" where name)
    [ "move"; "turns" ]

let species ~where args =
  let species = J.string ~where "species" args in
  if species = "" then J.fail "%sspecies is empty" where;
  Species species

let target ~where args =
  match (J.has "species" args, J.has "uncaught" args) with
  | true, true -> J.fail "%sspecies and uncaught: name one" where
  | false, true ->
      Uncaught (J.strings (where ^ "uncaught") (J.field ~where "uncaught" args))
  | _ -> species ~where args

let ball ~where args =
  match J.string_opt ~where "ball" args with
  | None -> default_ball
  | Some b when List.mem b balls -> b
  | Some b -> J.fail "%sball is %s, not %s" where b (String.concat ", " balls)

let read ~where args =
  not_ported ~where args;
  {
    target = target ~where args;
    catches =
      bounded ~where "catches" ~default:default_catches ~max:max_catches args;
    max_encounters =
      bounded ~where "encounters" ~default:default_encounters
        ~max:max_encounter_bound args;
    max_balls =
      bounded ~where "balls" ~default:default_balls ~max:max_ball_bound args;
    ball = ball ~where args;
    pace =
      (if J.has "pace" args then
         Grid_maps.Grid_field.direction ~where "pace" args
       else Grid_geometry.Direction.East);
  }

let decode args = Action_args.decode ~action:"capture" read args

let apply_options options t =
  let ball =
    match Run_options.find options "ball" with
    | Some b when List.mem b balls -> b
    | _ -> t.ball
  in
  let max_balls =
    match Run_options.int options "balls" with
    | Some n when n >= 1 && n <= max_ball_bound -> n
    | _ -> t.max_balls
  in
  { t with ball; max_balls }

let target_name = function Species s -> s | Uncaught _ -> "uncaught species"

let describe t =
  Printf.sprintf "%d %s, %d encounters, %d %s" t.catches (target_name t.target)
    t.max_encounters t.max_balls t.ball
