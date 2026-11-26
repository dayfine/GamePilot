module S = Steps

type t = { steps : S.game_steps; mutable end_ms : float }

let start steps = { steps; end_ms = steps.S.now () }
let read_hold_ms = 1000
let read_before_end_ms = 400.
let flick_ms = 150
let stick x y = match Wire.stick x y with Ok s -> Some s | Error _ -> None

let hold t ~ms ~right_x ~left_y =
  t.steps.S.queue
    [
      Wire.press ?left_stick:(stick 0. left_y) ?right_stick:(stick right_x 0.)
        ~hold_ms:ms ~cooldown_ms:0 [ Wire.ZL ];
    ];
  t.end_ms <- Float.max t.end_ms (t.steps.S.now ()) +. float_of_int ms

let read t =
  hold t ~ms:read_hold_ms ~right_x:0. ~left_y:0.;
  t.steps.S.wait_until (t.end_ms -. read_before_end_ms);
  t.steps.S.read_lock_target ()

let wait_for_plate t ~limit_ms =
  let until = t.steps.S.now () +. float_of_int limit_ms in
  let rec go () =
    match read t with
    | Some _ as target -> target
    | None when t.steps.S.now () >= until -> None
    | None -> go ()
  in
  go ()

let flick t x =
  hold t ~ms:flick_ms ~right_x:x ~left_y:0.;
  read t
