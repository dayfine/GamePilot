(** The seed lists: for each boot timing (delay), the initial seed each sound,
    button mode and seed button setting gives, and the lookup that picks the
    earliest delay giving a target seed.

    Port of
    [PokemonFRLG/Programs/RngManipulation/PokemonFRLG_SeedsDatabase.{h,cpp}]
    (https://github.com/PokemonAutomation/Arduino-Source). {!of_columns} takes
    what the C++ reads from the JSON: the [Delay] array, and every other array
    with its key. The C++ keeps the columns sorted by name (byte order); pass
    them in that order to get its tie-breaking in {!find_seed}. *)

type sound = Mono | Stereo  (** The game's sound option. *)

type seed_button =
  | A
  | Start
  | L  (** The button pressed on the title screen, which sets the seed. *)

type extra_button =
  | No_extra
  | Extra_l
      (** A button held with the seed button: none or L, the two the lookup
          tries. *)

val blackout_seed_offset : int
(** 0x24: what holding L as well adds to the seed. *)

type column = {
  name : string;
  sound : sound;
  button_mode : string;
  seed_button : seed_button;
  seeds : int array;
}
(** One seed list. [name] is its JSON key, parsed into [sound], [button_mode]
    (e.g. ["Help"], the only mode {!find_seed} uses) and [seed_button].
    [seeds.(i)] is the 16-bit seed at [delays.(i)] of {!t}. *)

type t = { delays : int array; columns : column list }
(** The seed table: the boot delays, one per row, and the columns in the order
    {!of_columns} was given them. *)

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
(** Where a target seed was found: the column it is in ([sound], [button_mode],
    [seed_button], [column_name]), the button held with it, its delay, and the
    seeds around it. *)

val find_seed : t -> target:int -> sound -> radius:int -> seed_match option
(** The earliest delay at which a ["Help"] column of [sound] gives [target],
    directly or with L held, with the seeds up to [radius >= 0] rows either side
    (L-held seeds given without the offset). On equal delays the earlier column
    wins, and within a column the seed without L. *)

val of_json : Yojson.Safe.t -> (t, string) result
(** The constructor's reading of the seed file (FR_Eng.json's shape): the
    [Delay] array of integers, every other key a column of hex seed strings,
    taken in byte order of their names as the C++ holds them. *)
