(* The leg walker's bookkeeping, its holds answered by a scripted handler
   whose frames show an interrupt at scripted times. Ported from the fork's
   Pokemon_LegWalker_Tests.cpp, case by case, with the walker's log lines and
   leg record added. *)

open Grid_maps
open Grid_walker

let tile_ms = 267
let delay_ms = 300

(* An interrupt set off by step [step], seen [delay_ms] after it ends. *)
let after_step step = Some ((tile_ms * step) + delay_ms)

let button_of : Direction.t -> Wire.button = function
  | North -> Up
  | East -> Right
  | South -> Down
  | West -> Left

let mover direction hold_ms =
  [ Wire.press ~hold_ms ~cooldown_ms:0 [ button_of direction ] ]

(* The scripted interrupt: a wild battle unless [kind] says otherwise (a sign's
   message is a [Dialogue]). *)
let walker ?tracer ?(kind = Grid_trace.Leg_record.Interrupt.Wild_battle) world
    log : Leg_walker.t =
  let battle : Leg_interrupt.t =
    {
      name = (if kind = Wild_battle then "a battle" else "a message");
      kind;
      seen = Scripted_interrupts.showing;
      detection_delay_ms = delay_ms;
      clear = (fun () -> Scripted_interrupts.clear world);
    }
  in
  { mover; interrupts = [ battle ]; log; tracer }

let result_text (r : Leg_spec.result) =
  Printf.sprintf "tiles %d, exact %b, interruptions %d, stopped %b" r.tiles
    r.exact r.interruptions r.stopped

(* Walks [leg] with an interrupt showing at [script]'s times, one per hold;
   what the holds, clears, result and log were, a line each. *)
let walked ?max_interruptions ?hold_watchers ?kind script leg =
  let world = Scripted_interrupts.create script in
  let lines = ref [] in
  let log line = lines := line :: !lines in
  let outcome =
    match
      Scripted_interrupts.run world (fun () ->
          Leg_walker.walk_leg ?max_interruptions ?hold_watchers
            (walker ?kind world log) leg)
    with
    | r -> result_text r
    | exception Leg_walker.Interrupted_too_often why -> "failed: " ^ why
  in
  String.concat "\n"
    ([
       "holds " ^ String.concat ", " (List.rev_map string_of_int world.holds_ms);
       Printf.sprintf "cleared %d" world.cleared;
       outcome;
     ]
    @ List.rev !lines)

let open_leg ?(tile_ms = tile_ms) direction tiles =
  Leg_spec.make ~tile_ms direction tiles

let wall_leg ?(tile_ms = tile_ms) direction tiles =
  Leg_spec.make ~to_wall:true ~tile_ms direction tiles

let hold_times () =
  let stalled = { (open_leg East 4) with stalled_steps = [ 2 ] } in
  Printf.sprintf "open 4: %d; wall 4: %d; stall on 2: %d, %d, %d"
    (Leg_timing.hold_ms (open_leg East 4) 4)
    (Leg_timing.hold_ms (wall_leg East 4) 4)
    (Leg_timing.hold_ms stalled 4)
    (Leg_timing.hold_ms stalled 3)
    (Leg_timing.hold_ms stalled 2)

(* Every step 0..8, seen 100ms early, on time and late, read back. *)
let tiles_before_interrupt () =
  let leg = open_leg East 8 in
  let read elapsed_ms remaining =
    Leg_timing.tiles_before_interrupt leg ~elapsed_ms
      ~detection_delay_ms:delay_ms ~remaining
  in
  let misread =
    List.concat_map
      (fun step ->
        List.filter_map
          (fun jitter ->
            let walked = read ((tile_ms * step) + delay_ms + jitter) 8 in
            if walked = step then None
            else Some (Printf.sprintf "step %d %+dms as %d" step jitter walked))
          [ -100; 0; 100 ])
      (List.init 9 Fun.id)
  in
  Printf.sprintf "misread: [%s]; before the leg: %d; past the rest: %d"
    (String.concat "; " misread)
    (read 50 8)
    (read (tile_ms * 20) 3)

