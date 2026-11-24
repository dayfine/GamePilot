module M = Menu_input

let one_candy ~log ~slot use =
  Effects.with_probes Rare_candy_steps.probes (fun () ->
      Rare_candy.run (Rare_candy_steps.make ~log) use ~slot)

let member ~log ~slot =
  List.find_opt
    (fun (m : Story.Room_policy.member) -> m.slot = slot)
    (Party_summary.read_all ~log ())

let rig ~log : Candy_level.rig =
  {
    level = (fun ~slot -> Member_level.read ~log ~slot);
    candy = (fun ~slot use -> one_candy ~log ~slot use);
    member = (fun ~slot -> member ~log ~slot);
    log;
  }

let renamed ~party ~slot species =
  party := Party_roster.replace !party ~slot species

let after_evolution ~log ~party ~slot =
  match member ~log ~slot with
  | Some m -> renamed ~party ~slot m.species
  | None -> log "Rare Candy: the evolved member's species did not read."

let use_candy ~log ~party ~slot use =
  let result = one_candy ~log ~slot use in
  log (Rare_candy.describe result);
  match result with
  | Used o ->
      (match Member_level.read ~log ~slot with
      | Some l -> log (Printf.sprintf "Rare Candy: slot %d is Lv %d." slot l)
      | None -> log "Rare Candy: the level did not read.");
      if o.evolution = Evolved then after_evolution ~log ~party ~slot
  | Out_of_candies -> M.fail "out_of_candies" "no Rare Candy in the bag"
  | Failed why -> M.fail "rare_candy_failed" why

let level ~log ~party ~slot goal =
  match Candy_level.run (rig ~log) goal ~slot with
  | Ok r -> renamed ~party ~slot r.species
  | Error cause -> raise (M.Action_failed cause)

let on_member ~party decode run (_ : Story.Plan.event) args =
  Result.bind (decode args) (fun (v, member) ->
      Result.bind (Party_roster.resolve !party member) (fun slot ->
          M.run (fun () -> run ~slot v)))

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
    ("candy_level", on_member ~party decode_goal (level ~log ~party));
  ]
