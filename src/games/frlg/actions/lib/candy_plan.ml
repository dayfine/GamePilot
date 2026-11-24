module J = Grid_maps.Json_field

type use = { member : Action_args.member; policy : Level_up.policy }

type goal = {
  use : use;
  target_level : int;
  species : string option;
  moves : string list;
  max_candies : int;
}

let max_level = 100
let min_target = 2
let default_max_candies = max_level - 1

let move_rule ~where args =
  let learn = J.string ~where "move" args
  and replacing = J.string ~where "replacing" args in
  if learn = replacing then
    J.fail "%sreplacing is the move itself, %s" where learn;
  { Level_up.learn; replacing }

let evolve ~where args =
  match J.find "evolve" args with
  | Some (`Bool b) -> b
  | Some _ -> J.fail "%sevolve is not true or false" where
  | None -> J.fail "%sevolve is missing" where

let read_use ~where args =
  let rules = J.records ~where "learn" args move_rule in
  {
    member = Action_args.member ~where args;
    policy = { rules; evolve = evolve ~where args };
  }

let in_range ~where name ~low ~high args =
  let n = J.int ~where name args in
  if n < low || n > high then
    J.fail "%s%s is %d, not %d..%d" where name n low high
  else n

let strings_or_none ~where name args =
  match J.find name args with
  | None -> []
  | Some v -> J.strings (where ^ name) v

let read_goal ~where args =
  {
    use = read_use ~where args;
    target_level =
      in_range ~where "target_level" ~low:min_target ~high:max_level args;
    species = J.string_opt ~where "expect_species" args;
    moves = strings_or_none ~where "expect_moves" args;
    max_candies =
      (if J.has "max_candies" args then
         in_range ~where "max_candies" ~low:1 ~high:default_max_candies args
       else default_max_candies);
  }

let decode_use args = Action_args.decode ~action:"use_rare_candy" read_use args
let decode_goal args = Action_args.decode ~action:"candy_level" read_goal args

let describe_use u =
  Printf.sprintf "%s, learn %s, %s"
    (Action_args.member_to_string u.member)
    (match u.policy.rules with
    | [] -> "nothing offered"
    | rules -> String.concat ", " (List.map Level_up.describe_rule rules))
    (if u.policy.evolve then "evolve" else "no evolution")

let describe_goal g =
  Printf.sprintf "%s to Lv %d (at most %d candies)%s%s" (describe_use g.use)
    g.target_level g.max_candies
    (match g.species with Some s -> ", then a " ^ s | None -> "")
    (match g.moves with
    | [] -> ""
    | moves -> ", knowing " ^ String.concat ", " moves)
