type target = Default | Ally | Foe_left | Foe_right

type event =
  | Action_menu
  | Switch_in
  | Move_learn
  | Use_next
  | Battle_over
  | Timed_out

type move_result =
  | Chosen
  | Refused
  | Other_move of string
  | Not_done of string

type item = {
  pocket : Frlg_readers.Bag_screen.pocket;
  row : int;
  on_slot : int option;
}

type t = {
  next_event : timeout_ms:int -> event;
  use_move : slot:int -> target:target -> expect:string option -> move_result;
  switch_to : slot:int -> bool;
  send_in : slot:int -> bool;
  run : unit -> unit;
  use_item : item -> bool;
  answer_move_learn : forget:int option -> unit;
  answer_use_next : bool -> unit;
}

let target_name = function
  | Default -> "default"
  | Ally -> "ally"
  | Foe_left -> "foe left"
  | Foe_right -> "foe right"

let event_name = function
  | Action_menu -> "action menu"
  | Switch_in -> "switch-in"
  | Move_learn -> "move learn"
  | Use_next -> "use next"
  | Battle_over -> "battle over"
  | Timed_out -> "timed out"
