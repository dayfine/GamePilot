module J = Grid_maps.Json_field

type t = {
  species : string;
  catches : int;
  max_encounters : int;
  max_balls : int;
  pace : Grid_maps.Direction.t;
}

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

let read ~where args =
  not_ported ~where args;
  let species = J.string ~where "species" args in
  if species = "" then J.fail "%sspecies is empty" where;
  {
    species;
    catches =
      bounded ~where "catches" ~default:default_catches ~max:max_catches args;
    max_encounters =
      bounded ~where "encounters" ~default:default_encounters
        ~max:max_encounter_bound args;
    max_balls =
      bounded ~where "balls" ~default:default_balls ~max:max_ball_bound args;
    pace =
      (if J.has "pace" args then J.direction ~where "pace" args
       else Grid_maps.Direction.East);
  }

let decode args = Action_args.decode ~action:"capture" read args

let describe t =
  Printf.sprintf "%d %s, %d encounters, %d balls" t.catches t.species
    t.max_encounters t.max_balls
