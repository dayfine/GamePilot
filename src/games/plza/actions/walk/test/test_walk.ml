(* PLZA's walk, scripted: the inputs it sends (angles to stick values, runs
   and their timing, L recentres) and how its looks end it, as the C++'s
   PokemonLZA_AutoStoryActions_Tests and its fake backend check them. *)

open Plza_walk
open Plza_terms.Walk_args

let case name input expectation = { Table_test.name; input; expectation }

(* A tilt to two places; a rounded -0.00 is 0.00. *)
let tilt v = if Float.abs v < 0.005 then "0.00" else Printf.sprintf "%.2f" v

let input_text : Wire.command -> string = function
  | Wait { wait_ms } -> Printf.sprintf "wait %d" wait_ms
  | Press { buttons; left_stick; hold_ms; cooldown_ms; _ } ->
      let stick =
        Option.map
          (fun s ->
            let x, y = (s : Wire.stick :> float * float) in
            Printf.sprintf "stick (%s, %s)" (tilt x) (tilt y))
          left_stick
      in
      let parts =
        List.map Wire.string_of_button buttons @ Option.to_list stick
      in
      Printf.sprintf "%s %d/%d" (String.concat "+" parts) hold_ms cooldown_ms

(* --- Stick_input --- *)

let position degrees () =
  match Stick_input.position degrees with
  | Ok s ->
      let x, y = (s : Wire.stick :> float * float) in
      Printf.sprintf "(%s, %s)" (tilt x) (tilt y)
  | Error e -> e

let stick ?(walk_only = false) pace duration_ms () =
  match
    Stick_input.stick ~walk_only pace ~degrees:0.0 ~duration_ms ~release_ms:0
  with
  | Ok c -> input_text c
  | Error e -> e

let stick_cases =
  [
    case "0 degrees: straight on, up" (position 0.0) "(0.00, 1.00)";
    case "90 degrees: right" (position 90.0) "(1.00, 0.00)";
    case "-90 degrees: left" (position (-90.0)) "(-1.00, 0.00)";
    case "180 degrees: back, down" (position 180.0) "(0.00, -1.00)";
    case "-66 degrees: (sin, cos)" (position (-66.0)) "(-0.91, 0.41)";
    case "a walk holds the stick for its time" (stick Walk 1000)
      "stick (0.00, 1.00) 1000/0";
    case "a run holds B with it, for its time over 1.65 (truncated)"
      (stick Run 1000) "B+stick (0.00, 1.00) 606/0";
    case "a run that walks only (before dash): the stick alone"
      (stick ~walk_only:true Run 1000)
      "stick (0.00, 1.00) 1000/0";
  ]

(* --- A scripted game: the looks in order, the last one repeated --- *)

let look ?(still = false) ?(fade_black = false) ?(fade_white = false)
    ?(dialog = false) ?(arrow = false) ?(party = false) ?(hint = false)
    ?(home = false) at_ms : Walk_look.t =
  {
    at_ms;
    home_menu = home;
    screen_still = still;
    fade_black;
    fade_white;
    dialog_box = dialog;
    advance_arrow = arrow;
    player_can_move = party;
    controls_hint = hint;
  }

let platform at = look ~hint:true at
let overworld at = look ~party:true at

(* What the walk sent and logged, in order, and its outcome. *)
let scripted looks run =
  let lines = ref [] and looks = ref looks in
  let say line = lines := line :: !lines in
  let next () =
    match !looks with
    | [ last ] -> last
    | l :: rest ->
        looks := rest;
        l
    | [] -> Walk_look.nothing ~at_ms:0.0
  in
  let steps : Walk.game_steps =
    {
      submit = (fun c -> say (input_text c));
      look = (fun () -> next ());
      log = (fun line -> say ("log " ^ line));
      log_detail = (fun line -> say ("detail " ^ line));
    }
  in
  let outcome =
    match run steps with
    | Ok () -> "ok"
    | Error c -> Engine_run.Failure.cause_to_string c
  in
  String.concat "\n" (List.rev !lines @ [ outcome ])

(* The inputs alone, without the logs. *)
let inputs looks run =
  scripted looks run |> String.split_on_char '\n'
  |> List.filter (fun l -> not (String.starts_with ~prefix:"log " l))
  |> List.filter (fun l -> not (String.starts_with ~prefix:"detail " l))
  |> String.concat "\n"

let leg turn walk_ms = { turn; walk_ms }
let move ?(style = Turn_then_walk) legs = { legs; style; wait_first_ms = 0 }

let walk_only_move ?style legs steps =
  Walk.run_story_move steps ~walk_only:true (move ?style legs)

let running_move ?style legs steps =
  Walk.run_story_move steps ~walk_only:false (move ?style legs)

let platform_legs = [ leg 0.0 4500; leg 90.0 10000 ]

