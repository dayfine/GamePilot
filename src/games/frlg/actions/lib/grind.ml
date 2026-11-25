module P = Grind_plan
module S = Frlg_battle.Scripted_battle
module M = Menu_input

type rig = {
  slot_of : string -> int option;
  known_moves : slot:int -> string list;
  level : slot:int -> int option;
  swap : int -> int -> unit;
  go_to : Checkpoints.Pose.grid -> unit;
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

(* The C++'s read_level(): an unread level ends the step. *)
let read_level rig (plan : P.t) ~slot ~when_ =
  match rig.level ~slot with
  | Some level -> level
  | None ->
      M.fail "grind_level_unread"
        (Printf.sprintf "couldn't read %s's level %s" plan.goal.species when_)

let reached (plan : P.t) level = level >= plan.goal.target_level

(* What a battle left: the grinder's level, whether the goal's move was learned
   in it, and whether the sweeper could not come in (fainted in an earlier
   battle: "... has no energy left to battle!", mg-04b testing 6), so the lead
   ran and the next battle waits for a heal. *)
type fought = { level : int; learned_now : bool; sweeper_down : bool }

let fought rig (plan : P.t) (summary : S.summary) ~level n =
  let sweeper_down = summary.switches_refused > 0 in
  if sweeper_down then
    rig.log
      (Printf.sprintf "Grind: battle %d: %s could not come in, ran." n
         plan.sweeper);
  {
    level;
    learned_now = List.mem plan.goal.learn_move summary.learned;
    sweeper_down;
  }

(* One battle at the spot, then the grinder's level read on its summary (the
   C++'s battle()). The line says "battle N of LIMIT, Lv L" for the watch
   page. *)
let fight ~limit rig (plan : P.t) script n =
  rig.find_battle ();
  match rig.battle script with
  | S.Failed { why; _ } ->
      M.fail "grind_battle_failed" (Printf.sprintf "battle %d: %s" n why)
  | S.Over summary ->
      let level =
        read_level rig plan ~slot:grinder_slot
          ~when_:(Printf.sprintf "after battle %d" n)
      in
      rig.log
        (Printf.sprintf "Grind: battle %d of %d, Lv %d %s." n limit level
           (S.describe (S.Over summary)));
      fought rig plan summary ~level n

let log_reached rig (plan : P.t) ~level ~n ~learned =
  rig.log
    (Printf.sprintf "Grind: %s reached Lv %d (target %d) in battle %d; %s %s."
       plan.goal.species level plan.goal.target_level n
       (if learned then "learned" else "did not learn")
       plan.goal.learn_move)

(* Reached: the C++ heals once more and ends back on the spot. *)
let finish rig (plan : P.t) ~level ~n ~learned =
  log_reached rig plan ~level ~n ~learned;
  heal_and_return rig plan

type progress = { n : int; since_heal : int; level : int; learned : bool }

let capped ?cap p = match cap with Some c -> p.n > c | None -> false

(* After a battle: the end when the level is reached, else the next, after a
   heal when the sweeper is down. *)
let rec after_battle ?cap rig plan script p { level; learned_now; sweeper_down }
    =
  let learned = p.learned || learned_now in
  if reached plan level then finish rig plan ~level ~n:p.n ~learned
  else (
    if sweeper_down then heal_and_return rig plan;
    let since_heal = if sweeper_down then 0 else p.since_heal + 1 in
    battles ?cap rig plan script { n = p.n + 1; since_heal; level; learned })

(* Out of battles, capped, or on. *)
and battles ?cap rig plan script p =
  if p.n > plan.P.max_battles then
    M.fail "grind_out_of_battles"
      (Printf.sprintf "%s did not reach Lv %d in %d battles (Lv %d)"
         plan.goal.species plan.goal.target_level plan.max_battles p.level)
  else if capped ?cap p then
    rig.log
      (Printf.sprintf
         "Grind: capped at %d battles for testing: %s is Lv %d, not %d"
         (p.n - 1) plan.goal.species p.level plan.goal.target_level)
  else heal_or_fight ?cap rig plan script p

and heal_or_fight ?cap rig plan script p =
  if P.heal_due plan.strategy ~since_heal:p.since_heal then (
    heal_and_return rig plan;
    battles ?cap rig plan script { p with since_heal = 0 })
  else
    after_battle ?cap rig plan script p
      (fight ~limit:(limit ?cap plan) rig plan script p.n)

let grind ?cap rig (plan : P.t) ~level =
  put rig plan.goal.species ~at:grinder_slot;
  put rig plan.sweeper ~at:sweeper_slot;
  rig.go_to plan.strategy.spot;
  rig.log
    (Printf.sprintf "Grind: at most %d battles%s." (limit ?cap plan)
       (match cap with
       | Some c -> Printf.sprintf " (capped at %d)" c
       | None -> ""));
  battles ?cap rig plan (P.battle_script plan)
    { n = 1; since_heal = 0; level; learned = false }

(* The C++'s first read: an unread level ends the step, a level reached
   already skips the walk out. *)
let level_first ?cap rig (plan : P.t) ~at =
  rig.log ("Grind: " ^ P.describe plan ^ ".");
  let level = read_level rig plan ~slot:at ~when_:"before the grind" in
  if reached plan level then
    rig.log
      (Printf.sprintf "Grind: %s is Lv %d, at least %d already; skipped."
         plan.goal.species level plan.goal.target_level)
  else grind ?cap rig plan ~level

(* {1 One round} GamePilot's: a round ends at the heal place, healed, so the
   runner can save there after each one (mg-04b). *)

let heal_at_end rig (plan : P.t) =
  rig.log "Grind: heal.";
  rig.heal plan.strategy.heal

(* Battles [p.n ..] of the round, up to [limit], ending at the target level. *)
let rec round_battles ~limit rig (plan : P.t) script p =
  if p.n > limit then (
    rig.log
      (Printf.sprintf "Grind: round over after %d battles: %s is Lv %d, not %d"
         limit plan.goal.species p.level plan.goal.target_level);
    heal_at_end rig plan)
  else after_round_battle ~limit rig plan script p

and after_round_battle ~limit rig plan script p =
  let { level; learned_now; sweeper_down } = fight ~limit rig plan script p.n in
  let learned = p.learned || learned_now in
  if reached plan level then (
    log_reached rig plan ~level ~n:p.n ~learned;
    heal_at_end rig plan)
  else if sweeper_down then heal_at_end rig plan
  else
    round_battles ~limit rig plan script { p with n = p.n + 1; level; learned }

(* At the target level without the move: no later battle offers it. *)
let move_missed (plan : P.t) level =
  M.fail "grind_move_missed"
    (Printf.sprintf "%s is Lv %d, at least %d, and does not know %s"
       plan.goal.species level plan.goal.target_level plan.goal.learn_move)

let round ?cap rig (plan : P.t) ~at =
  let level = read_level rig plan ~slot:at ~when_:"before the round" in
  if reached plan level then move_missed plan level;
  put rig plan.goal.species ~at:grinder_slot;
  put rig plan.sweeper ~at:sweeper_slot;
  rig.go_to plan.strategy.spot;
  let limit = min (limit ?cap plan) plan.strategy.heal_every in
  rig.log (Printf.sprintf "Grind: a round of at most %d battles." limit);
  round_battles ~limit rig plan (P.battle_script plan)
    { n = 1; since_heal = 0; level; learned = false }

(* The move known: GamePilot's skip, before the C++'s steps. *)
let run ?cap rig (plan : P.t) =
  let at = slot rig plan.goal.species in
  let known = rig.known_moves ~slot:at in
  if P.met plan.goal ~known then
    rig.log
      (Printf.sprintf "Grind: %s knows %s already; skipped." plan.goal.species
         plan.goal.learn_move)
  else if plan.round then round ?cap rig plan ~at
  else level_first ?cap rig plan ~at
