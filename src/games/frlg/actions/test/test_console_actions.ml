(* The actions the checkpoint runner takes on a console without save states:
   the soft reset back to the last save (Soft_reset) and the in-game save
   (Game_save, its screens decided by Save_dialog), on a scripted screen read
   through the FRLG readers from recorded mGBA frames (Scripted_screen). No
   Switch capture of the title, the load menu, the recap or the save's
   messages exists yet: docs/switch-bring-up.md lists the ones to take. *)

open Frlg_actions
open Frlg_overworld_fixtures
module S = Scripted_screen
module D = Save_dialog

let log = ignore

let outcome = function
  | Ok () -> "ok"
  | Error cause -> "failed " ^ Story.Failure.cause_to_string cause

let run_on ~react body =
  let screen = S.create ~react () in
  let result = S.run screen body in
  Printf.sprintf "%s; %s; ends on %s" (outcome result) (S.presses_text screen)
    (S.screen_name (S.screen_at screen screen.S.clock_ms))

(* {1 The soft reset} *)

let combo (p : S.press) = List.length p.buttons = 4

(* The reset shows black, then the title once the intro is past; A on the
   title shows the load menu; A on it (CONTINUE) black, then the recap; three
   B on the recap the overworld. [ignored] resets are not taken. *)
let game ?(ignored = 0) ?(menu_on_save = false) ?(title_answers = true)
    ?(black_after_ms = 200) () =
  let resets = ref 0 and recap_b = ref 0 in
  fun screen (p : S.press) ->
    let show d s = S.show screen ~at_ms:(p.at_ms + d) s in
    match (p.buttons, S.screen_at screen p.at_ms) with
    | _ when combo p ->
        incr resets;
        if !resets > ignored then (
          show 100 S.Black;
          show 3000 S.Title)
        else if menu_on_save then show 100 (S.Start_menu 4)
    | [ Wire.B ], S.Start_menu _ -> show 100 S.Overworld
    | [ Wire.A ], S.Start_menu _ -> show 100 S.Question
    | [ Wire.A ], S.Title when title_answers -> show 600 S.Load_menu
    | [ Wire.A ], S.Load_menu ->
        show black_after_ms S.Black;
        show (black_after_ms + 1300) S.Recap
    | [ Wire.B ], S.Recap ->
        incr recap_b;
        if !recap_b = 3 then show 300 S.Overworld
    | _ -> ()

let reset react = run_on ~react (fun () -> Soft_reset.return_to_save ~log ())

let reset_cases =
  [
    ( "soft reset: the combo, SELECT through the intro, A at the title, \
       CONTINUE, B over the recap, the overworld",
      (fun () -> reset (game ())),
      "ok; A+B+Select+Start 360, Select x15, A x3, B x14; ends on overworld" );
    ( "soft reset: console B's CONTINUE goes black after 3.6 s (2026-11-23)",
      (fun () -> reset (game ~black_after_ms:3600 ())),
      "ok; A+B+Select+Start 360, Select x15, A x3, B x14; ends on overworld" );
    ( "soft reset: a reset the game missed is tried again",
      (fun () -> reset (game ~ignored:1 ())),
      "ok; A+B+Select+Start 360, Select x15, A x3, A+B+Select+Start 360, \
       Select x15, A x3, B x14; ends on overworld" );
    ( "soft reset: a reset taken as START, the menu open on SAVE: B, never A, \
       and the next reset",
      (fun () -> reset (game ~ignored:1 ~menu_on_save:true ())),
      "ok; A+B+Select+Start 360, Select x15, B, A+B+Select+Start 360, Select \
       x15, A x3, B x14; ends on overworld" );
    ( "soft reset: no load menu in five attempts fails, repeating",
      (fun () -> reset (game ~title_answers:false ())),
      "failed soft_reset_failed: 5 attempts; the last: soft_reset_no_menu: the \
       load menu did not show; "
      ^ String.concat ", "
          (List.init 5 (fun _ -> "A+B+Select+Start 360, Select x15, A x3"))
      ^ "; ends on title" );
  ]

