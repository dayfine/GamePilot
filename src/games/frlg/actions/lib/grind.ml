module P = Grind_plan
module S = Frlg_battle.Scripted_battle
module M = Menu_input

type rig = {
  slot_of : string -> int option;
  known_moves : slot:int -> string list;
  swap : int -> int -> unit;
  go_to : Story.Pose.grid -> unit;
  heal : Grind_plan.heal -> unit;
  find_battle : unit -> unit;
  battle : Frlg_battle.Battle_script.t -> Frlg_battle.Scripted_battle.outcome;
  log : string -> unit;
}

let grinder_slot = 1
let sweeper_slot = 2

let slot rig species =
  match rig.slot_of species with
  | Some s -> s
  | None -> M.fail "not_in_party" (species ^ " is not in the party")

let put rig species ~at =
  let s = slot rig species in
  if s <> at then rig.swap s at

let heal_and_return rig (plan : P.t) =
  rig.log "Grind: heal.";
  rig.heal plan.strategy.heal;
  rig.go_to plan.strategy.spot

(* The most battles this grind fights: the plan's, or the cap below it. *)
let limit ?cap (plan : P.t) =
  match cap with Some c -> min c plan.max_battles | None -> plan.max_battles

(* One battle at the spot: [true] once the goal's move was learned in it. The
   line says "battle N of LIMIT" for the watch page; no level in it: FireRed
   has no level reader. *)
let fight ?cap rig (plan : P.t) script n =
  rig.find_battle ();
  match rig.battle script with
  | S.Failed { why; _ } ->
      M.fail "grind_battle_failed" (Printf.sprintf "battle %d: %s" n why)
  | S.Over summary ->
      rig.log
        (Printf.sprintf "Grind: battle %d of %d %s." n (limit ?cap plan)
           (S.describe (S.Over summary)));
      List.mem plan.goal.learn_move summary.learned

let rec battles ?cap rig plan script ~n ~since_heal =
  let capped = match cap with Some c -> n > c | None -> false in
  if n > plan.P.max_battles then
    M.fail "grind_out_of_battles"
      (Printf.sprintf "%s did not learn %s in %d battles" plan.goal.species
         plan.goal.learn_move plan.max_battles)
  else if capped then
    rig.log
      (Printf.sprintf
         "Grind: capped at %d battles for testing: %s has not learned %s"
         (n - 1) plan.goal.species plan.goal.learn_move)
  else if P.heal_due plan.strategy ~since_heal then (
    heal_and_return rig plan;
    battles ?cap rig plan script ~n ~since_heal:0)
  else if fight ?cap rig plan script n then
    rig.log
      (Printf.sprintf "Grind: %s learned %s in battle %d (Lv %d expected)."
         plan.goal.species plan.goal.learn_move n plan.goal.target_level)
  else battles ?cap rig plan script ~n:(n + 1) ~since_heal:(since_heal + 1)

let grind ?cap rig (plan : P.t) =
  rig.log ("Grind: " ^ P.describe plan ^ ".");
  put rig plan.goal.species ~at:grinder_slot;
  put rig plan.sweeper ~at:sweeper_slot;
  rig.go_to plan.strategy.spot;
  rig.log
    (Printf.sprintf "Grind: at most %d battles%s." (limit ?cap plan)
       (match cap with
       | Some c -> Printf.sprintf " (capped at %d)" c
       | None -> ""));
  battles ?cap rig plan (P.battle_script plan) ~n:1 ~since_heal:0

let run ?cap rig (plan : P.t) =
  let known = rig.known_moves ~slot:(slot rig plan.goal.species) in
  if P.met plan.goal ~known then
    rig.log
      (Printf.sprintf "Grind: %s knows %s already; skipped." plan.goal.species
         plan.goal.learn_move)
  else grind ?cap rig plan
