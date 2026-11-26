(* Screen_graph (Graph.path, Graph.check) and Screen_walk (go_to, take) tested
   on toy menu graphs with fake_game_steps feeding scripted candidate-screen
   reads and recording submitted buttons. *)

open Screen_graph

type screen =
  | Menu of int
  | List_item of int
  | Confirm_exit
  | Confirm_save
  | Card
  | Done_msg

let show = function
  | Menu r -> Printf.sprintf "Menu(%d)" r
  | List_item k -> Printf.sprintf "List(%d)" k
  | Confirm_exit -> "Confirm_exit"
  | Confirm_save -> "Confirm_save"
  | Card -> "Card"
  | Done_msg -> "Done_msg"

let press b : Wire.command list =
  [
    Press
      {
        buttons = [ b ];
        left_stick = None;
        right_stick = None;
        hold_ms = 80;
        cooldown_ms = 200;
      };
  ]

let edge ?(arrive = Graph.Held 1000) ?(kind = Graph.Transit) button leads_to :
    screen Graph.edge =
  { input = press button; leads_to; arrive; within_ms = 3000; kind }

let toy_screens =
  [
    Menu 0;
    Menu 1;
    Menu 2;
    Menu 3;
    List_item 0;
    List_item 1;
    Confirm_exit;
    Confirm_save;
    Card;
    Done_msg;
  ]

let toy_edges = function
  | Menu r ->
      let next = (r + 1) mod 4 and prev = (r + 3) mod 4 in
      let base =
        [
          edge ~arrive:First_read Down (Menu next);
          edge ~arrive:First_read Up (Menu prev);
        ]
      in
      if r = 2 then edge A (List_item 0) :: base else base
  | List_item k ->
      [
        edge ~arrive:First_read Down (List_item ((k + 1) mod 2));
        edge B Confirm_exit;
        edge ~kind:(Acts "claim") A Card;
      ]
  | Confirm_exit -> [ edge A (Menu 2) ]
  | Confirm_save -> [ edge ~kind:(Acts "save") A Done_msg; edge B (Menu 0) ]
  | Card -> [ edge B (List_item 0) ]
  | Done_msg -> [ edge A (Menu 0) ]

let make_graph ?(when_unread = Graph.Fail) ?(screens = toy_screens)
    ?(edges = toy_edges) ?(home = Menu 0) () : screen Graph.t =
  {
    name = "toy";
    probes = [];
    read = (fun _ -> []);
    edges;
    screens;
    home;
    when_unread;
    show;
    describe = (fun _ -> "frame");
  }

let button_of_cmds cmds =
  String.concat "+"
    (List.filter_map
       (function
         | Wire.Press { buttons = b :: _; _ } -> Some (Wire.string_of_button b)
         | _ -> None)
       cmds)

let run_walk ?(when_unread = Graph.Fail) ?(max_hops = 40) ~reads ~at () =
  let g = make_graph ~when_unread () in
  let remaining = ref reads in
  let sent = ref [] in
  let fake_game_steps : screen Screen_walk.game_steps =
    {
      read_screen =
        (fun ~hold_ms ~within_ms:_ ->
          match !remaining with
          | r :: rest ->
              remaining := rest;
              let _ = hold_ms in
              r
          | [] -> []);
      describe_last = (fun () -> "last-frame");
      send = (fun cmds -> sent := button_of_cmds cmds :: !sent);
      log = ignore;
    }
  in
  let res = Screen_walk.go_to ~max_hops g fake_game_steps ~at in
  let out =
    match res with
    | Ok s -> "ok:" ^ show s
    | Error e -> "err:" ^ Screen_walk.failure_to_string g e
  in
  let presses = String.concat "," (List.rev !sent) in
  out ^ " [" ^ presses ^ "]"

let run_take ~reads ~from act () =
  let g = make_graph () in
  let remaining = ref reads in
  let sent = ref [] in
  let fake_game_steps : screen Screen_walk.game_steps =
    {
      read_screen =
        (fun ~hold_ms:_ ~within_ms:_ ->
          match !remaining with
          | r :: rest ->
              remaining := rest;
              r
          | [] -> []);
      describe_last = (fun () -> "last-frame");
      send = (fun cmds -> sent := button_of_cmds cmds :: !sent);
      log = ignore;
    }
  in
  let res = Screen_walk.take g fake_game_steps ~from act in
  let out =
    match res with
    | Ok s -> "ok:" ^ show s
    | Error e -> "err:" ^ Screen_walk.failure_to_string g e
  in
  out ^ " [" ^ String.concat "," (List.rev !sent) ^ "]"

let path_str g ~from ~at () =
  match Graph.path g ~from ~at with
  | None -> "none"
  | Some es ->
      String.concat ","
        (List.map (fun (e : _ Graph.edge) -> show e.leads_to) es)

let check_str g () =
  match Graph.check g with Ok () -> "ok" | Error e -> "err:" ^ e

