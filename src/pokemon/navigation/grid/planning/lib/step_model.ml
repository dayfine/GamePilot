type 'state t = {
  compare_state : 'state -> 'state -> int;
  press : 'state -> Direction.t -> 'state Leg.step option;
  held_at : 'state -> Direction.t -> bool;
  open_stop_risk : ('state -> Direction.t -> int) option;
  tap_stop_risk : ('state -> Direction.t -> int option) option;
  open_check_risk :
    ('state -> Direction.t -> run:int -> next:Direction.t option -> int) option;
}

let max_counted_run = 3

let simple ~compare_state ~press ~held_at =
  {
    compare_state;
    press;
    held_at;
    open_stop_risk = None;
    tap_stop_risk = None;
    open_check_risk = None;
  }
