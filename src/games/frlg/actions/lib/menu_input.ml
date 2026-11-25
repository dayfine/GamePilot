open Frlg_readers

exception Action_failed of Pokemon_checkpoints.Failure.cause

let fail ?repeats code detail =
  raise (Action_failed (Pokemon_checkpoints.Failure.cause ?repeats code detail))

let raise_error = function
  | Ok () -> ()
  | Error cause -> raise (Action_failed cause)

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

let mash button ms = taps button (ms / (tap_hold_ms + tap_release_ms))

let moves ~from ~to_ =
  if to_ >= from then taps Wire.Down (to_ - from) else taps Wire.Up (from - to_)

let await_screen ?(timeout_ms = screen_timeout_ms) ~code what reader =
  match Effects.await ~timeout_ms reader with
  | Holds m -> m
  | Timeout -> fail code (what ^ " did not show")

let settle_back ~label ~log =
  raise_error (Scene_looks.settle Talk ~label ~battle_ends:false ~log)

module Fade_in = Frlg_overworld.Warp_fade_in

(* A menu's close: its fade out, the black, the dim spell, the steps up and
   the still spell after them take about 2 s (110 frames). *)
let fade_in_timeout_ms = 5000

let await_fade_in ~code what =
  let watch = Fade_in.watch () in
  let came_up m =
    Fade_in.watch_frame watch m;
    Fade_in.came_up watch
  in
  ignore (await_screen ~timeout_ms:fade_in_timeout_ms ~code what came_up)

(* The menus a party read goes through: none has a box or a fade the settle's
   look tells from the overworld. *)
let party_menus m =
  Party_menu.party_menu m
  || Option.is_some (Member_menu.cursor_row m)
  || Option.is_some (Summary_screen.page m)

let settle_menu_closed ~label ~log () =
  Scene_looks.settle ~menu_open:party_menus ~await_fade_in:true Menu_closed
    ~label ~battle_ends:false ~log

let close_to_overworld ~label ~log =
  raise_error
    (Effects.with_probes
       (Member_menu.probes @ Summary_screen.probes)
       (settle_menu_closed ~label ~log))

let max_pages = 8
let question m = Option.is_some (Dialog.yes_no_cursor m)
let question_input_ms = 300
let answer_cooldown_ms = 800

let answer_yes_to m =
  if Dialog.yes_no_cursor m = Some false then taps Wire.Up 1;
  ignore (Effects.submit [ Wire.Wait { wait_ms = question_input_ms } ]);
  press ~cooldown_ms:answer_cooldown_ms Wire.A

let page_press_ms = 600

(* One look, one move: Screen_state.Choice_talk on the FRLG readers. *)
let choice_look ~taken m : Screen_state.Choice_talk.look =
  { choice = question m; page = Dialog.advance_arrow m; past_choice = taken m }

let rec answer_yes_from page ~code ~taken what =
  let move m =
    Screen_state.Choice_talk.move ~pressed:(page > 1) (choice_look ~taken m)
  in
  let m = await_screen ~code what (fun m -> move m <> Wait) in
  match move m with
  | Pick -> answer_yes_to m
  | Answered | Wait -> ()
  | Next_page when page > max_pages -> fail code (what ^ " did not show")
  | Next_page ->
      press ~cooldown_ms:page_press_ms Wire.A;
      answer_yes_from (page + 1) ~code ~taken what

let answer_yes ~code ~taken what =
  Effects.with_probes Dialog.yes_no_probes (fun () ->
      answer_yes_from 1 ~code ~taken what)

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
