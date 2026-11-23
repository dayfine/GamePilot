type t = {
  ms_per_tile : Direction.t -> run:bool -> int;
  start_ms : int;
  tap_ms : int;
  press_ms : int;
  stop_ms : int;
  open_hold_error : (int -> int) option;
}
