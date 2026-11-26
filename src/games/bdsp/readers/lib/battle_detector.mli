(** Reader: BDSP wild-battle main menu (Fight / Pokémon / Bag / Run).

    Ported from the fork's
    [SerialPrograms/Source/PokemonBDSP/Inference/Battles/PokemonBDSP_BattleMenuDetector.cpp]
    ([BattleMenuDetector::is_battle_button]): checks the red Fight button at
    [(0.817, 0.585, 0.150, 0.070)]. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The probe {!shown} needs, relative to [picture]. *)

val shown : Effects.measurements -> bool
(** [true] when the red Fight button of the battle menu is visible. *)
