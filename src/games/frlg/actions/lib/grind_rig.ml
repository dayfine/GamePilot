let heal_at ~log ~walk_to : Grind_plan.heal -> unit = function
  | Nurse front ->
      Menu_input.raise_error (walk_to front);
      Heal_and_save.heal_at_nurse ~log ()
  | Pad pad ->
      Menu_input.raise_error (walk_to pad);
      Menu_input.settle_back ~label:"heal pad" ~log

let make ~log ~party ~walk_to ~find_battle ~battle : Grind.rig =
  {
    slot_of = (fun species -> Party_roster.slot_of !party species);
    known_moves = (fun ~slot -> Summary_moves.read_known ~log ~slot);
    swap =
      (fun a b ->
        Party_actions.swap ~log a b;
        party := Party_roster.swap !party a b);
    go_to = (fun pose -> Menu_input.raise_error (walk_to pose));
    heal = heal_at ~log ~walk_to;
    find_battle;
    battle;
    log;
  }
