module S = Delete_save_screen
module P = Switch_presses
module T = Timed_press

let ( let* ) = Result.bind

type game = { key : string; icon_png : string }

(* From HOME (the game closed, then 2 s) to the Delete Save Data list: Down to
   the icon row, Right held to its end (power), Left to the settings gear, A;
   Up held to the left list's top, Down 7 times to Data Management, A; Down
   held 3 s to the right pane's last item, Delete Save Data (quick taps drop
   there), A. *)
let after_close_ms = 2000
let data_management_downs = 7
let down : T.t = { button = Down; hold_ms = 80; cooldown_ms = 400 }

let to_list : T.t list =
  [
    down;
    { button = Right; hold_ms = 2500; cooldown_ms = 400 };
    { button = Left; hold_ms = 80; cooldown_ms = 500 };
    { button = A; hold_ms = 100; cooldown_ms = 2500 };
    { button = Up; hold_ms = 2000; cooldown_ms = 400 };
  ]
  @ T.times data_management_downs down
  @ [
      { button = A; hold_ms = 100; cooldown_ms = 1500 };
      { button = Down; hold_ms = 3000; cooldown_ms = 500 };
      { button = A; hold_ms = 100; cooldown_ms = 2500 };
    ]

(* A row: A opens its game's page; another game's, B back and Down to the next
   row. *)
let open_row : T.t = { button = A; hold_ms = 100; cooldown_ms = 2000 }

let next_row : T.t list =
  [
    { button = B; hold_ms = 100; cooldown_ms = 1500 };
    { button = Down; hold_ms = 80; cooldown_ms = 600 };
  ]

let max_rows = 6
let page_wait_ms = 2000

(* The page: A on "Delete Save Data for <user>" opens Caution, whose red button
   is greyed about 3 s; Up selects it. *)
let open_caution : T.t = { button = A; hold_ms = 100; cooldown_ms = 2000 }
let greyed_ms = 3000
let red_wait_ms = 5000
let select_red : T.t = { button = Up; hold_ms = 100; cooldown_ms = 600 }

(* Confirm: A on the red button, then OK on the success popup, then HOME. *)
let delete : T.t = { button = A; hold_ms = 100; cooldown_ms = 4000 }

let after_deleted : T.t list =
  [
    { button = A; hold_ms = 100; cooldown_ms = 1500 };
    { button = Home; hold_ms = 100; cooldown_ms = 2000 };
  ]

let red_check_ms = 1000
let deleted_wait_ms = 3000

let not_native =
  "delete-save reads System Settings on the whole frame: run the daemon with \
   --viewport native"

(* After A on a row: [Some true] on the game's page, [Some false] on another
   game's, [None] on no page. *)
let opened_page key =
  T.press open_row;
  let page m = if S.game_page m then Some (S.is_game key m) else None in
  Held_screen.wait_for ~timeout_ms:page_wait_ms page

let no_row key =
  Printf.sprintf
    "no row of the first %d is %s's; left on the list, nothing deleted" max_rows
    key

let no_page number =
  Printf.sprintf "row %d: A showed no game page; nothing deleted" number

(* Row [row] (from 0): opens it, and backs out to the next unless it is the
   game's. *)
let rec find_row ~log key row =
  let number = row + 1 in
  if row >= max_rows then Error (no_row key)
  else
    match opened_page key with
    | None -> Error (no_page number)
    | Some true -> Ok (log (Printf.sprintf "Row %d is %s." number key))
    | Some false ->
        log (Printf.sprintf "Row %d is another game." number);
        T.press_all next_row;
        find_row ~log key number

let caution_is c m = S.caution m = c

let selected_after_up ~log =
  T.press select_red;
  match Effects.read () with
  | Some m when caution_is Red_selected m ->
      log "On the red Delete Save Data button. Nothing deleted.";
      Ok ()
  | Some _ | None -> Error "Up did not select the red button; nothing deleted"

let select_red_button ~log =
  T.press open_caution;
  P.wait greyed_ms;
  match Effects.await ~timeout_ms:red_wait_ms (caution_is Red_not_selected) with
  | Timeout ->
      Error "the red Delete Save Data button stayed greyed; nothing deleted"
  | Holds _ -> selected_after_up ~log

let to_caution ~log ~picture tile game =
  if not (Picture_box.native picture) then Error not_native
  else
    let* () = Game_entry.close_game ~log ~picture tile in
    let icon = Effects.upload_template game.icon_png in
    let probes = S.icon_probe { key = game.key; icon } :: S.colour_probes in
    Effects.with_probes probes (fun () ->
        P.wait after_close_ms;
        T.press_all to_list;
        let* () = find_row ~log game.key 0 in
        select_red_button ~log)

let press_delete ~log =
  T.press delete;
  match Effects.await ~timeout_ms:deleted_wait_ms S.deleted with
  | Timeout ->
      Error "A on the red button, then no \"Successfully deleted save data.\""
  | Holds _ ->
      log "Successfully deleted save data.";
      T.press_all after_deleted;
      Ok ()

let on_red ~log =
  match Effects.await ~timeout_ms:red_check_ms (caution_is Red_selected) with
  | Timeout ->
      Error
        "not on the Caution screen with the red button selected; pressed \
         nothing"
  | Holds _ -> press_delete ~log

let confirm ~log ~picture =
  if not (Picture_box.native picture) then Error not_native
  else Effects.with_probes S.colour_probes (fun () -> on_red ~log)
