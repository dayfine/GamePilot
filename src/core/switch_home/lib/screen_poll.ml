type 'screen game_steps = { read_screen : unit -> 'screen; wait : int -> unit }
type 'screen outcome = Holds of 'screen | Timed_out of 'screen | Home_menu

let not_running = "the game is not running: the Switch HOME menu is showing"

let until steps ~at_ms ~home_menu ~poll_ms ~timeout_ms holds =
  let max_reads = (timeout_ms / poll_ms) + 1 in
  let rec poll ~start ~reads =
    let screen = steps.read_screen () in
    let reads = reads + 1 in
    let start = Option.value ~default:(at_ms screen) start in
    let elapsed = Float.max 0.0 (at_ms screen -. start) in
    if home_menu screen then Home_menu
    else if holds screen then Holds screen
    else if elapsed >= float_of_int timeout_ms || reads >= max_reads then
      Timed_out screen
    else (
      steps.wait poll_ms;
      poll ~start:(Some start) ~reads)
  in
  poll ~start:None ~reads:0
