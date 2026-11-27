(** Verified BDSP static legendary and bonus encounter templates, base stats,
    and default trigger metadata for Ramanas Park and Sinnoh static encounters.

    Port and correction of the static encounter table in
    [https://github.com/dayfine/Arduino-Source]
    [SerialPrograms/Source/PokemonBDSP/Programs/RngManipulation/PokemonBDSP_RngTargets.{h,cpp}]
    (fixing Giratina to Lv. 70, Ramanas Park Regirock/Regice/Registeel to Lv. 70
    with forced Hidden Ability, and [advances_after_accept] to 84). Excludes
    shiny-locked gifts (Mew, Jirachi), uncatchable Origin Giratina, Shaymin
    (Flower Paradise petal noise), and roamers (Mesprit, Cresselia). *)

(** How the final encounter input is scheduled for a static target. *)
type trigger_kind =
  | Direct_no_pokemon_model
      (** No 3D Pokemon model advances RNG during approach (e.g. Rotom TV or an
          empty Ramanas Park pedestal). *)
  | Timeline_single_confirm
      (** Enter chamber or close menu, open the cry dialog, and press confirm
          inside a blink-free gap. *)

type t = {
  id : string;  (** Lowercase slug (e.g. ["kyogre"], ["groudon"]). *)
  template : Static_encounter.template;  (** RNG generation template. *)
  base_stats : Static_encounter.base_stats;
      (** Species base stats for summary stat calibration. *)
  default_trigger : trigger_kind;  (** Default trigger archetype. *)
  advances_after_accept : int;
      (** Starting blind delay after the final confirm input. *)
}
(** One verified static encounter target. *)

val all : t list
(** Every supported Ramanas Park and Sinnoh static encounter. *)

val find : string -> t option
(** Looks up a target by its lowercase {!t.id} slug (e.g. ["kyogre"],
    ["groudon"]). *)
