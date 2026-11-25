(* Closing FireRed and starting it from a HOME tile (Game_entry, the fork's
   NintendoSwitch_GameEntry steps), on a scripted console B (Scripted_home)
   whose screens are captures. *)

open Switch_home
module S = Scripted_home

(* X on a running FireRed's tile opens the close popup (later X there do
   nothing), A on it closes FireRed: HOME, BDSP played last. With FireRed
   closed, X does nothing. Right from BDSP's tile goes to FireRed's; A there
   opens the user select, A there boots it: black, then the intro. *)
let console ?(running = true) () =
  let running = ref running in
  fun t b screen ->
    let show after s = S.show t ~after s in
    match (b, screen) with
    | Wire.X, S.Home_fire_red_last when !running -> show 300 S.Close_popup
    | Wire.A, S.Close_popup ->
        running := false;
        show 1000 S.Home_bdsp_last
    | Wire.Right, S.Home_bdsp_last -> show 200 S.Home_on_fire_red
    | Wire.A, S.Home_on_fire_red -> show 800 S.User_select
    | Wire.A, S.User_select ->
        show 300 S.Black;
        show 4000 S.Intro
    | _ -> ()

let picture = Fire_red.nso_gba_picture

(* The presses, runs of one button counted. *)
let presses_text t =
  let rec runs acc = function
    | [] -> List.rev acc
    | b :: rest -> (
        match acc with
        | (b', n) :: acc' when b = b' -> runs ((b, n + 1) :: acc') rest
        | _ -> runs ((b, 1) :: acc) rest)
  in
  match runs [] (List.rev t.S.presses) with
  | [] -> "no press"
  | l ->
      String.concat ", "
        (List.map
           (fun (b, n) -> if n = 1 then b else Printf.sprintf "%s x%d" b n)
           l)

let run start react body () =
  let t = S.create ~start react in
  let outcome =
    S.run t (fun () ->
        match body () with Ok () -> "ok" | Error e -> "error: " ^ e)
  in
  Printf.sprintf "%s; %s; ends on %s" outcome (presses_text t)
    (S.screen_name (S.screen_at t t.S.clock_ms))

let close () = Game_entry.close_game ~log:ignore ~picture Fire_red.tile

let start ~game_slot () =
  Game_entry.start_game ~log:ignore ~picture ~game_slot ~user_slot:0
    Fire_red.tile

let case name input expectation : Table_test.case = { name; input; expectation }

let () =
  Table_test.run "game_entry"
    [
      case "close: X opens the popup, A closes FireRed, HOME"
        (run S.Home_fire_red_last (console ()) close)
        "ok; X x13, A; ends on HOME (BDSP last)";
      case
        "close: already closed, X twice finds no popup (Down x3 and HOME \
         between)"
        (run S.Home_bdsp_last (console ~running:false ()) close)
        "ok; X x13, Down x3, Home x2, X x13; ends on HOME (BDSP last)";
      case "close: never HOME, an error after its rounds"
        (run S.Game (fun _ _ _ -> ()) close)
        "error: Unable to find Switch Home; Home x10; ends on game";
      case
        "start: B until HOME, HOME and Right to tile 2, A, A on the user \
         select, until its black"
        (run S.Home_bdsp_last (console ()) (start ~game_slot:2))
        "ok; B x4, Home, Right, A x2; ends on black";
      case "start: tile 0 starts the cursor's tile"
        (run S.Home_on_fire_red (console ()) (start ~game_slot:0))
        "ok; B x4, A x2; ends on black";
    ]
