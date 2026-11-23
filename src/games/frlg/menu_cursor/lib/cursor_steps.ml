type outcome = Reached | Unread | Stuck of int

let read_timeout_ms = 3000
let tap_timeout_ms = 400
let max_taps = 16

let current ~timeout_ms read =
  match Effects.await ~timeout_ms (fun m -> Option.is_some (read m)) with
  | Holds m -> read m
  | Timeout -> None

let tap_toward ~tap read ~at row =
  tap (if row > at then Wire.Down else Wire.Up);
  ignore
    (Effects.await ~timeout_ms:tap_timeout_ms (fun m -> read m <> Some at)
      : Effects.awaited)

let rec step ~timeout_ms ~tap read row taps =
  match current ~timeout_ms read with
  | None -> Unread
  | Some at when at = row -> Reached
  | Some at when taps >= max_taps -> Stuck at
  | Some at ->
      tap_toward ~tap read ~at row;
      step ~timeout_ms ~tap read row (taps + 1)

let step_to ?(timeout_ms = read_timeout_ms) ~tap read row =
  step ~timeout_ms ~tap read row 0
