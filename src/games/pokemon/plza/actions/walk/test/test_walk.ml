(* PLZA's walk, scripted: the inputs it sends (angles to stick values, runs
   and their timing, L recentres) and how its screen reads end it, as the C++'s
   tests (PokemonLZA_AutoStoryActions_Tests.cpp) check them. *)

open Plza_walk
open Plza_rules.Walk_args

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

(* --- Walk_inputs --- *)

let stick ?(walk_only = false) pace duration_ms () =
  match
    Walk_inputs.tilt ~walk_only pace ~degrees:0.0 ~duration_ms ~release_ms:0
  with
  | Ok c -> input_text c
  | Error e -> e

let stick_cases =
  [
    case "a walk holds the stick for its time" (stick Walk 1000)
      "stick (0.00, 1.00) 1000/0";
    case "a run holds B with it, for its time over 1.65 (truncated)"
      (stick Run 1000) "B+stick (0.00, 1.00) 606/0";
    case "a run that walks only (before dash): the stick alone"
      (stick ~walk_only:true Run 1000)
      "stick (0.00, 1.00) 1000/0";
  ]

(* --- A scripted game: the screen reads in order, the last one repeated --- *)

let screen ?(still = false) ?(fade_black = false) ?(fade_white = false)
    ?(dialog = false) ?(arrow = false) ?(party = false) ?(hint = false)
    ?(home = false) ?(battle = false) ?(prompt = false) ?(scene = false) at_ms :
    Walk_screen.t =
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
    interact_prompt = prompt;
    scene_under_way = scene;
    battle;
    minimap_arrow = None;
  }

let platform at = screen ~hint:true at
let overworld at = screen ~party:true at

(* What the walk sent and logged, in order, and its outcome as [outcome] says
   it. *)
let recorded screens run outcome =
  let lines = ref [] and screens = ref screens in
  let say line = lines := line :: !lines in
  let next () =
    match !screens with
    | [ last ] -> last
    | l :: rest ->
        screens := rest;
        l
    | [] -> Walk_screen.empty ~at_ms:0.0
  in
  let steps : Walk.game_steps =
    {
      submit = (fun c -> say (input_text c));
      read_screen = (fun () -> next ());
      log = (fun line -> say ("log " ^ line));
      log_detail = (fun line -> say ("detail " ^ line));
    }
  in
  let ended = outcome (run steps) in
  String.concat "\n" (List.rev !lines @ [ ended ])

let result_text = function
  | Ok () -> "ok"
  | Error c -> Engine_run.Failure.cause_to_string c

(* What the walk sent and logged, in order, and its outcome. *)
let scripted screens run = recorded screens run result_text

(* The inputs alone, without the logs. *)
let inputs screens run =
  scripted screens run |> String.split_on_char '\n'
  |> List.filter (fun l -> not (String.starts_with ~prefix:"log " l))
  |> List.filter (fun l -> not (String.starts_with ~prefix:"detail " l))
  |> String.concat "\n"

let leg angle_deg walk_ms = { angle_deg; walk_ms }
let move ?(style = Face_then_walk) legs = { legs; style; wait_before_ms = 0 }

let walk_only_move ?style legs steps =
  Walk.play_legs steps ~walk_only:true (move ?style legs)

let running_move ?style legs steps =
  Walk.play_legs steps ~walk_only:false (move ?style legs)

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
          [ platform 0.0; screen ~still:true ~hint:true 1.0; platform 2.0 ]
          (walk_only_move [ leg 0.0 500 ]))
      "stick (0.00, 1.00) 500/0\n\
       log [PLZA] walk: the screen stayed still after the walk of leg 1/1 turn \
       0 walk 500 ms; once more\n\
       stick (0.00, 1.00) 500/0\n\
       ok";
    case "an angle alone, no walk: no stick held after it"
      (fun () -> inputs [ platform 0.0 ] (walk_only_move [ leg (-45.0) 0 ]))
      "L 100/150\nstick (-0.71, 0.71) 150/100\nL 100/150\nok";
    case
      "steered legs: each at its angle, L before an angled leg after the first"
      (fun () ->
        inputs
          [ platform 0.0 ]
          (walk_only_move ~style:Steer
             [ leg 30.0 500; leg 0.0 300; leg (-66.0) 600 ]))
      "stick (0.50, 0.87) 500/0\n\
       stick (0.00, 1.00) 300/0\n\
       L 100/150\n\
       stick (-0.91, 0.41) 600/0\n\
       ok";
  ]

(* --- walk_to_end --- *)

