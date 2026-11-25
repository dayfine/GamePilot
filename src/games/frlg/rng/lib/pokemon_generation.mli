(** Method 1, 2 and 4 generation: a Pokemon's PID, gender value, nature, ability
    and IVs from a {!Rng_state.t}, and its shininess for a trainer.

    Port of the generation half of the fork's [Pokemon/Pokemon_AdvRng.{h,cpp}]:
    [AdvIVs], [AdvPokemonResult], [pid_from_states], [gender_value_from_pid],
    [gender_from_gender_value], [nature_from_pid], [ability_from_pid],
    [unown_form_from_pid], [iv_group_from_state], [pokemon_from_state] and
    [shiny_type_from_pid].

    Natures are [AdvNature] numbers 0 (Hardy) to 24 (Quirky); abilities are the
    slot, 0 or 1. *)

type ivs = {
  hp : int;
  attack : int;
  defense : int;
  spatk : int;
  spdef : int;
  speed : int;
}
(** [AdvIVs]: the six individual values, each 0 to 31. *)

type result = {
  pid : int;
  gender_value : int;  (** The PID's low byte. *)
  nature : int;
  ability : int;
  ivs : ivs;
}
(** [AdvPokemonResult]. *)

type gender = Male | Female
type shiny_type = Normal | Star | Square  (** [AdvShinyType] without [Any]. *)

val pid_of_states : low:int -> high:int -> int
(** [pid_from_states s0 s1]: the high half of [high] over the high half of
    [low]. *)

val nature_of_pid : int -> int
(** [nature_from_pid]: the PID mod 25, an [AdvNature] number. *)

val ability_of_pid : int -> int
(** [ability_from_pid]: the PID's lowest bit, the ability slot 0 or 1. *)

val gender_of_value : int -> threshold:int -> gender option
(** [gender_from_gender_value]: [None] for a genderless species (threshold below
    -1), else [Female] when the value is at most the threshold. *)

val unown_form_of_pid : int -> int
(** 0 (A) to 25 (Z), 26 (!), 27 (?). *)

val pokemon_of_state_with_pid :
  ?roaming:bool -> Rng_state.t -> pid:int -> nature:int -> result
(** [pokemon_from_state] with a PID and nature already chosen: IVs from [s2] and
    [s3] (Method 1), [s3] and [s4] (Method 2) or [s2] and [s4] (Method 4).
    [roaming] keeps the low byte of [s2]'s IVs and zeroes the rest, as the
    game's roaming legendary bug does. *)

val pokemon_of_state : ?roaming:bool -> Rng_state.t -> result
(** [pokemon_from_state]: PID from [s0] and [s1], nature from the PID. *)

val shiny_type_of_pid : int -> tid_xor_sid:int -> shiny_type
(** [shiny_type_from_pid]: [tid_xor_sid] is the trainer's ID xor secret ID. With
    [p] the PID's high half xor its low half, [Square] when [p] equals
    [tid_xor_sid], [Star] when [p xor tid_xor_sid] is otherwise below 8, else
    [Normal]. *)
