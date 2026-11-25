(* Repeat_until runs a looped checkpoint round by round until its goal holds,
   saving after each round and reloading the last save to retry a failed one.
   The world is a level grind: target level 10, 3 levels a batch from 1. *)

open Pokemon_checkpoints

let limits = { Repeat_until.max_rounds = 5; attempts_per_round = 2 }

let run ?(limits = limits) ?(target = 10) script =
  let game, reached, log = Level_grind_world.make script in
  let result =
    match
      Repeat_until.run limits ~goal:(reached target) game
        Level_grind_world.checkpoint
    with
    | Ok 1 -> "ok after 1 round"
    | Ok rounds -> Printf.sprintf "ok after %d rounds" rounds
    | Error stop -> "stopped: " ^ Repeat_until.stop_to_string stop
  in
  log () ^ "\n" ^ result

let grind = Level_grind_world.script
let lost = Failure.cause "blacked_out" "the lead fainted"

let cases : Table_test.case list =
  [
    {
      name = "goal already met: no round runs";
      input = (fun () -> run { grind with start_level = 10 });
      expectation = "[Repeat] cp: goal met after 0 rounds\nok after 0 rounds";
    };
    {
      name = "rounds until the goal, each saved";
      input = (fun () -> run grind);
      expectation =
        {|[Repeat] cp: round 1 of at most 5
batch 1: level 1 -> 4
save at level 4
[Repeat] cp: round 1 saved
[Repeat] cp: round 2 of at most 5
batch 2: level 4 -> 7
save at level 7
[Repeat] cp: round 2 saved
[Repeat] cp: round 3 of at most 5
batch 3: level 7 -> 10
save at level 10
[Repeat] cp: round 3 saved
[Repeat] cp: goal met after 3 rounds
ok after 3 rounds|};
    };
    {
      name = "started from a later round's save: only the rounds left";
      input = (fun () -> run { grind with start_level = 7 });
      expectation =
        {|[Repeat] cp: round 1 of at most 5
batch 1: level 7 -> 10
save at level 10
[Repeat] cp: round 1 saved
[Repeat] cp: goal met after 1 round
ok after 1 round|};
    };
    {
      name =
        "a failed round reloads the last save and runs again, losing only its \
         own progress";
      input = (fun () -> run { grind with failing_batches = [ (2, lost) ] });
      expectation =
        {|[Repeat] cp: round 1 of at most 5
batch 1: level 1 -> 4
save at level 4
[Repeat] cp: round 1 saved
[Repeat] cp: round 2 of at most 5
batch 2: level 4 -> 5, then failed
[Repeat] cp: round 2 failed; reloading for attempt 2
reload: level 5 -> 4
batch 3: level 4 -> 7
save at level 7
[Repeat] cp: round 2 saved
[Repeat] cp: round 3 of at most 5
batch 4: level 7 -> 10
save at level 10
[Repeat] cp: round 3 saved
[Repeat] cp: goal met after 3 rounds
ok after 3 rounds|};
    };
    {
      name = "a round failing on every attempt stops the loop";
      input =
        (fun () ->
          run { grind with failing_batches = [ (1, lost); (2, lost) ] });
      expectation =
        {|[Repeat] cp: round 1 of at most 5
batch 1: level 1 -> 2, then failed
[Repeat] cp: round 1 failed; reloading for attempt 2
reload: level 2 -> 1
batch 2: level 1 -> 2, then failed
stopped: round 1 failed after 2 attempts: cp event 2 (battles): blacked_out: the lead fainted|};
    };
    {
      name = "a failure that repeats is not retried";
      input =
        (fun () ->
          run
            {
              grind with
              failing_batches =
                [ (1, Failure.cause ~repeats:true "no_pokemon" "empty party") ];
            });
      expectation =
        {|[Repeat] cp: round 1 of at most 5
batch 1: level 1 -> 2, then failed
stopped: round 1 failed after 1 attempt: cp event 2 (battles): no_pokemon: empty party|};
    };
    {
      name = "the goal still unmet after max_rounds";
      input =
        (fun () ->
          run ~limits:{ limits with max_rounds = 2 } grind
          |> String.split_on_char '\n' |> List.rev |> List.hd);
      expectation = "stopped: goal not met after 2 rounds";
    };
    {
      name = "a failed save stops the loop";
      input = (fun () -> run { grind with failing_save = Some 2 });
      expectation =
        {|[Repeat] cp: round 1 of at most 5
batch 1: level 1 -> 4
save at level 4
[Repeat] cp: round 1 saved
[Repeat] cp: round 2 of at most 5
batch 2: level 4 -> 7
stopped: save failed in round 2: save_not_confirmed: no saved text|};
    };
  ]

let () = Table_test.run "repeat_until" cases
