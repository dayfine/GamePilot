type opened = Opened | No_candy | Not_opened of string

type driver = {
  open_candy : slot:int -> opened;
  level_up : Level_up.driver;
  close_bag : unit -> unit;
  log : string -> unit;
}

type result = Used of Level_up.outcome | Out_of_candies | Failed of string

let used driver policy member =
  match
    Level_up.run driver.level_up
      (Level_up_policy.for_everyone policy)
      ~members:[ member ]
  with
  | Ok [ o ] ->
      if o.levels = 0 then driver.log "Rare Candy: it had no effect.";
      driver.close_bag ();
      Used o
  | Ok _ -> Failed "not one outcome for one member"
  | Error why -> Failed why

let run driver policy ~(member : Level_up.member) =
  driver.log (Printf.sprintf "Rare Candy: one on slot %d." member.slot);
  match driver.open_candy ~slot:member.slot with
  | No_candy -> Out_of_candies
  | Not_opened why -> Failed why
  | Opened -> used driver policy member

let describe = function
  | Used o -> "Rare Candy: " ^ Level_up.describe o ^ "."
  | Out_of_candies -> "Rare Candy: none left in the bag."
  | Failed why -> "Rare Candy: failed: " ^ why ^ "."
