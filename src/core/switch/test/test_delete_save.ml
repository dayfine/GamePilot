(* Deleting a game's save from System Settings (Delete_save), on a scripted
   console B (Scripted_home) whose screens
   are captures: to the red Caution button, and the confirm from there. *)

open Switch
module S = Scripted_home

type console = {
  rows : string array;  (** the list's games, top first, by key *)
  red_after : int option;  (** when the red button turns red; [None]: never *)
  deletes : bool;  (** A on the red button shows the success popup *)
}

let za_first = { rows = [| "plza" |]; red_after = Some 2500; deletes = true }

(* X on FireRed's tile opens the close popup, A closes it: HOME. A on HOME (the
   gear) opens System Settings; there the second A opens the list of games.
   Down moves down the list; A opens the row's page, B goes back; A on the
   page opens Caution, its button greyed until [red_after]; Up selects it. A
   on it shows the success popup, A there the list, HOME HOME. *)
let console c =
  let row = ref 0 and settings_as = ref 0 in
  fun t b screen ->
    let show after s = S.show t ~after s in
    match (b, screen) with
    | Wire.X, S.Home_fire_red_last -> show 300 S.Close_popup
    | Wire.A, S.Close_popup -> show 1000 S.Home_bdsp_last
    | Wire.A, S.Home_bdsp_last -> show 1000 S.Settings
    | Wire.A, S.Settings ->
        incr settings_as;
        if !settings_as = 2 then show 1000 S.Save_list
    | Wire.Down, S.Save_list -> row := min (!row + 1) (Array.length c.rows - 1)
    | Wire.A, S.Save_list -> show 800 (S.Page c.rows.(!row))
    | Wire.B, S.Page _ -> show 500 S.Save_list
    | Wire.A, S.Page _ ->
        show 500 S.Caution_greyed;
        Option.iter (fun ms -> show ms S.Caution_red) c.red_after
    | Wire.Up, S.Caution_red -> show 200 S.Caution_red_selected
    | Wire.A, S.Caution_red_selected when c.deletes -> show 1500 S.Deleted
    | Wire.A, S.Deleted -> show 500 S.Save_list
    | Wire.Home, S.Save_list -> show 1000 S.Home_bdsp_last
    | _ -> ()

let native : Wire.box = { x = 0.; y = 0.; w = 1.; h = 1. }

let run start c body () =
  S.play ~presses:S.presses_counted ~start (console c) (fun () ->
      match body () with Ok () -> "ok" | Error e -> "error: " ^ e)

let to_caution ?(picture = native) key () =
  Delete_save.to_caution ~log:ignore ~picture Fire_red.tile
    { key; icon_png = "png" }

let confirm () = Delete_save.confirm ~log:ignore ~picture:native

(* Close, then the presses to the list but its last A (counted with the A on
   the first row that follows it). *)
let to_list = "X x13, A, Down, Right, Left, A, Up, Down x7, A, Down"
let case name input expectation : Table_test.case = { name; input; expectation }

let () =
  Table_test.run "delete_save"
    [
      case "Z-A on the first row: to the red button, selected"
        (run S.Home_fire_red_last za_first (to_caution "plza"))
        ("ok; " ^ to_list ^ ", A x3, Up; ends on Caution (red selected)");
      case "Z-A on the third row: two other games' pages backed out of"
        (run S.Home_fire_red_last
           { za_first with rows = [| "violet"; "firered"; "plza" |] }
           (to_caution "plza"))
        ("ok; " ^ to_list
       ^ ", A x2, B, Down, A, B, Down, A x2, Up; ends on Caution (red selected)"
        );
      case "FireRed on the second row"
        (run S.Home_fire_red_last
           { za_first with rows = [| "plza"; "firered" |] }
           (to_caution "firered"))
        ("ok; " ^ to_list
       ^ ", A x2, B, Down, A x2, Up; ends on Caution (red selected)");
      case "no row is Z-A: six rows opened, left on the list"
        (run S.Home_fire_red_last
           { za_first with rows = [| "violet"; "firered" |] }
           (to_caution "plza"))
        ("error: no row of the first 6 is plza's; left on the list, nothing \
          deleted; " ^ to_list
       ^ ", A x2, B, Down, A, B, Down, A, B, Down, A, B, Down, A, B, Down, A, \
          B, Down; ends on the save data list");
      case "the red button stays greyed: no Up"
        (run S.Home_fire_red_last
           { za_first with red_after = None }
           (to_caution "plza"))
        ("error: the red Delete Save Data button stayed greyed; nothing \
          deleted; " ^ to_list ^ ", A x3; ends on Caution (greyed)");
      case "the GBA picture: refused before any press"
        (run S.Home_fire_red_last za_first
           (to_caution ~picture:Fire_red.nso_gba_picture "plza"))
        "error: delete-save reads System Settings on the whole frame: run the \
         daemon with --viewport native; no press; ends on HOME (FireRed last)";
      case "confirm on the red button: A, OK, HOME"
        (run S.Caution_red_selected za_first confirm)
        "ok; A x2, Home; ends on HOME (BDSP last)";
      case "confirm with Cancel selected: no press"
        (run S.Caution_red za_first confirm)
        "error: not on the Caution screen with the red button selected; \
         pressed nothing; no press; ends on Caution (Cancel selected)";
      case "confirm on the game's page: no press"
        (run (S.Page "plza") za_first confirm)
        "error: not on the Caution screen with the red button selected; \
         pressed nothing; no press; ends on plza's page";
      case "confirm, no success popup after A: one A"
        (run S.Caution_red_selected { za_first with deletes = false } confirm)
        "error: A on the red button, then no \"Successfully deleted save \
         data.\"; A; ends on Caution (red selected)";
    ]
