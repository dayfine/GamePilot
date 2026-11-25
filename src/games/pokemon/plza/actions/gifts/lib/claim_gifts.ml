module G = Mystery_gift
module B = Gift_to_box

type span = { from : string; stop_at : string option; code_only : bool }
type step = { at : string; go : unit -> (unit, string) result }

let default_code = "CELEBRATE30TH"
let ( let* ) = Result.bind

let from_overworld ~log next () =
  let* _row = Menu_rows.open_menu ~log in
  next ~log

let close ~log ~picture ~tile () =
  log "Closing the game.";
  Switch_home.Game_entry.close_game ~log ~picture tile

let internet_steps ~log =
  [
    { at = "mystery-gift"; go = (fun () -> G.open_internet_list ~log) };
    { at = "gift-list"; go = (fun () -> G.choose_gift ~log) };
    { at = "card"; go = (fun () -> G.leave_card ~log) };
  ]

let code_steps ~log ~picture ~code =
  [
    { at = "code"; go = (fun () -> G.open_keyboard ~log) };
    { at = "keyboard"; go = (fun () -> G.claim_code ~log ~picture code) };
    { at = "code-card"; go = (fun () -> G.dismiss_card ~log) };
    { at = "disconnect"; go = (fun () -> Ok (G.disconnect ())) };
  ]

let box_steps ~log ~picture ~tile =
  [
    { at = "after-gifts"; go = from_overworld ~log B.to_boxes };
    { at = "boxes"; go = (fun () -> B.move_gift ~log) };
    { at = "moved"; go = (fun () -> B.open_save_prompt ~log) };
    { at = "save"; go = (fun () -> B.save ~log) };
    { at = "saved"; go = close ~log ~picture ~tile };
  ]

let steps ~log ~picture ~tile ~code ~code_only =
  { at = "overworld"; go = from_overworld ~log G.open_gifts }
  :: (if code_only then [] else internet_steps ~log)
  @ code_steps ~log ~picture ~code
  @ box_steps ~log ~picture ~tile

let points =
  [
    "overworld";
    "mystery-gift";
    "gift-list";
    "card";
    "code";
    "keyboard";
    "code-card";
    "disconnect";
    "after-gifts";
    "boxes";
    "moved";
    "save";
    "saved";
  ]

let rec drop_to at = function
  | [] -> []
  | s :: rest as all -> if s.at = at then all else drop_to at rest

let rec take_to stop = function
  | [] -> []
  | s :: rest -> if Some s.at = stop then [] else s :: take_to stop rest

let index name = List.find_index (String.equal name) points

let known name =
  if index name <> None then Ok ()
  else
    Error (Printf.sprintf "no point %s (%s)" name (String.concat ", " points))

let after_start span stop =
  if index stop > index span.from then Ok ()
  else
    Error
      (Printf.sprintf "the stop %s is not after the start %s" stop span.from)

let check span =
  let* () = known span.from in
  let* () = Option.fold ~none:(Ok ()) ~some:known span.stop_at in
  let* () = Option.fold ~none:(Ok ()) ~some:(after_start span) span.stop_at in
  if span.code_only && span.from <> "overworld" then
    Error "the code alone starts from the overworld"
  else Ok ()

let rec run_all = function
  | [] -> Ok ()
  | s :: rest ->
      let* () = s.go () in
      run_all rest

let chosen ~log ~picture ~tile ~code span =
  take_to span.stop_at
    (drop_to span.from
       (steps ~log ~picture ~tile ~code ~code_only:span.code_only))

(* The screen at a point, read with no press, where a reader knows it. *)
let read_at = function
  | "gift-list" -> Some G.await_list
  | "card" | "code-card" -> Some G.await_card
  | "keyboard" -> Some G.await_keyboard
  | _ -> None

let confirm ~log ~verb at =
  match read_at at with
  | Some read ->
      let* () = read () in
      Ok (log (Printf.sprintf "%s %s, read." verb at))
  | None -> Ok (log (Printf.sprintf "%s %s, not read (no reader yet)." verb at))

let stop ~log span =
  Option.fold ~none:(Ok ())
    ~some:(fun at ->
      Result.map_error
        (fun e -> Printf.sprintf "the stop %s did not show: %s" at e)
        (confirm ~log ~verb:"Stopped on" at))
    span.stop_at

let start ~log span =
  Result.map_error
    (fun e -> Printf.sprintf "the start %s does not show: %s" span.from e)
    (confirm ~log ~verb:"Starting on" span.from)

let run ~log ~picture ~assets ~gift_name ~tile ~span ~code =
  let* () = check span in
  Effects.with_probes (G.probes ~picture ~assets ~gift_name) (fun () ->
      Switch_home.Stick_wake.run ();
      let* () = start ~log span in
      let* () = run_all (chosen ~log ~picture ~tile ~code span) in
      stop ~log span)
