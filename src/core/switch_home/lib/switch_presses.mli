(** The fork's button commands as daemon presses: pbf_press_button (a press held
    [hold_ms], then [cooldown_ms] before the next) and pbf_mash_button
    (issue_mash_button's defaults, NintendoSwitch_ProController.h: a press every
    64 ms, held 40, for the duration). *)

val press : hold_ms:int -> cooldown_ms:int -> Wire.button -> unit
(** pbf_press_button: [button] held [hold_ms], then [cooldown_ms] with nothing
    held; returns when the daemon has done both. *)

val mash_presses : Wire.button -> int -> Wire.command list
(** The presses of a mash of [ms] milliseconds. *)

val mash : Wire.button -> int -> unit
(** pbf_mash_button: {!mash_presses}, returning when they are done. *)

val wait : int -> unit
(** pbf_wait: nothing held for [ms] milliseconds. *)
