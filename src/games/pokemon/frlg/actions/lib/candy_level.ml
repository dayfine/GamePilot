module Level_up = Frlg_battle.Level_up
module Level_up_policy = Frlg_battle.Level_up_policy

type game_steps = {
  read_level : slot:int -> (int option, Pokemon_engine.Failure.cause) result;
  open_bag : unit -> (Rare_candy.opened, Pokemon_engine.Failure.cause) result;
  use_candy : slot:int -> Level_up_policy.policy -> Rare_candy.result;
  close_bag : unit -> (unit, Pokemon_engine.Failure.cause) result;
  read_member :
    slot:int -> (Room_policy.member option, Pokemon_engine.Failure.cause) result;
  log : string -> unit;
}

type report = {
  candies : int;
  level : int;
  species : string;
  learned : Level_up_policy.move_rule list;
  declined : string option list;
  evolutions : Level_up.evolution list;
}

let ( let* ) = Result.bind

let fail code fmt =
  Printf.ksprintf (fun d -> Error (Pokemon_engine.Failure.cause code d)) fmt

(* The candies so far and what they did. *)
type fed = {
  count : int;
  learned : Level_up_policy.move_rule list;
  declined : string option list;
  evolutions : Level_up.evolution list;
}

let start = { count = 0; learned = []; declined = []; evolutions = [] }

let add fed (o : Level_up.outcome) =
  {
    count = fed.count + 1;
    learned = fed.learned @ o.learned;
    declined = fed.declined @ o.declined;
    evolutions =
      (if o.evolution = No_evolution then fed.evolutions
       else fed.evolutions @ [ o.evolution ]);
  }

let read_level (game_steps : game_steps) ~slot =
  let* level = game_steps.read_level ~slot in
  match level with
  | Some l -> Ok l
  | None -> fail "level_unread" "slot %d's level did not read" slot

let close_then_fail game_steps err =
  let* () = game_steps.close_bag () in
  err

let use_one_candy game_steps (goal : Candy_plan.goal) ~slot ~current fed =
  match game_steps.use_candy ~slot goal.use.policy with
  | Out_of_candies ->
      close_then_fail game_steps
        (fail "out_of_candies" "no Rare Candy left: slot %d is Lv %d, not %d"
           slot current goal.target_level)
  | Failed why -> fail "rare_candy_failed" "%s" why
  | Stopped cause -> Error cause
  | Used o when o.levels = 0 ->
      close_then_fail game_steps
        (fail "no_effect" "the candy did not take on slot %d (Lv %d)" slot
           current)
  | Used o -> Ok (add fed o)

let rec feed_in_bag game_steps goal ~slot ~start_level ~planned fed =
  if fed.count >= planned then
    let* () = game_steps.close_bag () in
    Ok fed
  else
    let current = start_level + fed.count in
    let* fed = use_one_candy game_steps goal ~slot ~current fed in
    feed_in_bag game_steps goal ~slot ~start_level ~planned fed

let check_batch_count (goal : Candy_plan.goal) ~slot ~start_level ~needed fed =
  if fed.count < needed then
    fail "max_candies" "%d candies used and slot %d is Lv %d, not %d" fed.count
      slot (start_level + fed.count) goal.target_level
  else Ok fed

let open_and_feed game_steps (goal : Candy_plan.goal) ~slot ~start_level ~needed
    ~planned =
  let* opened = game_steps.open_bag () in
  match opened with
  | No_candy ->
      fail "out_of_candies" "no Rare Candy left: slot %d is Lv %d, not %d" slot
        start_level goal.target_level
  | Not_opened why -> fail "rare_candy_failed" "%s" why
  | Opened ->
      let* fed =
        feed_in_bag game_steps goal ~slot ~start_level ~planned start
      in
      check_batch_count goal ~slot ~start_level ~needed fed

let feed_batch game_steps (goal : Candy_plan.goal) ~slot ~start_level ~needed =
  let planned = min needed goal.max_candies in
  if planned <= 0 then
    fail "max_candies" "0 candies used and slot %d is Lv %d, not %d" slot
      start_level goal.target_level
  else open_and_feed game_steps goal ~slot ~start_level ~needed ~planned

let feed game_steps (goal : Candy_plan.goal) ~slot =
  let* start_level = read_level game_steps ~slot in
  game_steps.log
    (Printf.sprintf "Candy level: slot %d starts at Lv %d." slot start_level);
  let needed = goal.target_level - start_level in
  if needed <= 0 then Ok start
  else feed_batch game_steps goal ~slot ~start_level ~needed

let missing_moves (goal : Candy_plan.goal) known =
  List.filter (fun m -> not (List.mem m known)) goal.moves

let check_level (goal : Candy_plan.goal) (m : Room_policy.member) =
  match m.level with
  | Some l when l >= goal.target_level -> Ok l
  | Some l ->
      fail "level_short" "the summary reads Lv %d, not %d" l goal.target_level
  | None -> fail "level_unread" "the summary's level did not read"

let check_species (goal : Candy_plan.goal) ~slot (m : Room_policy.member) =
  match goal.species with
  | Some s when s <> m.species ->
      fail "species_wrong" "slot %d is a %s, not a %s" slot m.species s
  | _ -> Ok ()

let check_moves (goal : Candy_plan.goal) ~slot known =
  match missing_moves goal known with
  | [] -> Ok ()
  | missing ->
      fail "moves_missing" "slot %d knows %s, not %s" slot
        (String.concat ", " known)
        (String.concat ", " missing)

let checked (goal : Candy_plan.goal) ~slot (m : Room_policy.member) =
  let* level = check_level goal m in
  let* () = check_species goal ~slot m in
  let* () =
    match (goal.moves, m.moves) with
    | [], _ -> Ok ()
    | _, None -> fail "moves_unread" "slot %d's moves did not read" slot
    | _, Some known -> check_moves goal ~slot known
  in
  Ok level

let report (m : Room_policy.member) level fed =
  {
    candies = fed.count;
    level;
    species = m.species;
    learned = fed.learned;
    declined = fed.declined;
    evolutions = fed.evolutions;
  }

let levelled game_steps goal ~slot =
  let* fed = feed game_steps goal ~slot in
  let* member = game_steps.read_member ~slot in
  match member with
  | None -> fail "no_summary" "slot %d's summary did not read" slot
  | Some m ->
      let* level = checked goal ~slot m in
      Ok (report m level fed)

let run game_steps (goal : Candy_plan.goal) ~slot =
  game_steps.log ("Candy level: " ^ Candy_plan.describe_goal goal ^ ".");
  match levelled game_steps goal ~slot with
  | Ok r ->
      game_steps.log
        (Printf.sprintf "Candy level: slot %d is a Lv %d %s after %d candies."
           slot r.level r.species r.candies);
      Ok r
  | Error cause ->
      game_steps.log
        ("Candy level: " ^ Pokemon_engine.Failure.cause_to_string cause ^ ".");
      Error cause
