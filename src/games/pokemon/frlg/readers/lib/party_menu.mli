(** Readers: the party menu, its selected slot, its empty slots, and the mark a
    member's sprite carries for a held item or for mail. Ported from the fork's
    Menus/PokemonFRLG_PartyMenuDetector (the screen and PartySlotDetector),
    PokemonFRLG_PartyEmptySlotDetector and PokemonFRLG_PartyHeldItemDetector;
    the boxes are theirs, relative to the game picture, unless a reader says
    otherwise. Slots are numbered 1 to 6: 1 is the big box on the left, 2 to 6
    the rows on the right.

    The screen: the white message box along the bottom and the dark teal
    background left of the slots. A message box that covers the bottom (a
    member's own menu shrinks it) hides the screen from {!party_menu}, as in the
    fork; the slot readers still read. *)

type mark = No_mark | Held_item | Mail

(** The list's layout: one big box (slot 1) and five rows, or a double battle's
    two big boxes (slots 1 and 2) and four rows. *)
type layout = Single | Double

val mark_name : mark -> string
val probes : Wire.probe_spec list

(** {1 Thresholds} *)

val max_filled_stddev_sum : float
(** A slot's probe on the frame of an empty slot shows the frame's edge: its
    stddev sum is above this (the fork's 20); a member's name plate is flat
    there. *)

val min_item_red : float
(** The held-item icon's red band ((200, 60, 30) to (255, 160, 140), the fork's)
    covers at least this share of the icon's box (0.019 on a Switch icon, 0.08
    on mGBA; a sprite's own red can pass, hence the yellow)... *)

val min_item_yellow : float
(** ...and its yellow body ((210, 210, 100) to (255, 255, 190), the fork's) at
    least this share. Measured: 0.22-0.26 on an icon on Switch and mGBA; on the
    party menu's sprites without one, the yellow and red together stay below. *)

val min_mail_lavender : float
(** The mail icon's lavender ((200, 200, 240) to (240, 240, 255): (214, 214,
    255) on mGBA, (231, 234, 254) on Switch, whose colors differ) covers at
    least this share of the icon's box. Measured: 0.10 on mGBA, 0.093-0.099 on
    Switch; other party sprites stay below it in the captures at hand. *)

(** {1 Readers} *)

val layout : Effects.measurements -> layout option
(** The party menu's layout; [None] when it does not show. The double layout is
    unverified: written from pokefirered's window templates, with no capture of
    it yet. *)

val party_menu : Effects.measurements -> bool
(** Either layout shows. *)

val selected_slot : Effects.measurements -> int option
(** The slot with the orange border, in either layout; [None] when no slot or
    more than one has it. *)

val slot_empty : Effects.measurements -> int -> bool
(** Slot 2 to 6 shows an empty frame (the single layout's). Slot 1 is never
    empty: false. *)

val members : Effects.measurements -> int
(** Slots before the first empty one (1 to 6). *)

val mark : Effects.measurements -> int -> mark
(** The icon on slot [n]'s sprite (English layout; a Japanese game draws it
    further right). *)