(* A watcher along the hold fires on its 3rd frame and never stops the hold. *)
let watch_along () =
  let frames = ref 0 in
  let along =
    Watch_along.create (fun _ ->
        incr frames;
        !frames = 3)
  in
  let walk = walked ~hold_watchers:[ along ] [] (open_leg North 2) in
  Printf.sprintf "%s\nfired %b after %d frames" walk (Watch_along.fired along)
    !frames

(* The leg record of an open leg interrupted once: both holds' time and the
   battle, as the tracer's open leg collects them. *)
let traced_leg () =
  let lines = ref [] in
  let tracer = Grid_trace.Leg_tracer.create (fun l -> lines := l :: !lines) in
  Grid_trace.Leg_tracer.begin_event tracer ~checkpoint:"03.01"
    ~event:"to_the_grass";
  Grid_trace.Leg_tracer.begin_leg tracer
    (Grid_trace.Leg_record.plan North 6 Open);
  let world = Scripted_interrupts.create [ after_step 2 ] in
  ignore
    (Scripted_interrupts.run world (fun () ->
         Leg_walker.walk_leg (walker ~tracer world ignore) (open_leg North 6))
      : Leg_spec.result);
  Grid_trace.Leg_tracer.end_leg tracer [] Dead_reckoned;
  String.concat "\n" (List.rev !lines)

(* After a leg: a battle the last step set off shows 100ms into the watch, then
   nothing does. *)
let late_interrupts () =
  let world = Scripted_interrupts.create ~late:[ Some 100; None ] [] in
  let lines = ref [] in
  let cleared =
    Scripted_interrupts.run world (fun () ->
        Leg_walker.clear_late_interrupts
          (walker world (fun l -> lines := l :: !lines))
          ~watch_ms:1000)
  in
  String.concat "\n"
    (Printf.sprintf "cleared %d, clock %dms" cleared world.clock_ms
    :: List.rev !lines)

let blocked ?tile_ms ?(kind = Grid_trace.Leg_record.Interrupt.Dialogue) script
    tiles =
  walked ~kind script
    { (wall_leg ?tile_ms South tiles) with stop_if_blocked = true }

let cases : Table_test.case list =
  [
    {
      name = "hold times";
      input = hold_times;
      expectation = "open 4: 934; wall 4: 1602; stall on 2: 1201, 934, 400";
    };
    {
      name = "tiles before an interrupt";
      input = tiles_before_interrupt;
      expectation = "misread: []; before the leg: 0; past the rest: 3";
    };
    {
      name = "a wall leg is walked again";
      input = (fun () -> walked [ after_step 2 ] (wall_leg North 6));
      expectation =
        "holds 2136, 2136\n\
         cleared 1\n\
         tiles 6, exact true, interruptions 1, stopped false\n\
         Leg: a battle after 834ms, walking to the wall again.";
    };
    {
      name = "an open leg walks the rest";
      input = (fun () -> walked [ after_step 2 ] (open_leg North 6));
      expectation =
        "holds 1468, 934\n\
         cleared 1\n\
         tiles 6, exact false, interruptions 1, stopped false\n\
         Leg: a battle after 834ms, about 2 tiles walked, 4 to go.";
    };
    {
      name = "an open leg interrupted at its end";
      input = (fun () -> walked [ after_step 6 ] (open_leg North 6));
      expectation =
        "holds 1468\n\
         cleared 1\n\
         tiles 6, exact false, interruptions 1, stopped false\n\
         Leg: a battle after 1902ms, about 6 tiles walked, 0 to go.";
    };
    {
      name = "gives up after too many interruptions";
      input =
        (fun () ->
          walked ~max_interruptions:3
            (List.init 4 (fun _ -> after_step 0))
            (wall_leg North 6));
      expectation =
        "holds 2136, 2136, 2136, 2136\n\
         cleared 3\n\
         failed: Interrupted 4 times on: north 6 (to wall)\n\
         Leg: a battle after 300ms, walking to the wall again.\n\
         Leg: a battle after 300ms, walking to the wall again.\n\
         Leg: a battle after 300ms, walking to the wall again.";
    };
    {
      name = "an open leg stops at an interrupt";
      input =
        (fun () ->
          walked
            [ after_step 2 ]
            { (open_leg North 6) with stop_on_interrupt = true });
      expectation =
        "holds 1468\n\
         cleared 1\n\
         tiles 2, exact false, interruptions 1, stopped true\n\
         Leg: a battle after 834ms, about 2 of 6 tiles walked, stopping the \
         leg.";
    };
    {
      (* Held south into a sign: its message shows 600ms into every hold. *)
      name = "a wall leg blocked by a sign stops";
      input = (fun () -> blocked [ Some 2200; Some 600; Some 600 ] 23);
      expectation =
        "holds 6675, 6675\n\
         cleared 2\n\
         tiles 0, exact false, interruptions 2, stopped true\n\
         Leg: a message after 2200ms, walking to the wall again.\n\
         Leg: a message after 600ms, stopping the leg.";
    };
    {
      (* Running, a tile takes 133ms, and the sign spoke 353 to 726ms into
         each hold (Switch, 2026-11-13 18:29, 12.03 pallet_shore). *)
      name = "a wall leg blocked by a sign stops, running";
      input =
        (fun () -> blocked ~tile_ms:133 [ Some 353; Some 578; Some 603 ] 6);
      expectation =
        "holds 1064, 1064\n\
         cleared 2\n\
         tiles 0, exact false, interruptions 2, stopped true\n\
         Leg: a message after 353ms, walking to the wall again.\n\
         Leg: a message after 578ms, stopping the leg.";
    };
    {
      (* Held north into a sign two tiles short of the leg's end: its message
         shows at once on every hold (mGBA, 2026-11-23, mg-04's north 2 into
         Lavender Town's sign). *)
      name = "an open leg blocked by a sign stops";
      input =
        (fun () ->
          walked ~kind:Dialogue
            [ Some 217; Some 83; Some 83 ]
            { (open_leg ~tile_ms:133 North 2) with stop_if_blocked = true });
      expectation =
        "holds 199, 199\n\
         cleared 2\n\
         tiles 0, exact false, interruptions 2, stopped true\n\
         Leg: a message after 217ms, about 0 tiles walked, 2 to go.\n\
         Leg: a message after 83ms, about 0 of 2 tiles walked, stopping the \
         leg.";
    };
    {
      (* Two wild battles soon after each other on a wall leg through grass
         are luck, not a sign in the way: the leg is walked on (Switch,
         2026-11-24, mg-05a's return_to_route8_grass, battles 431 and 657ms
         into the holds). *)
      name = "a wall leg with wild battles one after another walks on";
      input =
        (fun () ->
          blocked ~kind:Wild_battle ~tile_ms:133 [ Some 431; Some 657; None ] 4);
      expectation =
        "holds 798, 798, 798\n\
         cleared 2\n\
         tiles 4, exact true, interruptions 2, stopped false\n\
         Leg: a battle after 431ms, walking to the wall again.\n\
         Leg: a battle after 657ms, walking to the wall again.";
    };
    {
      name = "a watcher along a hold never stops it";
      input = watch_along;
      expectation =
        "holds 400\n\
         cleared 0\n\
         tiles 2, exact true, interruptions 0, stopped false\n\
         fired true after 3 frames";
    };
    {
      name = "holds and interrupts go to the leg record";
      input = traced_leg;
      expectation =
        {|[Leg] {"checkpoint":"03.01","chunks":0,"dir":"north","end":[],"end_kind":"open","event":"to_the_grass","interrupts":["wild_battle"],"known":"dead_reckoned","leg":1,"ms":1768,"planned_end":[],"tiles":6}|};
    };
    {
      name = "an interrupt after the leg is cleared";
      input = late_interrupts;
      expectation =
        "cleared 1, clock 1100ms\nLeg: a battle at the end of the leg.";
    };
  ]

let () = Table_test.run "leg walker" cases
