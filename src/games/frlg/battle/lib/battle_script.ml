type command =
  | Move of { slot : int; target : Battle.target; name : string option }
  | Switch of int
  | Item of Battle.item
  | Run

type fallback =
  | Attack of { slots : int list; target : Battle.target }
  | Flee
  | Stop

type send_in = { slot : int; then_ : fallback option }

type t = {
  opening : command list;
  fallback : fallback;
  send_ins : send_in list;
  switch_refused : fallback option;
  learn : Battle.learn;
  use_next : bool;
  max_menus : int;
  event_timeout_ms : int;
}

let default_max_menus = 40
let default_event_timeout_ms = 60_000

let make ?(opening = []) ?(send_ins = []) ?switch_refused
    ?(learn = Battle.Keep_moves) ?(use_next = false)
    ?(max_menus = default_max_menus)
    ?(event_timeout_ms = default_event_timeout_ms) fallback =
  {
    opening;
    fallback;
    send_ins;
    switch_refused;
    learn;
    use_next;
    max_menus;
    event_timeout_ms;
  }

let describe_command = function
  | Move { slot; target; name } ->
      Printf.sprintf "move %d (%s%s)" slot
        (Battle.target_name target)
        (match name with Some n -> ", " ^ n | None -> "")
  | Switch slot -> Printf.sprintf "switch to %d" slot
  | Item { row; on_slot; _ } ->
      Printf.sprintf "item row %d%s" row
        (match on_slot with Some s -> Printf.sprintf " on %d" s | None -> "")
  | Run -> "run"
