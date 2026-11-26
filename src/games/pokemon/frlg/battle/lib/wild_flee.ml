type outcome = Fled of int | Not_fled of string

let max_runs = 5
let event_timeout_ms = 20000

let run_line runs =
  if runs = 0 then "Wild battle: RUN."
  else Printf.sprintf "Wild battle: RUN again (refused %d)." runs

let refused runs =
  Not_fled
    (Printf.sprintf
       "the action menu came back after %d RUNs: a trainer's battle, or a foe \
        that bars escape"
       runs)

let unanswered event runs =
  Not_fled (Printf.sprintf "%s after %d RUNs" (Battle.event_name event) runs)

let run (game_steps : Battle.game_steps) ~log =
  let rec from runs =
    match game_steps.next_event ~timeout_ms:event_timeout_ms with
    | Battle_over -> Fled runs
    | Action_menu when runs >= max_runs -> refused runs
    | Action_menu ->
        log (run_line runs);
        game_steps.run ();
        from (runs + 1)
    | (Switch_in | Move_learn | Use_next | Switch_offer | Timed_out) as event ->
        unanswered event runs
  in
  from 0

let describe = function
  | Fled runs -> Printf.sprintf "fled after %d RUNs" runs
  | Not_fled why -> "not fled: " ^ why
