open Engine_run

type 'a item = { value : 'a; next : 'a option; continuing_from_pass : bool }
type trial = { number : int; continuing_from_pass : bool }

let already_at_start ~continuing_from_pass ~trial ~attempt =
  continuing_from_pass && trial = 1 && attempt = 1

let trial_already_at_start t ~attempt =
  already_at_start ~continuing_from_pass:t.continuing_from_pass ~trial:t.number
    ~attempt

let run_chain ?after items f =
  let rec go ~continuing_from_pass = function
    | [] -> true
    | value :: rest ->
        let next = match rest with n :: _ -> Some n | [] -> after in
        if f { value; next; continuing_from_pass } then
          go ~continuing_from_pass:true rest
        else false
  in
  go ~continuing_from_pass:false items

let run_trials policy ~continuing_from_pass ~trial run =
  Checkpoint_trials.until_decided policy ~trial (fun number ->
      run { number; continuing_from_pass })

let run_attempts ~retries trial_ctx ~attempt run =
  let rec go tried =
    let n = List.length tried + 1 in
    let already_at_start = trial_already_at_start trial_ctx ~attempt:n in
    Result.bind (run ~attempt:n ~already_at_start) (fun res ->
        let tried = tried @ [ attempt res ] in
        match Checkpoint_trials.attempts ~retries tried with
        | Attempt_again -> go tried
        | (Run_passed | Run_failed _) as verdict -> Ok (n, res, verdict))
  in
  go []

let round_trial ~continuing_from_pass = { number = 1; continuing_from_pass }

let round_passed = function
  | Round_trials.Round_passed _ -> true
  | Round_trials.Round_failed _ -> false

let run_rounds ~max_rounds ~capped ~continuing_from_pass ~round ~next_state init
    run =
  let rec go state ~from_pass runs =
    match Round_trials.decide ~max_rounds ~capped (List.map round runs) with
    | Next_round number -> step state ~from_pass runs ~number
    | decision -> (decision, runs)
  and step state ~from_pass runs ~number =
    let trial_ctx = round_trial ~continuing_from_pass:from_pass in
    match run state ~number trial_ctx with
    | Ok res ->
        let from_pass = round_passed (round res) in
        go (next_state state res) ~from_pass (runs @ [ res ])
    | Error e -> (Round_trials.Stopped e, runs)
  in
  go init ~from_pass:continuing_from_pass []

let verdict_outcome ?(note = "") ~id = function
  | Checkpoint_trials.Checkpoint_passed { passes; runs } ->
      let line =
        Printf.sprintf "[Checkpoints] %s: passed (%d of %d runs)%s" id passes
          runs note
      in
      (true, Some line)
  | Checkpoint_trials.Stopped why ->
      (false, Some (Printf.sprintf "[Checkpoints] %s: stopped: %s" id why))
  | Checkpoint_trials.Run_again -> (false, None)