let until ?(earliest_end_ms = 0) ?(walk_only = true) ?(stop_on_battle = false)
    until legs steps =
  Walk.walk_to_end steps ~walk_only ~stop_on_battle "walk" (move legs) ~until
    ~earliest_end_ms

let hud at = screen ~battle:true ~party:true at
let white = Event Fade_white

let until_cases =
  [
    case "a white fade stops the last leg early (the C++'s first case)"
      (fun () ->
        scripted
          [ platform 0.0; platform 250.0; screen ~fade_white:true 500.0 ]
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
          [ platform 0.0; screen ~fade_white:true 250.0 ]
          (until ~walk_only:false white [ leg 0.0 500 ]))
      "B+stick (0.00, 1.00) 151/0\nok";
    case "the clock runs slower than the slices: held until the reads' time too"
      (fun () ->
        inputs
          [ platform 0.0; platform 100.0; platform 200.0; platform 400.0 ]
          (until white [ leg 0.0 500 ]))
      "stick (0.00, 1.00) 250/0\n\
       stick (0.00, 1.00) 250/0\n\
       stick (0.00, 1.00) 250/0\n\
       walk_no_end: walk: no end event within 550 ms of the last leg";
    case "an end event before earliest_end_ms: passed on the way, walk on"
      (fun () ->
        scripted
          [ screen ~fade_white:true 0.0; screen ~fade_white:true 250.0 ]
          (until ~earliest_end_ms:400 white [ leg 0.0 500 ]))
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
          [ screen ~fade_black:true 0.0 ]
          (until (Event Dialog) [ leg 0.0 500 ]))
      "stick (0.00, 1.00) 250/0\n\
       log [PLZA] walk: a black fade after 250 ms of the last leg: the scene \
       takes over.\n\
       ok";
    case "until a scene: the second busy read in a row stops the walk"
      (fun () ->
        scripted
          [ screen ~dialog:true 0.0; platform 250.0; screen ~arrow:true 500.0 ]
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
    case
      "a story battle ahead: the battle HUD on two reads in a row stops the \
       last leg (fork PR 725)"
      (fun () ->
        scripted
          [
            platform 0.0;
            platform 250.0;
            hud 500.0;
            platform 750.0;
            hud 1000.0;
            hud 1250.0;
          ]
          (until ~stop_on_battle:true white [ leg 0.0 3000 ]))
      "stick (0.00, 1.00) 250/0\n\
       stick (0.00, 1.00) 250/0\n\
       stick (0.00, 1.00) 250/0\n\
       stick (0.00, 1.00) 250/0\n\
       stick (0.00, 1.00) 250/0\n\
       log [PLZA] walk: battle HUD showed after 1250 ms of the last leg: \
       stopping walk.\n\
       battle_on_screen: battle on screen";
    case
      "a walk into a talk, a story battle ahead: the HUD on the last slice and \
       the read after the legs stops it"
      (fun () ->
        scripted
          [ platform 0.0; platform 250.0; hud 500.0; hud 750.0 ]
          (until ~stop_on_battle:true
             (Talk { after_legs = false })
             [ leg 0.0 250 ]))
      "stick (0.00, 1.00) 250/0\n\
       log [PLZA] walk: battle HUD showed after 250 ms of the last leg: \
       stopping walk.\n\
       battle_on_screen: battle on screen";
    case "no story battle ahead: the battle HUD does not stop the walk"
      (fun () ->
        inputs
          [ platform 0.0; hud 250.0; hud 500.0 ]
          (until white [ leg 0.0 500 ]))
      "stick (0.00, 1.00) 250/0\n\
       stick (0.00, 1.00) 250/0\n\
       walk_no_end: walk: no end event within 500 ms of the last leg";
    case "steered: the last leg sliced at its own angle, after its L"
      (fun () ->
        inputs
          [ screen ~fade_white:true 0.0 ]
          (fun steps ->
            Walk.walk_to_end steps ~walk_only:true ~stop_on_battle:false "walk"
              (move ~style:Steer [ leg 0.0 300; leg 90.0 500 ])
              ~until:white ~earliest_end_ms:0))
      "stick (0.00, 1.00) 300/0\nL 100/150\nstick (1.00, 0.00) 250/0\nok";
  ]

(* --- free control, and the walk event --- *)

let can_walk { Walk.submit; read_screen; log; _ } =
  Free_control_wait.wait
    (Free_control_wait.screen_game_steps ~submit ~read_screen ~log)
    "walk"

let reads_every_poll n make =
  List.init n (fun i -> make (float_of_int (i * 250)))

