module J = Grid_maps.Json_field

type use = { member : Action_args.member; policy : Level_up_policy.policy }

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
let ( let* ) = Result.bind

(* Decoding is in two steps. Main's Json_field reads raise on a field missing
   or of the wrong type, and Action_args.decode turns that into [bad_args]
   (main's contract, to be converted to Result in its own PR); what they
   cannot check is checked after, here, as a Result. *)
let bad_args fmt =
  Printf.ksprintf
    (fun e -> Error (Checkpoints_run.Failure.cause ~repeats:true "bad_args" e))
    fmt

(* The fields as read, before the checks; [where] names each in a message. *)
type rule_read = { rule_where : string; learn : string; replacing : string }

type use_read = {
  use_where : string;
  member_read : Action_args.member;
  rules : rule_read list;
  evolve : Yojson.Safe.t option;
}

type goal_read = {
  use_read : use_read;
  target_read : int;
  species_read : string option;
  moves_read : string list;
  max_candies_read : int option;
}

let read_rule ~where args =
  {
    rule_where = where;
    learn = J.string ~where "move" args;
    replacing = J.string ~where "replacing" args;
  }

let read_use ~where args =
  let rules = J.records ~where "learn" args read_rule in
  {
    use_where = where;
    member_read = Action_args.member ~where args;
    rules;
    evolve = J.find "evolve" args;
  }

let strings_or_none ~where name args =
  match J.find name args with
  | None -> []
  | Some v -> J.strings (where ^ name) v

let read_goal ~where args =
  {
    use_read = read_use ~where args;
    target_read = J.int ~where "target_level" args;
    species_read = J.string_opt ~where "expect_species" args;
    moves_read = strings_or_none ~where "expect_moves" args;
    max_candies_read =
      (if J.has "max_candies" args then Some (J.int ~where "max_candies" args)
       else None);
  }

let check_rule (r : rule_read) =
  if r.learn = r.replacing then
    bad_args "%sreplacing is the move itself, %s" r.rule_where r.learn
  else Ok { Level_up_policy.learn = r.learn; replacing = r.replacing }

let check_rules rules =
  List.fold_left
    (fun checked r ->
      let* checked = checked in
      let* rule = check_rule r in
      Ok (checked @ [ rule ]))
    (Ok []) rules

let check_evolve ~where = function
  | Some (`Bool b) -> Ok b
  | Some _ -> bad_args "%sevolve is not true or false" where
  | None -> bad_args "%sevolve is missing" where

let check_use (u : use_read) =
  let* rules = check_rules u.rules in
  let* evolve = check_evolve ~where:u.use_where u.evolve in
  Ok { member = u.member_read; policy = { rules; evolve } }

let in_range ~where name ~low ~high n =
  if n < low || n > high then
    bad_args "%s%s is %d, not %d..%d" where name n low high
  else Ok n

let check_max_candies ~where = function
  | None -> Ok default_max_candies
  | Some n -> in_range ~where "max_candies" ~low:1 ~high:default_max_candies n

let check_goal (g : goal_read) =
  let where = g.use_read.use_where in
  let* use = check_use g.use_read in
  let* target_level =
    in_range ~where "target_level" ~low:min_target ~high:max_level g.target_read
  in
  let* max_candies = check_max_candies ~where g.max_candies_read in
  Ok
    {
      use;
      target_level;
      species = g.species_read;
      moves = g.moves_read;
      max_candies;
    }

let decode_use args =
  let* u = Action_args.decode ~action:"use_rare_candy" read_use args in
  check_use u

let decode_goal args =
  let* g = Action_args.decode ~action:"candy_level" read_goal args in
  check_goal g

let describe_use u =
  Printf.sprintf "%s, learn %s, %s"
    (Action_args.member_to_string u.member)
    (match u.policy.rules with
    | [] -> "nothing offered"
    | rules -> String.concat ", " (List.map Level_up_policy.describe_rule rules))
    (if u.policy.evolve then "evolve" else "no evolution")

let describe_goal g =
  Printf.sprintf "%s to Lv %d (at most %d candies)%s%s" (describe_use g.use)
    g.target_level g.max_candies
    (match g.species with Some s -> ", then a " ^ s | None -> "")
    (match g.moves with
    | [] -> ""
    | moves -> ", knowing " ^ String.concat ", " moves)
