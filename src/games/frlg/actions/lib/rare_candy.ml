type opened = Opened | No_candy | Not_opened of string

type rig = {
  open_candy : slot:int -> opened;
  level_up : Level_up.rig;
  close_bag : unit -> unit;
  log : string -> unit;
}

type result = Used of Level_up.outcome | Out_of_candies | Failed of string

let used rig policy member =
  match
    Level_up.run rig.level_up (Level_up_policy.only policy) ~members:[ member ]
  with
  | Ok [ o ] ->
      if o.levels = 0 then rig.log "Rare Candy: it had no effect.";
      rig.close_bag ();
      Used o
  | Ok _ -> Failed "not one outcome for one member"
  | Error why -> Failed why

let run rig policy ~(member : Level_up.member) =
  rig.log (Printf.sprintf "Rare Candy: one on slot %d." member.slot);
  match rig.open_candy ~slot:member.slot with
  | No_candy -> Out_of_candies
  | Not_opened why -> Failed why
  | Opened -> used rig policy member

let describe = function
  | Used o -> "Rare Candy: " ^ Level_up.describe o ^ "."
  | Out_of_candies -> "Rare Candy: none left in the bag."
  | Failed why -> "Rare Candy: failed: " ^ why ^ "."