let case name input expectation : Table_test.case = { name; input; expectation }

let () =
  let g = make_graph () in
  Table_test.run "screen_graph"
    [
      case "check passes on valid toy graph" (check_str g) "ok";
      case "check rejects missing home"
        (check_str (make_graph ~screens:[ Menu 1 ] ()))
        "err:toy: home screen Menu(0) is not in screens";
      case "check rejects edge leading outside screens"
        (check_str
           (make_graph ~screens:[ Menu 0; Menu 1 ]
              ~edges:(function
                | Menu 0 -> [ edge A (Menu 2) ] | _ -> [ edge B (Menu 0) ])
              ()))
        "err:toy: edge from Menu(0) leads to Menu(2), which is not in screens";
      case "check rejects screen that cannot reach home via Transit"
        (check_str
           (make_graph ~screens:[ Menu 0; Card ]
              ~edges:(function
                | Card -> [ edge ~kind:(Acts "exit") A (Menu 0) ] | _ -> [])
              ()))
        "err:toy: screen Card cannot reach home (Menu(0)) via Transit edges";
      case "check rejects duplicate act names on one screen"
        (check_str
           (make_graph ~screens:[ Menu 0; Card ]
              ~edges:(function
                | Menu 0 ->
                    [
                      edge ~kind:(Acts "go") A Card;
                      edge ~kind:(Acts "go") B Card;
                    ]
                | Card -> [ edge B (Menu 0) ]
                | _ -> [])
              ()))
        "err:toy: duplicate act \"go\" on screen Menu(0)";
      case "path finds shortest wrap-around route"
        (path_str g ~from:(Menu 0) ~at:(Graph.exactly (Menu 3)))
        "Menu(3)";
      case "path never traverses Acts edge"
        (path_str g ~from:(List_item 0) ~at:(Graph.exactly Card))
        "none";
      case "go_to walks shortest path"
        (run_walk
           ~reads:[ [ Menu 0 ]; [ Menu 1 ]; [ Menu 2 ]; [ List_item 0 ] ]
           ~at:(Graph.exactly (List_item 0)))
        "ok:List(0) [Down,Down,A]";
      case "go_to retries on lost press"
        (run_walk
           ~reads:[ [ Menu 0 ]; [ Menu 0 ]; [ Menu 3 ] ]
           ~at:(Graph.exactly (Menu 3)))
        "ok:Menu(3) [Up,Up]";
      case "go_to replans when landing elsewhere"
        (run_walk
           ~reads:[ [ Menu 0 ]; [ Menu 2 ]; [ List_item 0 ] ]
           ~at:(Graph.exactly (List_item 0)))
        "ok:List(0) [Down,A]";
      case "go_to settles look-alike screen using expected hop destination"
        (run_walk
           ~reads:
             [ [ List_item 0 ]; [ Confirm_exit; Confirm_save ]; [ Menu 2 ] ]
           ~at:(Graph.exactly (Menu 2)))
        "ok:Menu(2) [B,A]";
      case "go_to treats ambiguous first read as unread"
        (run_walk
           ~reads:[ [ Confirm_exit; Confirm_save ] ]
           ~at:(Graph.exactly (Menu 0)))
        "err:toy: screen unread (last-frame) []";
      case "go_to when_unread Press recovers when screen appears"
        (run_walk
           ~when_unread:(Press (press B))
           ~reads:[ []; []; [ Menu 0 ] ] ~at:(Graph.exactly (Menu 0)))
        "ok:Menu(0) [B,B]";
      case "go_to when_unread Press fails after 3 consecutive unread reads"
        (run_walk
           ~when_unread:(Press (press B))
           ~reads:[ []; []; []; [] ] ~at:(Graph.exactly (Menu 0)))
        "err:toy: screen unread (last-frame) [B,B,B]";
      case "go_to fails Out_of_hops when budget exhausted"
        (run_walk ~max_hops:2
           ~reads:[ [ Menu 0 ]; [ Menu 0 ]; [ Menu 0 ] ]
           ~at:(Graph.exactly (Menu 3)))
        "err:toy: out of hops on Menu(0) [Up,Up]";
      case "go_to fails No_path when only Acts edge reaches target"
        (run_walk ~reads:[ [ List_item 0 ] ] ~at:(Graph.exactly Card))
        "err:toy: no path from List(0) []";
      case "take acts when source holds and returns any known screen"
        (run_take
           ~reads:[ [ List_item 0 ]; [ Done_msg ] ]
           ~from:(List_item 0) "claim")
        "ok:Done_msg [A]";
      case "take fails Not_on when source does not hold"
        (run_take ~reads:[ [ List_item 1 ] ] ~from:(List_item 0) "claim")
        "err:toy: expected List(0) before acting (last-frame) []";
      case "take fails No_path for unknown act name"
        (run_take ~reads:[ [ List_item 0 ] ] ~from:(List_item 0) "missing")
        "err:toy: no path from List(0) []";
    ]
