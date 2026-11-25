module M = Menu_input

let ( let* ) = Result.bind

(* The member as the reckoned party has it; ["?"] when it does not. *)
let member_at ~party ~slot : Level_up.member =
  let species =
    Option.value ~default:"?"
      (List.nth_opt (Party_roster.to_list !party) (slot - 1))
  in
  { slot; species; nickname = None }

let one_candy ~log ~party ~slot policy =
  Effects.with_probes Rare_candy_steps.probes (fun () ->
      Rare_candy.run
        (Rare_candy_steps.make ~log)
        policy ~member:(member_at ~party ~slot))

(* Member_level and Party_summary fail by raising Menu_input.Action_failed
   (main's contract); Menu_step.result turns that into a Result, until they
   are converted in their own PR. *)
let level ~log ~slot = Menu_step.result (fun () -> Member_level.read ~log ~slot)

let member ~log ~slot =
  Result.map
    (List.find_opt (fun (m : Room_policy.member) -> m.slot = slot))
    (Menu_step.result (Party_summary.read_all ~log))

let candy_level_game_steps ~log ~party : Candy_level.game_steps =
  {
    level = (fun ~slot -> level ~log ~slot);
    candy = (fun ~slot policy -> one_candy ~log ~party ~slot policy);
    member = (fun ~slot -> member ~log ~slot);
    log;
  }

let renamed ~party ~slot species =
  party := Party_roster.replace !party ~slot species

let after_evolution ~log ~party ~slot =
  let* m = member ~log ~slot in
  Ok
    (match m with
    | Some m -> renamed ~party ~slot m.species
    | None -> log "Rare Candy: the evolved member's species did not read.")

let log_level ~log ~slot = function
  | Some l -> log (Printf.sprintf "Rare Candy: slot %d is Lv %d." slot l)
  | None -> log "Rare Candy: the level did not read."

let use_candy ~log ~party ~slot (use : Candy_plan.use) =
  let result = one_candy ~log ~party ~slot use.policy in
  log (Rare_candy.describe result);
  match result with
  | Used o ->
      let* l = level ~log ~slot in
      log_level ~log ~slot l;
      if o.evolution = Level_up.Evolved then after_evolution ~log ~party ~slot
      else Ok ()
  | Out_of_candies ->
      Error
        (Pokemon_checkpoints.Failure.cause "out_of_candies"
           "no Rare Candy in the bag")
  | Failed why ->
      Error (Pokemon_checkpoints.Failure.cause "rare_candy_failed" why)
  | Stopped cause -> Error cause

let candy_level ~log ~party ~slot goal =
  let* r = Candy_level.run (candy_level_game_steps ~log ~party) goal ~slot in
  Ok (renamed ~party ~slot r.species)

let on_member ~party decode run (_ : Pokemon_checkpoints.Plan.event) args =
  let* v, member = decode args in
  let* slot = Party_roster.resolve !party member in
  Effects.with_probes M.probes (fun () -> run ~slot v)

let decode_use args =
  Result.map
    (fun (u : Candy_plan.use) -> (u, u.member))
    (Candy_plan.decode_use args)

let decode_goal args =
  Result.map
    (fun (g : Candy_plan.goal) -> (g, g.use.member))
    (Candy_plan.decode_goal args)

let handlers ~log ~party =
  [
    ("use_rare_candy", on_member ~party decode_use (use_candy ~log ~party));
    ("candy_level", on_member ~party decode_goal (candy_level ~log ~party));
  ]