let move_cases =
  [
    case
      "01.01's legs, walking: walk, then L, a 150 ms tilt right and L, then \
       walk"
      (fun () -> inputs [ platform 0.0 ] (walk_only_move platform_legs))
      "stick (0.00, 1.00) 4500/0\n\
       L 100/150\n\
       stick (1.00, 0.00) 150/100\n\
       L 100/150\n\
       stick (0.00, 1.00) 10000/0\n\
       ok";
    case "the same legs, running: B with the stick, the times over 1.65"
      (fun () -> inputs [ platform 0.0 ] (running_move platform_legs))
      "B+stick (0.00, 1.00) 2727/0\n\
       L 100/150\n\
       stick (1.00, 0.00) 150/100\n\
       L 100/150\n\
       B+stick (0.00, 1.00) 6060/0\n\
       ok";
    case "the screen stayed still after a walk: played once more, logged"
      (fun () ->
        scripted
          [ platform 0.0; look ~still:true ~hint:true 1.0; platform 2.0 ]
          (walk_only_move [ leg 0.0 500 ]))
      "stick (0.00, 1.00) 500/0\n\
       log [PLZA] walk: the screen stayed still after the walk of leg 1/1 turn \
       0 walk 500 ms; once more\n\
       stick (0.00, 1.00) 500/0\n\
       ok";
    case "a turn alone, no walk: no stick held after it"
      (fun () -> inputs [ platform 0.0 ] (walk_only_move [ leg (-45.0) 0 ]))
      "L 100/150\nstick (-0.71, 0.71) 150/100\nL 100/150\nok";
    case "held legs: each at its angle, L before a turned leg after the first"
      (fun () ->
        inputs
          [ platform 0.0 ]
          (walk_only_move ~style:Held
             [ leg 30.0 500; leg 0.0 300; leg (-66.0) 600 ]))
      "stick (0.50, 0.87) 500/0\n\
       stick (0.00, 1.00) 300/0\n\
       L 100/150\n\
       stick (-0.91, 0.41) 600/0\n\
       ok";
  ]

(* --- walk_until --- *)

let until ?(end_after_ms = 0) ?(walk_only = true) until legs steps =
  Walk.walk_until steps ~walk_only "walk" (move legs) ~until ~end_after_ms

let white = Event Fade_white

let until_cases =
  [
    case "a white fade stops the last leg early (the C++'s first case)"
      (fun () ->
        scripted
          [ platform 0.0; platform 250.0; look ~fade_white:true 500.0 ]
          (until white [ leg 0.0 500; leg 90.0 1000 ]))
      "stick (0.00, 1.00) 500/0\n\
       L 100/150\n\
       stick (1.00, 0.00) 150/100\n\
       L 100/150\n\
       stick (0.00, 1.00) 250/0\n\
       log [PLZA] walk: the end event after 250 ms of the last leg.\n\
       detail [PLZA] walk: ended on: fade_white\n\
       ok";
    case "no end event once the budget is spent: walk_no_end (the C++'s second)"
      (fun () ->
        inputs
          [ platform 0.0; platform 250.0; platform 500.0 ]
          (until white [ leg 0.0 250 ]))
      "stick (0.00, 1.00) 250/0\n\
       walk_no_end: walk: no end event within 250 ms of the last leg";
    case "the last leg in 250 ms slices, the rest of the budget last"
      (fun () ->
        inputs
          [
            platform 0.0;
            platform 250.0;
            platform 500.0;
            platform 700.0;
            platform 800.0;
          ]
          (until white [ leg 0.0 700 ]))
      "stick (0.00, 1.00) 250/0\n\
       stick (0.00, 1.00) 250/0\n\
       stick (0.00, 1.00) 200/0\n\
       walk_no_end: walk: no end event within 700 ms of the last leg";
    case "slices run with B, each its time over 1.65"
      (fun () ->
        inputs
          [ platform 0.0; look ~fade_white:true 250.0 ]
          (until ~walk_only:false white [ leg 0.0 500 ]))
      "B+stick (0.00, 1.00) 151/0\nok";
    case "the clock runs slower than the slices: held until the looks' time too"
      (fun () ->
        inputs
          [ platform 0.0; platform 100.0; platform 200.0; platform 400.0 ]
          (until white [ leg 0.0 500 ]))
      "stick (0.00, 1.00) 250/0\n\
       stick (0.00, 1.00) 250/0\n\
       stick (0.00, 1.00) 250/0\n\
       walk_no_end: walk: no end event within 550 ms of the last leg";
    case "an end event before end_after_ms: passed on the way, walk on"
      (fun () ->
        scripted
          [ look ~fade_white:true 0.0; look ~fade_white:true 250.0 ]
          (until ~end_after_ms:400 white [ leg 0.0 500 ]))
      "stick (0.00, 1.00) 250/0\n\
       log [PLZA] walk: the end event after 250 ms of the last leg, before its \
       400 ms: passed on the way, on.\n\
       stick (0.00, 1.00) 250/0\n\
       log [PLZA] walk: the end event after 500 ms of the last leg.\n\
       detail [PLZA] walk: ended on: fade_white\n\
       ok";
    case "a black fade ends a walk to a dialog: the scene takes over"
      (fun () ->
        scripted
          [ look ~fade_black:true 0.0 ]
          (until (Event Dialog) [ leg 0.0 500 ]))
      "stick (0.00, 1.00) 250/0\n\
       log [PLZA] walk: a black fade after 250 ms of the last leg: the scene \
       takes over.\n\
       ok";
    case "until a scene: the second busy look in a row stops the walk"
      (fun () ->
        scripted
          [ look ~dialog:true 0.0; platform 250.0; look ~arrow:true 500.0 ]
          (until Scene [ leg 0.0 2000 ]))
      "stick (0.00, 1.00) 250/0\n\
       stick (0.00, 1.00) 250/0\n\
       stick (0.00, 1.00) 250/0\n\
       log [PLZA] walk: a scene (text waiting for A) took control after 750 ms \
       of the last leg: the walk stops.\n\
       ok";
    case "until a scene, control free all along: walk_no_scene"
      (fun () ->
        inputs [ platform 0.0; platform 250.0 ] (until Scene [ leg 0.0 500 ]))
      "stick (0.00, 1.00) 250/0\n\
       stick (0.00, 1.00) 250/0\n\
       walk_no_scene: walk: control still free after 500 ms of the last leg: \
       no scene took it";
    case "held: the last leg sliced at its own angle, after its L"
      (fun () ->
        inputs
          [ look ~fade_white:true 0.0 ]
          (fun steps ->
            Walk.walk_until steps ~walk_only:true "walk"
              (move ~style:Held [ leg 0.0 300; leg 90.0 500 ])
              ~until:white ~end_after_ms:0))
      "stick (0.00, 1.00) 300/0\nL 100/150\nstick (1.00, 0.00) 250/0\nok";
  ]

