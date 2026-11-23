(* Blink recovery against the C++'s golden vectors
   (fixtures/blink_recovery.txt, "recover" and "reanchor" lines). A capture
   arrives a frame at a time and the loop is polled once a second, as the C++
   loop over its watchers; every pass that is not "no_samples" or "not_fresh"
   and differs from the last printed one is checked. *)

open Bdsp_rng

let records = Fixture_lines.read "fixtures/blink_recovery.txt"
let us = 1e6
let thousand = 1000.0

let state_text (s : Xorshift128.state) =
  String.concat " " (List.map Fixture_lines.hex32 [ s.s0; s.s1; s.s2; s.s3 ])

(* "<runs> v*n ...": one watcher's match in thousandths, n frames of v. *)
let rec runs_capture tokens =
  match tokens with
  | count :: rest ->
      let runs = List.filteri (fun i _ -> i < int_of_string count) rest in
      let frames =
        List.concat_map
          (fun run ->
            match String.split_on_char '*' run with
            | [ value; count ] ->
                List.init (int_of_string count) (fun _ -> int_of_string value)
            | _ -> failwith ("not a run: " ^ run))
          runs
      in
      ( Array.of_list frames,
        List.filteri (fun i _ -> i >= int_of_string count) rest )
  | [] -> failwith "missing capture"

and captures count tokens =
  if count = 0 then []
  else
    let capture, rest = runs_capture tokens in
    capture :: captures (count - 1) rest

let waiting_text : Blink_recovery.waiting -> string = function
  | No_samples -> "no_samples"
  | No_threshold -> "no_threshold"
  | Not_fresh -> "not_fresh"
  | Too_few_blinks -> "too_few_blinks"
  | No_tick_fit -> "no_tick_fit"
  | Confirming -> "confirming"
  | Too_few_rolls -> "too_few_rolls"
  | Unsolved -> "unsolved"

let confirmed_text ~start (r : Blink_recovery.recovery) =
  Printf.sprintf
    "confirmed %s %d slots %s anchor %d %d %s %.17g %d thresholds %s"
    (state_text r.state) r.events
    (String.concat " " (List.map string_of_int r.slots))
    r.anchor_stream r.clock.anchor_advance
    (Fixture_lines.micros_since ~from:start r.clock.anchor_time)
    r.clock.tick_seconds r.clock.npcs
    (String.concat " " (List.map Fixture_lines.float17 r.thresholds))

let decision_text ~start : Blink_recovery.decision -> string = function
  | Keep_collecting waiting -> waiting_text waiting
  | Provisional { state; events } ->
      Printf.sprintf "provisional %s %d" (state_text state) events
  | Changed { state; events } ->
      Printf.sprintf "changed %s %d" (state_text state) events
  | Dropped -> "dropped"
  | Confirmed recovery -> confirmed_text ~start recovery
  | Gave_up reason -> "gave_up reason=" ^ reason

type feed = {
  frames : int array array;
  start_us : int;
  frame_us : int;
  first : int array;  (** Oldest sample still held, per watcher. *)
  next : int array;  (** First sample not yet arrived. *)
}

let timestamp feed index =
  float_of_int (feed.start_us + (index * feed.frame_us)) /. us

(* What each watcher holds at [now_us]: its samples up to then, oldest first. *)
let arrive feed ~now_us =
  Array.mapi
    (fun w frames ->
      while
        feed.next.(w) < Array.length frames
        && feed.start_us + (feed.next.(w) * feed.frame_us) <= now_us
      do
        feed.next.(w) <- feed.next.(w) + 1
      done;
      List.init
        (feed.next.(w) - feed.first.(w))
        (fun i ->
          let index = feed.first.(w) + i in
          ({
             timestamp = timestamp feed index;
             score = float_of_int frames.(index) /. thousand;
           }
            : Blink_extraction.match_sample)))
    feed.frames
  |> Array.to_list

let discard feed cuts =
  List.iteri
    (fun w cut ->
      Option.iter
        (fun cut ->
          while
            feed.first.(w) < feed.next.(w)
            && timestamp feed feed.first.(w) < cut
          do
            feed.first.(w) <- feed.first.(w) + 1
          done)
        cut)
    cuts

let finished : Blink_recovery.decision -> bool = function
  | Confirmed _ | Gave_up _ -> true
  | _ -> false

let rec run feed ~poll_us ~start loop k last printed =
  let now_us = feed.start_us + (k * poll_us) in
  let matches = arrive feed ~now_us in
  let ended =
    Array.for_all2
      (fun next frames -> next = Array.length frames)
      feed.next feed.frames
  in
  let loop, outcome =
    Blink_recovery.poll loop ~now:(float_of_int now_us /. us) matches
  in
  discard feed outcome.discard_before;
  let text = decision_text ~start outcome.decision in
  let line =
    (match outcome.events with Some n -> string_of_int n | None -> "-")
    ^ " " ^ text
  in
  let shown = text <> "no_samples" && text <> "not_fresh" && line <> last in
  let printed =
    if shown then Printf.sprintf "%d %s" k line :: printed else printed
  in
  let last = if shown then line else last in
  if finished outcome.decision then List.rev printed
  else if ended then List.rev (Printf.sprintf "%d capture_ended" k :: printed)
  else run feed ~poll_us ~start loop (k + 1) last printed

let recover = function
  | npcs :: liveness :: start_us :: frame_us :: poll_us :: watchers :: tokens ->
      let frames = Array.of_list (captures (int_of_string watchers) tokens) in
      let count = Array.length frames in
      let feed =
        {
          frames;
          start_us = int_of_string start_us;
          frame_us = int_of_string frame_us;
          first = Array.make count 0;
          next = Array.make count 0;
        }
      in
      let start = float_of_int feed.start_us /. us in
      let config =
        {
          Blink_recovery.default_config with
          npcs = int_of_string npcs;
          liveness_timeout_seconds = int_of_string liveness;
        }
      in
      run feed ~poll_us:(int_of_string poll_us) ~start
        (Blink_recovery.start config ~watchers:count ~now:start)
        1 "" []
      |> List.map (fun line -> "\n  " ^ line)
      |> String.concat ""
  | _ -> failwith "recover: npcs liveness start frame poll watchers captures"

(* The expected text starts with the case's name, then one line per pass. *)
let without_name (r : Fixture_lines.record) =
  match String.index_opt r.expected '\n' with
  | Some at ->
      {
        r with
        expected = String.sub r.expected at (String.length r.expected - at);
      }
  | None -> { r with expected = "" }

let () =
  Fixture_lines.check_op (List.map without_name records) "recover" recover;
  Case_table.finish ()