let step ?(until = None) ?(wait_before_ms = 0) ?(battle_ahead = false) legs
    steps =
  Walk.run_event steps ~walk_only:true ~battle_ahead "walk"
    {
      move = { (move legs) with wait_before_ms };
      until;
      earliest_end_ms = 0;
      heading_deg = None;
    }

let free_cases =
  [
    case "two reads of the party bar in a row: free control"
      (fun () -> inputs [ overworld 0.0; overworld 250.0 ] can_walk)
      "wait 250\nok";
    case "the HOME menu: game_not_running, which repeats"
      (fun () -> inputs [ screen ~home:true 0.0 ] can_walk)
      "game_not_running: the game is not running: the Switch HOME menu is \
       showing";
    case "a text box for 30 s: walk_not_free, naming it"
      (fun () ->
        let lines =
          inputs (reads_every_poll 200 (screen ~dialog:true)) can_walk
        in
        List.nth (String.split_on_char '\n' lines) 120)
      "walk_not_free: walk: no free control within 30000 ms, last on a text box";
    case "nothing busy and no sign of control for 10 s: taken as control"
      (fun () ->
        let lines =
          String.split_on_char '\n'
            (scripted
               (reads_every_poll 50 (fun at_ms -> Walk_screen.empty ~at_ms))
               can_walk)
        in
        String.concat "\n" (List.filteri (fun i _ -> i >= 40) lines))
      "log [PLZA] walk: nothing busy for 10000 ms and no sign of control; \
       taken as control.\n\
       ok";
    case "a walk event: its wait, free control, the legs, the read after"
      (fun () ->
        scripted
          [ overworld 0.0; overworld 250.0; overworld 500.0 ]
          (step ~wait_before_ms:800 [ leg 0.0 400 ]))
      "wait 800\n\
       wait 250\n\
       stick (0.00, 1.00) 400/0\n\
       log [PLZA] walk: legs done, screen now: player_can_move\n\
       ok";
    case "a walk event with an end: held until it"
      (fun () ->
        inputs
          [ overworld 0.0; overworld 250.0; screen ~fade_white:true 500.0 ]
          (step ~until:(Some white) [ leg 0.0 400 ]))
      "wait 250\nstick (0.00, 1.00) 250/0\nok";
    case
      "a story battle ahead, the battle HUD before the walk (two reads 250 ms \
       apart): no walk, battle_on_screen"
      (fun () ->
        inputs [ hud 0.0; hud 250.0 ] (step ~battle_ahead:true [ leg 0.0 400 ]))
      "wait 250\nbattle_on_screen: battle on screen";
    case
      "a story battle ahead, a walk that failed with the HUD flickering (never \
       two reads in a row): the HUD after it, battle_on_screen"
      (fun () ->
        inputs
          [
            overworld 0.0;
            overworld 250.0;
            hud 500.0;
            overworld 750.0;
            hud 1000.0;
            hud 1250.0;
          ]
          (step ~battle_ahead:true ~until:(Some white) [ leg 0.0 500 ]))
      "wait 250\n\
       stick (0.00, 1.00) 250/0\n\
       stick (0.00, 1.00) 250/0\n\
       wait 250\n\
       battle_on_screen: battle on screen";
    case "no story battle ahead, the same walk: walk_no_end"
      (fun () ->
        inputs
          [
            overworld 0.0;
            overworld 250.0;
            hud 500.0;
            overworld 750.0;
            hud 1000.0;
            hud 1250.0;
          ]
          (step ~until:(Some white) [ leg 0.0 500 ]))
      "wait 250\n\
       stick (0.00, 1.00) 250/0\n\
       stick (0.00, 1.00) 250/0\n\
       walk_no_end: walk: no end event within 500 ms of the last leg";
    case "a walk event without free control sends no stick"
      (fun () -> inputs [ screen ~home:true 0.0 ] (step [ leg 0.0 400 ]))
      "game_not_running: the game is not running: the Switch HOME menu is \
       showing";
  ]

(* --- A prompts --- *)

(* One fact of a scripted run: its last line, the lines that are an A press,
   or whether a line starts with [prefix]. *)
let last_line text = List.hd (List.rev (String.split_on_char '\n' text))

let a_presses text =
  String.split_on_char '\n' text
  |> List.filter (String.starts_with ~prefix:"A ")
  |> List.length |> string_of_int

let has_line prefix text =
  String.split_on_char '\n' text
  |> List.exists (String.starts_with ~prefix)
  |> string_of_bool

let talk_outcome = function
  | Some r -> result_text r
  | None -> "nothing started"

