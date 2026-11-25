type 'inner state = { inner : 'inner; gates : Gate_state.t }
type Leg.special_step += Open_gate | Press_switch

type rules = {
  card_key_held : bool;
  open_gate_cost : int;
  press_switch_cost : int;
}

let default_rules =
  { card_key_held = false; open_gate_cost = 10; press_switch_cost = 20 }

type 'inner game = {
  compare_inner : 'inner -> 'inner -> int;
  press : 'inner -> Direction.t -> Gate_state.t -> 'inner Leg.step option;
  held_at : 'inner -> Direction.t -> Gate_state.t -> bool;
  place_of : 'inner -> Connected_maps.place;
  open_stop_risk : ('inner -> Direction.t -> Gate_state.t -> int) option;
  tap_stop_risk : ('inner -> Direction.t -> Gate_state.t -> int option) option;
  open_check_risk :
    ('inner ->
    Direction.t ->
    run:int ->
    next:Direction.t option ->
    Gate_state.t ->
    int)
    option;
}

let simple_game ~compare_inner ~press ~held_at ~place_of =
  {
    compare_inner;
    press;
    held_at;
    place_of;
    open_stop_risk = None;
    tap_stop_risk = None;
    open_check_risk = None;
  }

let carry (walked : _ Leg.step) gates =
  { walked with next = { inner = walked.next; gates } }

(* A step that leaves the player where they are, facing [direction], with
   the gates changed. *)
let special_step state special direction gates extra_cost =
  {
    (Leg.plain_step { state with gates } direction) with
    special_step = Some special;
    ends_leg = true;
    extra_cost;
  }

let open_gate rules state (map : Map_data.t) (gate : Map_gates.gate) direction =
  let key = Gate_state.gate_key ~map:map.name ~gate:gate.gate_id in
  let gates =
    { state.gates with opened = Gate_state.Names.add key state.gates.opened }
  in
  special_step state Open_gate direction gates rules.open_gate_cost

let press_switch rules state (pressed : Map_gates.switch) direction =
  let key = Gate_tiles.switch_key pressed in
  let now_on =
    match pressed.press with
    | Statues _ -> not (Gate_state.switch_on state.gates key)
    | Boulder_buttons _ -> true
  in
  let switches_on =
    if now_on then Gate_state.Names.add key state.gates.switches_on
    else Gate_state.Names.remove key state.gates.switches_on
  in
  let gates = { state.gates with switches_on } in
  special_step state Press_switch direction gates rules.press_switch_cost

(* What a press the game refuses may still do: open a gate or press a
   statue. *)
let act game world rules state direction =
  let place = game.place_of state.inner in
  let map = Connected_maps.map world place.map in
  let gate =
    if rules.card_key_held then
      Gate_tiles.closed_card_key_gate_faced map state.gates place.tile direction
    else None
  in
  match gate with
  | Some gate -> Some (open_gate rules state map gate direction)
  | None ->
      Gate_tiles.switch_pressed map place.tile direction
      |> Option.map (fun pressed -> press_switch rules state pressed direction)

let compare_state game a b =
  match game.compare_inner a.inner b.inner with
  | 0 -> Gate_state.compare a.gates b.gates
  | order -> order

let with_gates risk =
  Option.map (fun f state direction -> f state.inner direction state.gates) risk

let check_risk game =
  Option.map
    (fun f state direction ~run ~next ->
      f state.inner direction ~run ~next state.gates)
    game.open_check_risk

let model game world rules : _ Step_model.t =
  let press state direction =
    match game.press state.inner direction state.gates with
    | Some walked -> Some (carry walked state.gates)
    | None -> act game world rules state direction
  in
  {
    compare_state = compare_state game;
    press;
    held_at =
      (fun state direction -> game.held_at state.inner direction state.gates);
    open_stop_risk = with_gates game.open_stop_risk;
    tap_stop_risk = with_gates game.tap_stop_risk;
    open_check_risk = check_risk game;
  }
