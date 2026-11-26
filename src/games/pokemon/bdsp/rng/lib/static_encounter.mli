(** A static (gift or legendary) BDSP Pokemon generated from an RNG state, and
    the search for the advances whose Pokemon a filter accepts: what the
    starter RNG uses to find a shiny starter.

    Port of the static half of the fork's [Pokemon/Pokemon_BdspRng.{h,cpp}]
    (R21: same rolls in the same order). Left out until a program needs them:
    roamers (they reseed a Xoroshiro128+), [XoroshiroBDSP], [bdsp_splitmix64]
    and the nature checker mapping. Two deliberate differences in shape: no
    Synchronize is [None] rather than the C++'s [0xff], and {!scan} takes no
    [Cancellable] (a caller that needs to stop splits the range).

    32-bit values ([ec], [pid], rolls) are OCaml [int]s in [0, 2^32), as in
    {!Xorshift128}. *)

type shiny =
  | Not_shiny
  | Star
  | Square
      (** How a PID is shiny against a trainer: not at all, star or square
          ([BdspShinyType]). *)

val shiny_name : shiny -> string
(** ["Not Shiny"], ["Star Shiny"], ["Square Shiny"]. *)

type gender = Male | Female | Genderless  (** A generated Pokemon's gender. *)

val gender_name : gender -> string
(** ["Male"], ["Female"] or ["Genderless"]. *)

type ivs = {
  hp : int;
  attack : int;
  defense : int;
  spatk : int;
  spdef : int;
  speed : int;
}
(** The six individual values, each 0-31, in the game's stat order. *)

val ivs_to_string : ivs -> string
(** ["hp/atk/def/spa/spd/spe"]. *)

type pokemon = {
  ec : int;
  pid : int;
  shiny : shiny;
  ivs : ivs;
  ability : int;
  gender : gender;
  nature : int;  (** The game's index, 0-24; see {!nature_name}. *)
  level : int;
  height : int;
  weight : int;
}
(** [BdspPokemonResult]. *)

val nature_name : int -> string
(** The game's own nature order; ["?"] outside 0-24. *)

val shiny_of_pid : pid:int -> tsv:int -> shiny
(** [bdsp_get_shiny]: PSV equal to the TSV is square, an XOR under 16 is a star.
*)

val is_shiny : pid:int -> tsv:int -> bool
(** Whether {!shiny_of_pid} is a star or a square. *)

type template = {
  species : string;
  level : int;
  guaranteed_ivs : int;
  ability_kind : int;
      (** 0 or 1 fixed, 2 hidden (rolled anyway), else rolled. *)
  gender_ratio : int;  (** 255 genderless, 254 female, 0 male, else rolled. *)
  shiny_locked : bool;
}
(** [BdspStaticTemplate] without [roamer]. *)

val generate :
  Xorshift128.state ->
  template ->
  tsv:int ->
  synchronize_nature:int option ->
  pokemon
(** [bdsp_generate_static]: the Pokemon generated from this state. *)

type hit = { advances : int; state : Xorshift128.state; pokemon : pokemon }
(** [BdspRngHit]: [state] is the state at the start of that advance. *)

type searcher
(** [BdspStaticSearcher]. *)

val searcher :
  Xorshift128.state ->
  template ->
  tsv:int ->
  synchronize_nature:int option ->
  searcher
(** [searcher base template ~tsv ~synchronize_nature] searches from the state
    [base] for [template] against trainer shiny value [tsv];
    [synchronize_nature] is the lead's nature index when it has Synchronize, or
    [None]. *)

val generate_at : searcher -> int -> pokemon
(** The Pokemon after jumping the base state this many advances. *)

val scan :
  ?stop_at_first:bool ->
  searcher ->
  min_advances:int ->
  max_advances:int ->
  accept:(pokemon -> bool) ->
  hit list
(** Every advance in [min_advances, max_advances] whose Pokemon [accept]s, in
    order, walking a window of outputs forward; with [stop_at_first], only the
    first. Empty when [min_advances > max_advances]. *)