(* --- free control, and the walk event --- *)

let can_walk steps =
  Free_control.check_can_walk
    {
      look = steps.Walk.look;
      wait = (fun ms -> steps.submit (Stick_input.wait ms));
      log = steps.log;
    }
    "walk"

let looks_every_poll n make =
  List.init n (fun i -> make (float_of_int (i * 250)))

let step ?(until = None) ?(wait_first_ms = 0) legs steps =
  Walk.walk_step steps ~walk_only:true "walk"
    { move = { (move legs) with wait_first_ms }; until; end_after_ms = 0 }

let free_cases =
  [
    case "two looks of the party bar in a row: free control"
      (fun () -> inputs [ overworld 0.0; overworld 250.0 ] can_walk)
      "wait 250\nok";
    case "the HOME menu: game_not_running, which repeats"
      (fun () -> inputs [ look ~home:true 0.0 ] can_walk)
      "game_not_running: the game is not running: the Switch HOME menu is \
       showing";
    case "a text box for 30 s: walk_not_free, naming it"
      (fun () ->
        let lines =
          inputs (looks_every_poll 200 (look ~dialog:true)) can_walk
        in
        List.nth (String.split_on_char '\n' lines) 120)
      "walk_not_free: walk: no free control within 30000 ms, last on a text box";
    case "nothing busy and no sign of control for 10 s: taken as control"
      (fun () ->
        let lines =
          String.split_on_char '\n'
            (scripted
               (looks_every_poll 50 (fun at_ms -> Walk_look.nothing ~at_ms))
               can_walk)
        in
        String.concat "\n" (List.filteri (fun i _ -> i >= 40) lines))
      "log [PLZA] walk: nothing busy for 10000 ms and no sign of control; \
       taken as control.\n\
       ok";
    case "a walk event: its wait, free control, the legs, the look after"
      (fun () ->
        scripted
          [ overworld 0.0; overworld 250.0; overworld 500.0 ]
          (step ~wait_first_ms:800 [ leg 0.0 400 ]))
      "wait 800\n\
       wait 250\n\
       stick (0.00, 1.00) 400/0\n\
       log [PLZA] walk: legs done, screen now: player_can_move\n\
       ok";
    case "a walk event with an end: held until it"
      (fun () ->
        inputs
          [ overworld 0.0; overworld 250.0; look ~fade_white:true 500.0 ]
          (step ~until:(Some white) [ leg 0.0 400 ]))
      "wait 250\nstick (0.00, 1.00) 250/0\nok";
    case "a walk event without free control sends no stick"
      (fun () -> inputs [ look ~home:true 0.0 ] (step [ leg 0.0 400 ]))
      "game_not_running: the game is not running: the Switch HOME menu is \
       showing";
  ]

let () =
  Table_test.run "plza_walk"
    (stick_cases @ move_cases @ until_cases @ free_cases)
