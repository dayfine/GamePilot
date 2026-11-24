(** The seed lists: for each boot timing (delay), the initial seed each sound,
    button mode and seed button setting gives, and the lookup that picks the
    earliest delay giving a target seed.

    Port of [SeedsDatabase] in the fork's
    [PokemonFRLG/Programs/RngManipulation/PokemonFRLG_SeedsDatabase.{h,cpp}],
    without the file reading: {!of_columns} takes what the constructor reads
    from the JSON ([Delay] and the other arrays, in the JSON object's key order,
    which the C++ iterates sorted). *)

type sound = Mono | Stereo
type seed_button = A | Start | L

type extra_button =
  | No_extra
  | Extra_l  (** [BlackoutButton] [None] and [L], the two the lookup tries. *)

val blackout_seed_offset : int
(** [BLACKOUT_SEED_OFFSET]: holding L as well adds 0x24 to the seed. *)

type column = {
  name : string;
  sound : sound;
  button_mode : string;
  seed_button : seed_button;
  seeds : int array;
}

type t = { delays : int array; columns : column list }

val parse_column_name : string -> (sound * string * seed_button, string) result
(** ["<Sound> / <Button Mode> / <Seed Button>"], e.g. ["Mono / Help / A"]. *)

val of_columns :
  delays:int array -> (string * string list) list -> (t, string) result
(** The constructor: each column's name and its hex seed strings. *)

type seed_match = {
  seed_values : int list;
  seed_position : int;  (** The target's index in [seed_values]. *)
  seed_delay : int;
  seed_button : seed_button;
  extra_button : extra_button;
  sound : sound;
  button_mode : string;
  column_name : string;
}
(** [SeedMatch] when [found]. *)

val find_seed : t -> target:int -> sound -> radius:int -> seed_match option
(** The earliest delay at which a ["Help"] column of [sound] gives [target],
    directly or with L held, with the seeds up to [radius >= 0] rows either side
    (L-held seeds given without the offset). Earlier columns win ties. *)
