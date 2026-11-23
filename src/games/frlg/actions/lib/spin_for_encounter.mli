(** Turning in place on a grass tile until a wild battle starts: quick D-pad
    taps that only turn the player, clockwise, so the player never steps off the
    tile. Ported from the fork's [spin_for_encounter()]
    (Programs/MailGlitch/PokemonFRLG_MailGlitchBattle) with #804's fix for the
    encounter it missed between batches: the screen is checked before each
    batch, and each batch stops on a battle or the fade into one, not only on
    the battle's flash. *)

val batch_turns : int
(** Turns per batch: 24, as the fork. *)

val turn_hold_ms : int
(** 30 ms held: a turn, not a step (the fork's). *)

val turn_release_ms : int
(** 100 ms between turns. *)

val turns : Grid_maps.Direction.t -> int -> Grid_maps.Direction.t list
(** [n] turns clockwise, the first one after the facing. *)

val encounter : Effects.measurements -> bool
(** A battle shows or the screen fades (the battle's opening flash). *)

val spin :
  log:(string -> unit) ->
  facing:Grid_maps.Direction.t ->
  max_batches:int ->
  unit
(** Ends once {!encounter} holds; fails as [no_encounter] after [max_batches]
    batches. *)
