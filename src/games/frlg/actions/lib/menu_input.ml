open Frlg_readers

exception Action_failed of Story.Failure.cause

let fail ?repeats code detail =
  raise (Action_failed (Story.Failure.cause ?repeats code detail))

let probes =
  Scene_looks.probes @ Party_menu.probes @ Bag_screen.probes @ Money_box.probes

let run body =
  match Effects.with_probes probes body with
  | () -> Ok ()
  | exception Action_failed c -> Error c

let button_hold_ms = 160
let tap_hold_ms = 80
let tap_release_ms = 240
let screen_timeout_ms = 3000

let press ?(cooldown_ms = 0) button =
  ignore
    (Effects.submit
       [
         Wire.Press
           { buttons = [ button ]; hold_ms = button_hold_ms; cooldown_ms };
       ])

let hold ~hold_ms ~cooldown_ms button =
  Wire.Press { buttons = [ button ]; hold_ms; cooldown_ms }

let taps button n =
  let tap = hold ~hold_ms:tap_hold_ms ~cooldown_ms:tap_release_ms button in
  if n > 0 then ignore (Effects.submit (List.init n (fun _ -> tap)))

let moves ~from ~to_ =
  if to_ >= from then taps Wire.Down (to_ - from) else taps Wire.Up (from - to_)

let await_screen ?(timeout_ms = screen_timeout_ms) ~code what reader =
  match Effects.await ~timeout_ms reader with
  | Holds m -> m
  | Timeout -> fail code (what ^ " did not show")

let settle_back ~label ~log =
  match Scene_looks.settle Talk ~label ~battle_ends:false ~log with
  | Ok () -> ()
  | Error cause -> raise (Action_failed cause)

let max_pages = 8
let question m = Option.is_some (Dialog.yes_no_cursor m)
let page_or_question m = question m || Dialog.advance_arrow m
let question_input_ms = 300
let answer_cooldown_ms = 800

let answer_yes_to m =
  if Dialog.yes_no_cursor m = Some false then taps Wire.Up 1;
  ignore (Effects.submit [ Wire.Wait { wait_ms = question_input_ms } ]);
  press ~cooldown_ms:answer_cooldown_ms Wire.A

let page_press_ms = 600

let rec answer_yes_from page ~code what =
  let m = await_screen ~code what page_or_question in
  if question m then answer_yes_to m
  else if page > max_pages then fail code (what ^ " did not show")
  else (
    press ~cooldown_ms:page_press_ms Wire.A;
    answer_yes_from (page + 1) ~code what)

let answer_yes ~code what =
  Effects.with_probes Dialog.yes_no_probes (fun () ->
      answer_yes_from 1 ~code what)

let answer_if_asked ~timeout_ms () =
  match Effects.await ~timeout_ms question with
  | Holds m ->
      answer_yes_to m;
      true
  | Timeout -> false

let answer_yes_if_asked ~timeout_ms =
  Effects.with_probes Dialog.yes_no_probes (answer_if_asked ~timeout_ms)

let default_max_presses = 45

let press_until ?(max_presses = default_max_presses) ~code what button
    ~cooldown_ms reader =
  let presses =
    List.init max_presses (fun _ ->
        Wire.Press
          { buttons = [ button ]; hold_ms = button_hold_ms; cooldown_ms })
  in
  let holds = match Effects.read () with Some m -> reader m | None -> false in
  if not holds then
    match Effects.race presses ~stop:reader with
    | Stopped _ -> ()
    | Finished _ -> fail code (what ^ " did not show")

let dpad : Grid_maps.Direction.t -> Wire.button = function
  | North -> Up
  | South -> Down
  | East -> Right
  | West -> Left

let close_press_ms = 500

let close what reader =
  press_until ~code:"not_closed" (what ^ " closed") Wire.B
    ~cooldown_ms:close_press_ms (fun m -> not (reader m))