(* {1 The save dialog's decisions} *)

let steps screens =
  let _, actions =
    List.fold_left
      (fun (t, acc) s ->
        let t, a = D.next t s in
        (t, D.action_name a :: acc))
      (D.start, []) screens
  in
  String.concat ", " (List.rev actions)

let dialog_cases =
  [
    ( "save dialog: YES, the saving text, nothing twice: check the overworld",
      [ D.Yes_no; Text; Nothing; Nothing ],
      "answer yes, wait, wait, check overworld" );
    ( "save dialog: the overwrite question gets YES too",
      [ D.Yes_no; Text; Yes_no; Text; Nothing; Nothing ],
      "answer yes, wait, answer yes, wait, wait, check overworld" );
    ( "save dialog: one look at nothing is the frame between two boxes",
      [ D.Yes_no; Nothing; Text; Nothing; Nothing ],
      "answer yes, wait, wait, wait, check overworld" );
    ( "save dialog: a page after the last YES is a save error",
      [ D.Yes_no; Paged_text; Nothing; Nothing ],
      "answer yes, next page, wait, fail: save error" );
    ( "save dialog: a page before the next YES is not",
      [ D.Paged_text; Yes_no; Text; Nothing; Nothing ],
      "next page, answer yes, wait, wait, check overworld" );
    ( "save dialog: the Start menu back means a NO was taken",
      [ D.Yes_no; Start_menu ],
      "answer yes, fail: cancelled" );
  ]

(* {1 The save on a scripted screen} *)

(* START opens the menu (row 1), B on it closes it; A on SAVE asks; each YES
   asks again while [questions] remain, then shows the saving text for
   [saving_ms] and [after] (the overworld, or the menu back for a NO). *)
let save_game ?(questions = 2) ?(after = S.Overworld) ?(saving_ms = 2000) () =
  let asked = ref 0 in
  fun screen (p : S.press) ->
    let show d s = S.show screen ~at_ms:(p.at_ms + d) s in
    match (p.buttons, S.screen_at screen p.at_ms) with
    | [ Wire.Start ], _ -> show 100 (S.Start_menu 1)
    | [ Wire.B ], S.Start_menu _ -> show 100 S.Overworld
    | [ Wire.A ], (S.Start_menu _ | S.Question) when !asked < questions ->
        incr asked;
        show 100 S.Dialog;
        show 400 S.Question
    | [ Wire.A ], S.Question ->
        show 100 S.Dialog;
        show (100 + saving_ms) after
    | [ Wire.A ], S.Dialog_arrow -> show 100 S.Overworld
    | _ -> ()

let save react = run_on ~react (fun () -> Game_save.save_game ~log ())

let save_cases =
  [
    ( "save: the Start menu opens with the cursor on SAVE: SAVE read by its \
       name, no move",
      (fun () ->
        let rest = save_game () in
        save (fun screen p ->
            match (p.S.buttons, S.screen_at screen p.at_ms) with
            | [ Wire.Start ], S.Overworld ->
                S.show screen ~at_ms:(p.at_ms + 100) (S.Start_menu 4)
            | _ -> rest screen p)),
      "ok; Start, A x3, Start, B; ends on overworld" );
    ( "save: SAVE, YES, YES to overwrite, saved, START and B to confirm",
      (fun () -> save (save_game ())),
      "ok; Start, down x3, A x3, Start, B; ends on overworld" );
    ( "save: a first save has no overwrite question",
      (fun () -> save (save_game ~questions:1 ())),
      "ok; Start, down x3, A x2, Start, B; ends on overworld" );
    ( "save: the Start menu back after a YES fails as cancelled",
      (fun () -> save (save_game ~after:(S.Start_menu 4) ())),
      "failed save_cancelled: the START menu came back: the save was \
       cancelled; Start, down x3, A x3; ends on start menu row 4" );
    ( "save: a page after the last YES fails as a save error",
      (fun () -> save (save_game ~after:S.Dialog_arrow ())),
      "failed save_error: a message after the last YES: the save failed; \
       Start, down x3, A x4; ends on overworld" );
    ( "save: text that never ends fails after 30 s",
      (fun () -> save (save_game ~after:S.Dialog ())),
      "failed save_timeout: not back on the overworld 30 s after saving; \
       Start, down x3, A x3; ends on dialog" );
  ]

let () =
  Table_test.run "console actions"
    (List.map
       (fun (name, input, expectation) ->
         { Table_test.name; input; expectation })
       reset_cases
    @ List.map
        (fun (name, screens, expectation) ->
          { Table_test.name; input = (fun () -> steps screens); expectation })
        dialog_cases
    @ List.map
        (fun (name, input, expectation) ->
          { Table_test.name; input; expectation })
        save_cases)
