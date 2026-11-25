type start = From_internet | From_code | From_boxes

let default_code = "CELEBRATE30TH"
let ( let* ) = Result.bind

let gifts ~log ~picture ~start ~code =
  let* () = Mystery_gift.open_gifts ~log in
  let* () =
    if start = From_internet then
      let* () = Mystery_gift.open_internet_list ~log in
      Mystery_gift.claim_internet ~log
    else Ok ()
  in
  let* () = Mystery_gift.claim_code ~log ~picture code in
  Mystery_gift.disconnect ();
  Ok ()

let to_box_and_close ~log ~picture ~tile =
  let* () = Gift_to_box.move_and_save ~log in
  log "Saved. Closing the game.";
  Switch_home.Game_entry.close_game ~log ~picture tile

let stop_on_list ~log =
  let* _row = Menu_rows.open_menu ~log in
  let* () = Mystery_gift.open_gifts ~log in
  let* () = Mystery_gift.open_internet_list ~log in
  log "Stopped on the Internet gift list; nothing claimed.";
  Ok ()

let steps ~log ~picture ~tile ~start ~stop_at_list ~code =
  if stop_at_list && start = From_internet then stop_on_list ~log
  else if stop_at_list then Error "the stop on the gift list needs the start"
  else
    let* _row = Menu_rows.open_menu ~log in
    let* () =
      if start = From_boxes then Ok () else gifts ~log ~picture ~start ~code
    in
    to_box_and_close ~log ~picture ~tile

let run ~log ~picture ~assets ~tile ~start ~stop_at_list ~code =
  Effects.with_probes (Mystery_gift.probes ~picture ~assets) (fun () ->
      steps ~log ~picture ~tile ~start ~stop_at_list ~code)
