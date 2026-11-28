(** Gen 3 Pokémon base stats, gender thresholds, nature names, and level-L stat
    computation.

    Port of
    [PokemonFRLG/Programs/RngManipulation/PokemonFRLG_RngStatsDatabase.{h,cpp}]
    (https://github.com/PokemonAutomation/Arduino-Source), reading PA/CC's
    [BaseStats.json] copied to [src/games/pokemon/frlg/assets/base_stats.json].
*)

type stats = {
  hp : int;  (** Hit Points. *)
  atk : int;  (** Attack. *)
  def : int;  (** Defense. *)
  spa : int;  (** Special Attack. *)
  spd : int;  (** Special Defense. *)
  spe : int;  (** Speed. *)
}
(** Six Gen 3 stats (either base stats or computed level-L stats). *)

(** A Pokémon's gender. *)
type gender =
  | Male  (** Male Pokémon. *)
  | Female  (** Female Pokémon. *)
  | Genderless  (** Genderless species (such as Magnemite or Porygon). *)

type entry = {
  base : stats;  (** Species base stats from [base_stats.json]. *)
  gender_threshold : int;
      (** PA/CC [genderThreshold]: [-2] genderless, [-1] 100% male, [255] 100%
          female, else Female when [(pid land 0xff) <= gender_threshold]. *)
}
(** Species entry loaded from [base_stats.json]. *)

type t
(** Lookup table from lowercase species slug (e.g. ["scyther"]) to {!entry}. *)

val default_path : string
(** Repository-relative path to [base_stats.json]:
    ["src/games/pokemon/frlg/assets/base_stats.json"]. *)

val of_json : Yojson.Safe.t -> (t, string) result
(** Parses PA/CC's [BaseStats.json] object. *)

val load : ?path:string -> unit -> (t, string) result
(** Loads [base_stats.json] from [path] (or locates {!default_path} via
    {!Repo_io.Repo_files.locate}). *)

val find : t -> string -> entry option
(** Looks up a species by slug (case-insensitive, trimmed). *)

val nature_names : string array
(** The 25 Gen 3 natures in standard Gen 3 order ([pid mod 25]): [0] = ["Hardy"]
    .. [24] = ["Quirky"]. *)

val nature_name : int -> string option
(** Name of nature index [0..24], or [None] if out of range. *)

val nature_of_name : string -> int option
(** Nature index [0..24] for a name (case-insensitive, trimmed). *)

val gender_of_pid : pid:int -> gender_threshold:int -> gender
(** Computes {!gender} from a 32-bit [pid] and PA/CC [gender_threshold],
    matching {!Pokemon_generation.gender_of_value}. *)

val compute_stats :
  base:stats -> nature:int -> ivs:Pokemon_generation.ivs -> level:int -> stats
(** Computes Gen 3 level-[level] stats (0 EVs) from [base], [nature] ([0..24]),
    and [ivs]. *)
