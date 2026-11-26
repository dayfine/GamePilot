type target = Default | Ally | Foe_left | Foe_right

type event =
  | Action_menu
  | Switch_in
  | Level_up
  | Move_learn
  | Evolution
  | Use_next
  | Switch_offer
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

type game_steps = {
  next_event : timeout_ms:int -> event;
  use_move : slot:int -> target:target -> expect:string option -> move_result;
  switch_to : slot:int -> bool;
  send_in : slot:int -> bool;
  run : unit -> unit;
  use_item : item -> bool;
  level_up : Level_up.game_steps;
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
  | Level_up -> "level up"
  | Move_learn -> "move learn"
  | Evolution -> "evolution"
  | Use_next -> "use next"
  | Switch_offer -> "switch offer"
  | Battle_over -> "battle over"
  | Timed_out -> "timed out"
