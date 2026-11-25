open Frlg_readers
module Card = Trainer_card_front

type game_steps = {
  open_card : unit -> unit;
  look : unit -> Card.t option;
  wait : int -> unit;
  now_ms : unit -> float;
  close_card : unit -> unit;
  log : string -> unit;
}

let read_timeout_ms = Trainer_card_money.read_timeout_ms
let reread_ms = 300

(* A look counts once the next one agrees: the card's palette fades in, and a
   half-faded frame must not stand as the read. *)
let rec settled steps ~deadline previous =
  let look = steps.look () in
  match (look, previous) with
  | Some card, Some before when card = before -> Some card
  | _ when steps.now_ms () > deadline -> None
  | _ ->
      steps.wait reread_ms;
      settled steps ~deadline look

let read_with steps =
  steps.open_card ();
  let card =
    settled steps ~deadline:(steps.now_ms () +. float read_timeout_ms) None
  in
  steps.log
    (match card with
    | Some c -> "Trainer Card: " ^ Card.to_string c ^ "."
    | None -> "Trainer Card: the badges did not read.");
  steps.close_card ();
  card

let wait ms =
  ignore (Effects.submit [ Wire.Wait { wait_ms = ms } ] : Wire.batch_done)

let look () = Option.bind (Effects.read ()) Card.read

let console_game_steps ~log =
  {
    open_card =
      (fun () -> Menu_cursor.open_start_menu_row Trainer_card_money.player_row);
    look;
    wait;
    now_ms = Effects.now;
    close_card = (fun () -> Trainer_card_money.close ~log);
    log;
  }

let read ~log =
  Effects.with_probes Card.probes (fun () ->
      read_with (console_game_steps ~log))
