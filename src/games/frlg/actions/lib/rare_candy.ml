type opened = Opened | No_candy | Not_opened of string

type game_steps = {
  open_candy : slot:int -> (opened, Checkpoints_run.Failure.cause) result;
  level_up : Level_up.game_steps;
  close_bag : unit -> (unit, Checkpoints_run.Failure.cause) result;
  log : string -> unit;
}

type result =
  | Used of Level_up.outcome
  | Out_of_candies
  | Failed of string
  | Stopped of Checkpoints_run.Failure.cause

let closed game_steps o =
  match game_steps.close_bag () with Ok () -> Used o | Error c -> Stopped c

let used game_steps policy member =
  match
    Level_up.run game_steps.level_up
      (Level_up_policy.for_everyone policy)
      ~members:[ member ]
  with
  | Ok [ o ] ->
      if o.levels = 0 then game_steps.log "Rare Candy: it had no effect.";
      closed game_steps o
  | Ok _ -> Failed "not one outcome for one member"
  | Error why -> Failed why

let run game_steps policy ~(member : Level_up.member) =
  game_steps.log (Printf.sprintf "Rare Candy: one on slot %d." member.slot);
  match game_steps.open_candy ~slot:member.slot with
  | Error c -> Stopped c
  | Ok No_candy -> Out_of_candies
  | Ok (Not_opened why) -> Failed why
  | Ok Opened -> used game_steps policy member

let describe = function
  | Used o -> "Rare Candy: " ^ Level_up.describe o ^ "."
  | Out_of_candies -> "Rare Candy: none left in the bag."
  | Failed why -> "Rare Candy: failed: " ^ why ^ "."
  | Stopped c ->
      "Rare Candy: " ^ Checkpoints_run.Failure.cause_to_string c ^ "."
