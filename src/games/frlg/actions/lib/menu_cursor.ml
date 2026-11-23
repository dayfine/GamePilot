open Frlg_readers
module M = Menu_input

let confirm_ms = 1000
let max_confirms = 3

type column = { what : string; read : Effects.measurements -> int option }

let start_menu =
  { what = "the Start menu's cursor"; read = Start_menu.cursor_row }

let party = { what = "the party's cursor"; read = Party_menu.selected_slot }

let member_menu =
  { what = "the member's menu cursor"; read = Member_menu.cursor_row }

module Steps = Frlg_menu_cursor.Cursor_steps

let move_to ~code column row =
  match Steps.step_to ~tap:(fun b -> M.taps b 1) column.read row with
  | Reached -> ()
  | Unread -> M.fail code (column.what ^ " did not show")
  | Stuck at ->
      M.fail code (Printf.sprintf "%s stayed on %d, not %d" column.what at row)

let confirm ~code what taken =
  M.press_until ~max_presses:max_confirms ~code what Wire.A
    ~cooldown_ms:confirm_ms taken

let choose ~code column row ~taken =
  move_to ~code column row;
  confirm ~code (column.what ^ " taken") taken

let start_menu_taken m =
  (not (Start_menu.start_menu_open m)) || Dialog.dialog_up m

let open_start_menu_row row =
  M.press_until ~max_presses:max_confirms ~code:"no_start_menu" "the Start menu"
    Wire.Start ~cooldown_ms:confirm_ms Start_menu.start_menu_open;
  choose ~code:"no_start_menu" start_menu row ~taken:start_menu_taken
