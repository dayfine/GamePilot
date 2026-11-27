type actor = Npc of int | Pokemon of int
type event = { time_seconds : float; advance : int; actor : actor; roll : int }

type context = {
  npcs : int;
  pokemon_models : int;
  white_delay_seconds : float;
  advance_delay : int;
  advances_after_accept : int;
  tick_seconds : float;
}

let default_advances_after_accept = 84

let default_context ~npcs ~pokemon_models =
  {
    npcs;
    pokemon_models;
    white_delay_seconds = 0.0;
    advance_delay = 0;
    advances_after_accept = default_advances_after_accept;
    tick_seconds = Blink_model.npc_tick_seconds;
  }

type scheduled = { actor : actor; mutable next_time : float }

let earliest_index actors =
  let best = ref 0 in
  for i = 1 to Array.length actors - 1 do
    if actors.(i).next_time < actors.(!best).next_time then best := i
  done;
  !best

let actor_step ~tick_seconds roll = function
  | Npc _ -> tick_seconds
  | Pokemon _ -> Blink_model.pokemon_blink_interval roll

let fire_actor rng ~tick_seconds ~advance current =
  let roll = Xorshift128.next rng in
  let ev =
    { time_seconds = current.next_time; advance; actor = current.actor; roll }
  in
  current.next_time <-
    current.next_time +. actor_step ~tick_seconds roll current.actor;
  ev

let rec run_queue rng ~tick_seconds ~duration_seconds actors advance acc =
  let current = actors.(earliest_index actors) in
  if current.next_time > duration_seconds then List.rev acc
  else
    let ev = fire_actor rng ~tick_seconds ~advance current in
    run_queue rng ~tick_seconds ~duration_seconds actors (advance + 1)
      (ev :: acc)

let validate_context context ~duration_seconds =
  if context.npcs < 0 || context.pokemon_models < 0 then
    Error "Static_timeline: actor counts must be non-negative"
  else if context.npcs = 0 && context.pokemon_models = 0 then
    Error "Static_timeline: at least one NPC or Pokemon model is required"
  else if not (context.tick_seconds > 0.0) then
    Error "Static_timeline: tick_seconds must be positive"
  else if context.advance_delay < 0 then
    Error "Static_timeline: advance_delay must be non-negative"
  else if duration_seconds < 0.0 then
    Error "Static_timeline: duration_seconds must be non-negative"
  else Ok ()

let init_one_pokemon rng context advance initial_events i =
  let roll = Xorshift128.next rng in
  let ev =
    {
      time_seconds = context.white_delay_seconds;
      advance = !advance;
      actor = Pokemon i;
      roll;
    }
  in
  incr advance;
  initial_events := ev :: !initial_events;
  let next_time =
    context.white_delay_seconds +. Blink_model.pokemon_blink_interval roll
  in
  { actor = Pokemon i; next_time }

let init_pokemon_actors rng context =
  let advance = ref context.advance_delay in
  let initial_events = ref [] in
  let pokemon =
    Array.init context.pokemon_models
      (init_one_pokemon rng context advance initial_events)
  in
  (!advance, !initial_events, pokemon)

let run_timeline state ~context ~duration_seconds =
  let rng = Xorshift128.create state in
  Xorshift128.advance rng context.advance_delay;
  let start_advance, initial, pokemon = init_pokemon_actors rng context in
  let initial =
    List.filter
      (fun (ev : event) -> ev.time_seconds <= duration_seconds)
      initial
  in
  let first_npc = context.white_delay_seconds +. context.tick_seconds in
  let npcs =
    Array.init context.npcs (fun i -> { actor = Npc i; next_time = first_npc })
  in
  let actors = Array.append npcs pokemon in
  run_queue rng ~tick_seconds:context.tick_seconds ~duration_seconds actors
    start_advance initial

let simulate_timeline state ~context ~duration_seconds =
  Result.map
    (fun () -> run_timeline state ~context ~duration_seconds)
    (validate_context context ~duration_seconds)

let simulate_from_phase state ~tick_seconds ~first_player_tick_seconds
    ~first_pokemon_blink_seconds ~duration_seconds =
  if not (tick_seconds > 0.0) then
    Error "Static_timeline.simulate_from_phase: tick_seconds must be positive"
  else if first_player_tick_seconds < 0.0 || first_pokemon_blink_seconds < 0.0
  then
    Error
      "Static_timeline.simulate_from_phase: initial event times must be \
       non-negative"
  else if duration_seconds < 0.0 then
    Error
      "Static_timeline.simulate_from_phase: duration_seconds must be \
       non-negative"
  else
    let rng = Xorshift128.create state in
    let actors =
      [|
        { actor = Npc 0; next_time = first_player_tick_seconds };
        { actor = Pokemon 0; next_time = first_pokemon_blink_seconds };
      |]
    in
    Ok (run_queue rng ~tick_seconds ~duration_seconds actors 0 [])
