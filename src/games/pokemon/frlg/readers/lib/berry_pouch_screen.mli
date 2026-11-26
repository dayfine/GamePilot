(** Reader: the Berry Pouch (opened from the bag's Key Items). The fork has no
    reader for it: its Mail Glitch give step (Programs/MailGlitch/
    PokemonFRLG_MailGlitchActions, [run_give_bag_item()]) waits 2 s after
    opening it. This one is new: the list window's blue border left and right of
    the berry list, and the light blue band across the top left, above the BERRY
    POUCH title. Colors measured on mGBA (2026-11-23): border (107, 156, 239),
    band (165, 206, 239); the bag draws yellow and orange there, the party teal.
    No Switch capture of it yet. *)

val probes : Wire.probe_spec list

(** {1 Thresholds} *)

val max_distance : float
(** How far a box's channel shares may lie from its color's: 0.08. The two blues
    are 0.1 apart, the party's teal 0.17 from the band. *)

(** {1 Reader} *)

val berry_pouch : Effects.measurements -> bool
