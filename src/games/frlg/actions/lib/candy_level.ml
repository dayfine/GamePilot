type rig = {
  level : slot:int -> int option;
  candy : slot:int -> Level_up_policy.policy -> Rare_candy.result;
  member : slot:int -> Story.Room_policy.member option;
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

exception Ended of Story.Failure.cause

let fail code fmt =
  Printf.ksprintf (fun d -> raise (Ended (Story.Failure.cause code d))) fmt

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

let read_level (rig : rig) ~slot =
  match rig.level ~slot with
  | Some l -> l
  | None -> fail "level_unread" "slot %d's level did not read" slot

let candy rig (goal : Candy_plan.goal) ~slot ~level fed =
  if fed.count >= goal.max_candies then
    fail "max_candies" "%d candies used and slot %d is Lv %d, not %d" fed.count
      slot level goal.target_level;
  match rig.candy ~slot goal.use.policy with
  | Out_of_candies ->
      fail "out_of_candies" "no Rare Candy left: slot %d is Lv %d, not %d" slot
        level goal.target_level
  | Failed why -> fail "rare_candy_failed" "%s" why
  | Used o when o.levels = 0 ->
      fail "no_effect" "the candy did not take on slot %d (Lv %d)" slot level
  | Used o -> add fed o

let rec feed rig goal ~slot ~before fed =
  let level = read_level rig ~slot in
  (match before with
  | Some b when level <= b ->
      fail "level_stuck" "slot %d still reads Lv %d after a candy" slot level
  | _ -> ());
  rig.log
    (Printf.sprintf "Candy level: slot %d is Lv %d after %d candies." slot level
       fed.count);
  if level >= goal.Candy_plan.target_level then (level, fed)
  else
    feed rig goal ~slot ~before:(Some level) (candy rig goal ~slot ~level fed)

let missing_moves (goal : Candy_plan.goal) known =
  List.filter (fun m -> not (List.mem m known)) goal.moves

let check_level (goal : Candy_plan.goal) (m : Story.Room_policy.member) =
  match m.level with
  | Some l when l >= goal.target_level -> ()
  | Some l ->
      fail "level_short" "the summary reads Lv %d, not %d" l goal.target_level
  | None -> fail "level_unread" "the summary's level did not read"

let check_species (goal : Candy_plan.goal) ~slot (m : Story.Room_policy.member)
    =
  match goal.species with
  | Some s when s <> m.species ->
      fail "species_wrong" "slot %d is a %s, not a %s" slot m.species s
  | _ -> ()

let check_moves (goal : Candy_plan.goal) ~slot known =
  match missing_moves goal known with
  | [] -> ()
  | missing ->
      fail "moves_missing" "slot %d knows %s, not %s" slot
        (String.concat ", " known)
        (String.concat ", " missing)

let checked (goal : Candy_plan.goal) ~slot (m : Story.Room_policy.member) =
  check_level goal m;
  check_species goal ~slot m;
  match (goal.moves, m.moves) with
  | [], _ -> ()
  | _, None -> fail "moves_unread" "slot %d's moves did not read" slot
  | _, Some known -> check_moves goal ~slot known

let report (m : Story.Room_policy.member) level fed =
  {
    candies = fed.count;
    level;
    species = m.species;
    learned = fed.learned;
    declined = fed.declined;
    evolutions = fed.evolutions;
  }

let levelled rig goal ~slot =
  let level, fed = feed rig goal ~slot ~before:None start in
  match rig.member ~slot with
  | None -> fail "no_summary" "slot %d's summary did not read" slot
  | Some m ->
      checked goal ~slot m;
      report m level fed

let run rig (goal : Candy_plan.goal) ~slot =
  rig.log ("Candy level: " ^ Candy_plan.describe_goal goal ^ ".");
  match levelled rig goal ~slot with
  | r ->
      rig.log
        (Printf.sprintf "Candy level: slot %d is a Lv %d %s after %d candies."
           slot r.level r.species r.candies);
      Ok r
  | exception Ended cause ->
      rig.log ("Candy level: " ^ Story.Failure.cause_to_string cause ^ ".");
      Error cause
