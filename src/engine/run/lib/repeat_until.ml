module Make (T : Engine_rules.GAME_RULES) (Raw : Engine_plan.Plan.RAW) = struct
  module Plan = Engine_plan.Plan.Make (T) (Raw)
  module Game = Game.Make (T) (Raw)
  module Failure = Failure.Make (T)
  module Runner = Runner.Make (T) (Raw)
  module Log_line = Log_line.Make (T)

  type limits = { max_rounds : int; attempts_per_round : int }
  type chore = Goal_check | Between_rounds | Save | Reload

  type stop =
    | Round_failed of { round : int; attempts : int; failure : Failure.t }
    | Chore_failed of { round : int; chore : chore; cause : Failure.cause }
    | Limit_reached of { rounds : int }

  let count n noun = Printf.sprintf "%d %s%s" n noun (if n = 1 then "" else "s")

  let chore round chore = function
    | Ok value -> Ok value
    | Error cause -> Error (Chore_failed { round; chore; cause })

  let ( let* ) = Result.bind

  (* Round [round] until it passes, reloading the last save before each retry. *)
  let rec attempt limits ~say (game : Game.t) checkpoint ~log round tries =
    match Runner.run ~say game checkpoint with
    | Ok () -> Ok ()
    | Error failure
      when Failure.repeats failure || tries >= limits.attempts_per_round ->
        Error (Round_failed { round; attempts = tries; failure })
    | Error _ ->
        log
          (Printf.sprintf "round %d failed; reloading for attempt %d" round
             (tries + 1));
        let* () = chore round Reload (game.reload ()) in
        attempt limits ~say game checkpoint ~log round (tries + 1)

  let run limits ~goal ~say (game : Game.t) (checkpoint : Plan.checkpoint) =
    if limits.max_rounds < 1 || limits.attempts_per_round < 1 then
      invalid_arg "Repeat_until.run: limits below 1";
    let log text =
      say
        [ Log_line.Text ("[Repeat] " ^ checkpoint.checkpoint_id ^ ": " ^ text) ]
    in
    let rec round number =
      let* met = chore number Goal_check (goal ()) in
      if met then (
        log ("goal met after " ^ count (number - 1) "round");
        Ok (number - 1))
      else if number > limits.max_rounds then
        Error (Limit_reached { rounds = limits.max_rounds })
      else (
        log (Printf.sprintf "round %d of at most %d" number limits.max_rounds);
        let* () = attempt limits ~say game checkpoint ~log number 1 in
        let* () = chore number Between_rounds (game.between_rounds ()) in
        let* () = chore number Save (game.save ()) in
        log (Printf.sprintf "round %d saved" number);
        round (number + 1))
    in
    round 1
end
