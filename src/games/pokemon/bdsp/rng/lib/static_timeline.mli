(** Mixed-actor BDSP RNG timeline simulation: periodic human/NPC ticks alongside
    aperiodic 3D Pokemon model float-interval blinks sharing one {!Xorshift128}.

    Port of the fork's
    [PokemonBDSP/Programs/RngManipulation/PokemonBDSP_RngTimeline.{h,cpp}]
    ([simulate_timeline]), plus {!simulate_from_phase} for continuing a [1PK]
    (one player + one Pokemon model) scene from an arbitrary re-identified
    anchor. *)

(** Which overworld actor consumed an RNG advance. *)
type actor =
  | Npc of int  (** Periodic human/player NPC, indexed from 0. *)
  | Pokemon of int  (** Aperiodic 3D Pokemon model, indexed from 0. *)

type event = {
  time_seconds : float;  (** Seconds since the timeline start ([t = 0]). *)
  advance : int;  (** Advance index from the base state before this roll. *)
  actor : actor;  (** Actor that consumed the roll. *)
  roll : int;  (** 32-bit {!Xorshift128.next} output consumed by the actor. *)
}
(** One scheduled RNG event on the simulated timeline. *)

type context = {
  npcs : int;  (** Periodic human/player NPCs in the scene. *)
  pokemon_models : int;  (** Aperiodic 3D Pokemon models in the scene. *)
  white_delay_seconds : float;
      (** Seconds from trigger start until scene actors initialize. *)
  advance_delay : int;
      (** Fixed RNG advances consumed before the timeline begins. *)
  advances_after_accept : int;
      (** Fixed RNG advances consumed after the final confirm input. *)
  tick_seconds : float;
      (** Seconds per periodic NPC tick (nominally
          {!Blink_model.npc_tick_seconds}). *)
}
(** Scene parameters for {!simulate_timeline} ([BdspTimelineContext]). *)

val default_context : npcs:int -> pokemon_models:int -> context
(** Default scene context with zero white/advance delay, 84
    [advances_after_accept], and {!Blink_model.npc_tick_seconds}. *)

val simulate_timeline :
  Xorshift128.state ->
  context:context ->
  duration_seconds:float ->
  (event list, string) result
(** Simulates all NPC ticks and Pokemon model blinks from [t = 0] up to
    [duration_seconds]. After skipping [context.advance_delay] advances, each
    Pokemon model draws its initial interval at [context.white_delay_seconds]
    and each NPC schedules its first tick at
    [context.white_delay_seconds +. context.tick_seconds]. Returns [Error] on
    invalid scene counts or non-positive tick period. *)

val simulate_from_phase :
  Xorshift128.state ->
  tick_seconds:float ->
  first_player_tick_seconds:float ->
  first_pokemon_blink_seconds:float ->
  duration_seconds:float ->
  (event list, string) result
(** Simulates a [1PK] (1 player + 1 Pokemon model) scene starting from an
    arbitrary phase anchor where the player's next tick is at
    [first_player_tick_seconds] and the Pokemon model's next blink is at
    [first_pokemon_blink_seconds]. Unlike {!simulate_timeline}, no initial
    Pokemon setup roll is drawn at [t = 0]. *)
