type limits = { max_rounds : int; attempts_per_round : int }
type chore = Goal_check | Heal | Save | Reload

type stop =
  | Round_failed of { round : int; attempts : int; failure : Failure.t }
  | Chore_failed of { round : int; chore : chore; cause : Failure.cause }
  | Limit_reached of { rounds : int }

let chore_name = function
  | Goal_check -> "goal check"
  | Heal -> "heal"
  | Save -> "save"
  | Reload -> "reload"

let count n noun = Printf.sprintf "%d %s%s" n noun (if n = 1 then "" else "s")

let stop_to_string = function
  | Round_failed { round; attempts; failure } ->
      Printf.sprintf "round %d failed after %s: %s" round
        (count attempts "attempt")
        (Failure.to_string failure)
  | Chore_failed { round; chore; cause } ->
      Printf.sprintf "%s failed in round %d: %s" (chore_name chore) round
        (Failure.cause_to_string cause)
  | Limit_reached { rounds } -> "goal not met after " ^ count rounds "round"

let chore round chore = function
  | Ok value -> Ok value
  | Error cause -> Error (Chore_failed { round; chore; cause })

let ( let* ) = Result.bind

(* Round [round] until it passes, reloading the last save before each retry. *)
let rec attempt limits (game : Game.t) checkpoint ~log round tries =
  match Runner.run game checkpoint with
  | Ok () -> Ok ()
  | Error failure
    when Failure.repeats failure || tries >= limits.attempts_per_round ->
      Error (Round_failed { round; attempts = tries; failure })
  | Error _ ->
      log
        (Printf.sprintf "round %d failed; reloading for attempt %d" round
           (tries + 1));
      let* () = chore round Reload (game.reload ()) in
      attempt limits game checkpoint ~log round (tries + 1)

let run limits ~goal (game : Game.t) (checkpoint : Plan.checkpoint) =
  if limits.max_rounds < 1 || limits.attempts_per_round < 1 then
    invalid_arg "Repeat_until.run: limits below 1";
  let log text =
    game.log ("[Repeat] " ^ checkpoint.checkpoint_id ^ ": " ^ text)
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
      let* () = attempt limits game checkpoint ~log number 1 in
      let* () = chore number Heal (game.heal ()) in
      let* () = chore number Save (game.save ()) in
      log (Printf.sprintf "round %d saved" number);
      round (number + 1))
  in
  round 1