let talk screens =
  recorded screens
    (fun { Walk.submit; read_screen; log; log_detail } ->
      Talk_prompt.talk
        { submit; read_screen; log; log_detail }
        "walk" ~held_ms:0)
    talk_outcome

let prompt at = screen ~prompt:true at
let scene at = screen ~scene:true ~dialog:true at

let talk_cases =
  [
    case "a talk: A held 160 ms, released 240"
      (fun () -> List.hd (String.split_on_char '\n' (talk [ scene 0.0 ])))
      "A 160/240";
    case "a talk: a scene on two reads in a row has started it"
      (fun () -> last_line (talk [ prompt 0.0; scene 250.0; scene 500.0 ]))
      "ok";
    case "a talk started on the first A takes one A"
      (fun () -> a_presses (talk [ prompt 0.0; scene 250.0; scene 500.0 ]))
      "1";
    case "a talk: a scene on one read alone has not started it"
      (fun () ->
        a_presses
          (talk
             [
               scene 0.0;
               prompt 250.0;
               prompt 500.0;
               prompt 750.0;
               scene 1000.0;
               scene 1250.0;
             ]))
      "2";
    case "a talk: the prompt still up after three As is talk_no_scene"
      (fun () -> last_line (talk [ prompt 0.0 ]))
      "talk_no_scene: walk: the A prompt still up with nothing open after 3 \
       As: the game took none";
    case "a talk: the prompt still up takes three As in all"
      (fun () -> a_presses (talk [ prompt 0.0 ]))
      "3";
    case "a talk: the prompt gone with nothing open is nothing started"
      (fun () -> last_line (talk [ screen 0.0 ]))
      "nothing started";
  ]

(* One straight leg: two reads before it (no prompt), the check for a prompt
   already showing and the one the first input is checked against, then a read
   after each slice. *)
let prompt_end screens = scripted screens (until (Event Prompt) [ leg 0.0 500 ])
let before_legs = [ platform 0.0; platform 0.0 ]

let prompt_end_cases =
  [
    case "the prompt end: a steady prompt ends the walk"
      (fun () ->
        last_line (prompt_end (before_legs @ [ prompt 250.0; prompt 550.0 ])))
      "ok";
    case "the prompt end: the prompt read again 300 ms on"
      (fun () ->
        has_line "wait 300"
          (prompt_end (before_legs @ [ prompt 250.0; prompt 550.0 ])))
      "true";
    case "the prompt end: a prompt gone 300 ms on is walked past"
      (fun () ->
        has_line
          "log [PLZA] walk: the A prompt after 250 ms of the last leg went"
          (prompt_end (before_legs @ [ prompt 250.0; platform 500.0 ])))
      "true";
    case "the prompt end: a prompt that went never ends the walk"
      (fun () ->
        last_line (prompt_end (before_legs @ [ prompt 250.0; platform 500.0 ])))
      "walk_no_end: walk: no end event within 500 ms of the last leg";
    case "a straight walk to a prompt already showing: no stick"
      (fun () -> has_line "stick" (prompt_end [ prompt 0.0 ]))
      "false";
    case "a straight walk to a prompt already showing: logged"
      (fun () ->
        has_line "log [PLZA] walk: the A prompt shows before the walk"
          (prompt_end [ prompt 0.0 ]))
      "true";
    case "a straight walk to a prompt already showing: ok"
      (fun () -> last_line (prompt_end [ prompt 0.0 ]))
      "ok";
    case "a straight walk into a talk, the prompt already showing: A, no stick"
      (fun () ->
        has_line "stick"
          (scripted
             [ prompt 0.0; prompt 300.0; scene 600.0 ]
             (until (Talk { after_legs = false }) [ leg 0.0 500 ])))
      "false";
  ]

let prompt_free_cases =
  [
    case "free control: an A prompt held 1 s with nothing busy"
      (fun () -> last_line (scripted (reads_every_poll 8 prompt) can_walk))
      "ok";
    case "free control: an A prompt is logged as control"
      (fun () ->
        has_line
          "log [PLZA] walk: the A prompt held 1000 ms with nothing busy: \
           control."
          (scripted (reads_every_poll 8 prompt) can_walk))
      "true";
    case "free control: an A prompt under a text box is not control"
      (fun () ->
        has_line "log [PLZA] walk: the A prompt held"
          (scripted
             (reads_every_poll 8 (screen ~prompt:true ~dialog:true)
             @ [ overworld 2000.0 ])
             can_walk))
      "false";
  ]

let () =
  Table_test.run "plza_walk"
    (stick_cases @ move_cases @ until_cases @ free_cases @ talk_cases
   @ prompt_end_cases @ prompt_free_cases)
