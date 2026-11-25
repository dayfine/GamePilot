(** Reader: the black of a game loading after its launch, and the black of the
    game entering the overworld from its title. Ported from the fork's
    [GameLoadingDetector] (NintendoSwitch_GameEntry.cpp: the boxes (0.2, 0.2,
    0.6, 0.1) and (0.2, 0.7, 0.6, 0.1) both black) and the [BlackScreenWatcher]
    of PLZA's [gamemenu_to_ingame] (PokemonLZA_GameEntry.cpp: the box (0.1,
    0.04, 0.8, 0.3) black), black as the fork's [is_black] has it: channel means
    summing to 100 at most, their stddevs to 10 at most. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The probes both reads need, for a game picture at [picture] in the frame. *)

val loading : Effects.measurements -> bool
(** Both loading boxes are black. [false] when a probe is missing. *)

val entering : Effects.measurements -> bool
(** The entering box is black. [false] when its probe is missing. *)
