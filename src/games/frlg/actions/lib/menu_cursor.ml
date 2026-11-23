open Frlg_readers
module M = Menu_input

let tap_timeout_ms = 400
let max_taps = 16
let confirm_ms = 1000
let max_confirms = 3

type column = { what : string; read : Effects.measurements -> int option }

let start_menu =
  { what = "the Start menu's cursor"; read = Start_menu.cursor_row }

let party = { what = "the party's cursor"; read = Party_menu.selected_slot }

let member_menu =
  { what = "the member's menu cursor"; read = Member_menu.cursor_row }

let current ~code column =
  let m =
    M.await_screen ~code column.what (fun m -> Option.is_some (column.read m))
  in
  Option.get (column.read m)

(* One tap toward the row, then the read row must change: a tap the game did
   not take (a menu still sliding or fading in) leaves it, and the next step
   taps again. *)
let tap_toward column ~at row =
  M.taps (if row > at then Wire.Down else Wire.Up) 1;
  ignore
    (Effects.await ~timeout_ms:tap_timeout_ms (fun m ->
         column.read m <> Some at))

let rec step ~code column row taps =
  let at = current ~code column in
  if at = row then ()
  else if taps >= max_taps then
    M.fail code (Printf.sprintf "%s stayed on %d, not %d" column.what at row)
  else (
    tap_toward column ~at row;
    step ~code column row (taps + 1))

let move_to ~code column row = step ~code column row 0

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
