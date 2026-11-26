module K = Switch_home.Code_keyboard

type game_steps = Switch_home.Keyboard_typing.game_steps

let english_key_column = 3
let bottom_character_row = 3
let tries = 16
let hold_ms = 80
let move_release_ms = 300
let a_release_ms = 400
let unread_wait_ms = 300

let press (steps : game_steps) button release_ms =
  steps.submit [ Wire.press ~hold_ms ~cooldown_ms:release_ms [ button ] ]

let above_english_key =
  { K.row = bottom_character_row; col = english_key_column }

(* On the bottom character row, at or left of the English key's column: down
   onto the bottom row, right to the English key, A, then up onto "v". *)
let press_english_key (steps : game_steps) (from : K.key) =
  press steps Wire.Down move_release_ms;
  List.iter
    (fun _ -> press steps Wire.Right move_release_ms)
    (List.init (english_key_column - from.col) Fun.id);
  steps.log "AutoStory intro: keyboard: English (letters) key: A.";
  press steps Wire.A a_release_ms;
  press steps Wire.Up move_release_ms;
  match steps.read_cursor () with
  | Some k when k = above_english_key -> Ok ()
  | _ ->
      Error
        "the keyboard's cursor did not read on \"v\" after the English \
         (letters) key's A."

let not_reached =
  "the keyboard's cursor did not reach the English (letters) key."

let rec go (steps : game_steps) attempt =
  if attempt >= tries then Error not_reached
  else
    let step button =
      press steps button move_release_ms;
      go steps (attempt + 1)
    in
    match steps.read_cursor () with
    | None ->
        steps.submit [ Wire.Wait { wait_ms = unread_wait_ms } ];
        go steps (attempt + 1)
    | Some k when k.col > english_key_column -> step Wire.Left
    | Some k when k.row < bottom_character_row -> step Wire.Down
    | Some k -> press_english_key steps k

let switch steps = go steps 0
