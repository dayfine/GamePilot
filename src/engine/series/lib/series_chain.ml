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

let run_round_trial ~continuing_from_pass = { number = 1; continuing_from_pass }
