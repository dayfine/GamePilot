module Level_up = Frlg_battle.Level_up
module Level_up_policy = Frlg_battle.Level_up_policy

type opened = Opened | No_candy | Not_opened of string

type game_steps = {
  open_bag : unit -> (opened, Pokemon_engine.Failure.cause) result;
  use_candy : slot:int -> (opened, Pokemon_engine.Failure.cause) result;
  level_up : Level_up.game_steps;
  close_bag : unit -> (unit, Pokemon_engine.Failure.cause) result;
  log : string -> unit;
}

type result =
  | Used of Level_up.outcome
  | Out_of_candies
  | Failed of string
  | Stopped of Pokemon_engine.Failure.cause

let close_after game_steps res =
  match game_steps.close_bag () with Ok () -> res | Error c -> Stopped c

let used game_steps policy member =
  match
    Level_up.run game_steps.level_up
      (Level_up_policy.for_everyone policy)
      ~members:[ member ]
  with
  | Ok [ o ] ->
      if o.levels = 0 then game_steps.log "Rare Candy: it had no effect.";
      Used o
  | Ok _ -> Failed "not one outcome for one member"
  | Error why -> Failed why

let use_one game_steps policy ~(member : Level_up.member) =
  game_steps.log (Printf.sprintf "Rare Candy: one on slot %d." member.slot);
  match game_steps.use_candy ~slot:member.slot with
  | Error c -> Stopped c
  | Ok No_candy -> Out_of_candies
  | Ok (Not_opened why) -> Failed why
  | Ok Opened -> used game_steps policy member

let run game_steps policy ~(member : Level_up.member) =
  match game_steps.open_bag () with
  | Error c -> Stopped c
  | Ok No_candy -> Out_of_candies
  | Ok (Not_opened why) -> Failed why
  | Ok Opened -> (
      match use_one game_steps policy ~member with
      | (Used _ | Out_of_candies) as res -> close_after game_steps res
      | (Failed _ | Stopped _) as res -> res)

let describe = function
  | Used o -> "Rare Candy: " ^ Level_up.describe o ^ "."
  | Out_of_candies -> "Rare Candy: none left in the bag."
  | Failed why -> "Rare Candy: failed: " ^ why ^ "."
  | Stopped c -> "Rare Candy: " ^ Pokemon_engine.Failure.cause_to_string c ^ "."
