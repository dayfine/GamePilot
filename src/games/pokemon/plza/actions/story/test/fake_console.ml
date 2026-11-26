(* A console that keeps time and the inputs sent: each input takes its hold
   and release, each screen read 33 ms (a frame); the screen is a function of
   what was sent and when, so a scenario says what the game shows after each
   press. *)

type input = { at_ms : float; buttons : Wire.button list; stick_ms : int }
(** An input, timed at its end (once released). *)

type t = {
  mutable now : float;
  mutable inputs : input list;  (** newest first *)
  mutable lines : string list;  (** newest first *)
  mutable queued_until : float;  (** when the queued inputs end *)
}

let create () = { now = 0.0; inputs = []; lines = []; queued_until = 0.0 }

let run_input c (command : Wire.command) =
  match command with
  | Wait { wait_ms } -> c.now <- c.now +. float_of_int wait_ms
  | Press { buttons; left_stick; hold_ms; cooldown_ms; _ } ->
      c.now <- c.now +. float_of_int (hold_ms + cooldown_ms);
      let stick_ms = if Option.is_some left_stick then hold_ms else 0 in
      c.inputs <- { at_ms = c.now; buttons; stick_ms } :: c.inputs

let submit c command =
  c.now <- Float.max c.now c.queued_until;
  run_input c command

(* Queued: run on a clock of its own, from the queue's end. *)
let queue c commands =
  let now = c.now in
  c.now <- Float.max c.now c.queued_until;
  List.iter (run_input c) commands;
  c.queued_until <- c.now;
  c.now <- now

let frame_ms = 33.0

let steps ?(party = fun _ -> None) ?(lock = fun _ -> None) ?link_play c screen :
    Plza_story.Steps.game_steps =
  let log line = c.lines <- line :: c.lines in
  let link_play =
    Option.value link_play ~default:(fun c ->
        if (screen c).Plza_story.Look.main_menu then Some false else None)
  in
  {
    submit = submit c;
    submit_batch = List.iter (submit c);
    read_screen =
      (fun () ->
        c.now <- c.now +. frame_ms;
        screen c);
    race =
      (fun command check ->
        submit c command;
        c.now <- c.now +. frame_ms;
        let look = screen c in
        if check look then Some look else None);
    race_batch =
      (fun commands check ->
        List.find_map
          (fun command ->
            submit c command;
            c.now <- c.now +. frame_ms;
            let look = screen c in
            if check look then Some look else None)
          commands);
    race_then =
      (fun command check next ->
        submit c command;
        c.now <- c.now +. frame_ms;
        let look = screen c in
        if check look then (
          List.iter (submit c) (next look);
          Some look)
        else None);
    queue = queue c;
    now = (fun () -> c.now);
    wait_until = (fun at -> c.now <- Float.max c.now at);
    read_lock_target =
      (fun () ->
        c.now <- c.now +. (2. *. frame_ms);
        lock c);
    read_party_slots =
      (fun () ->
        c.now <- c.now +. (2. *. frame_ms);
        party c);
    read_link_play_row =
      (fun () ->
        c.now <- c.now +. frame_ms;
        link_play c);
    log;
    log_detail = log;
  }

(* The times of the presses of [b], oldest first. *)
let presses c b =
  List.rev_map
    (fun i -> i.at_ms)
    (List.filter (fun i -> List.mem b i.buttons) c.inputs)

(* The [n]th press of [b] (from 0) after [after], if sent. *)
let nth_after c b ~after n =
  List.nth_opt (List.filter (fun t -> t > after) (presses c b)) n

let last_press c b =
  List.find_map
    (fun i -> if List.mem b i.buttons then Some i.at_ms else None)
    c.inputs

(* How long the stick has been held in all, and when that reached [ms]. *)
let stick_reached c ms =
  let rec go total = function
    | [] -> None
    | i :: rest ->
        let total = total + i.stick_ms in
        if total >= ms then Some i.at_ms else go total rest
  in
  go 0 (List.rev c.inputs)

let lines c = List.rev c.lines
