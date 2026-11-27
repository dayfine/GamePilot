(** Pure BDSP Bag pocket navigation, Poké Mart quantity dialing, and Bag screen
    detection. *)

(** The eight BDSP Bag pockets in left-to-right tab order. *)
type pocket =
  | Medicine  (** Tab 0: Potions, status heals, and revives. *)
  | Poke_balls  (** Tab 1: Poké Balls. *)
  | Battle_items  (** Tab 2: X items and battle-only consumables. *)
  | Berries  (** Tab 3: Berries. *)
  | Items  (** Tab 4: General items and evolution stones. *)
  | Tms  (** Tab 5: Technical Machines. *)
  | Treasures  (** Tab 6: Shards, fossils, and sellable treasures. *)
  | Key_items  (** Tab 7: Key items such as the Explorer Kit and Bike. *)

val pocket_index : pocket -> int
(** Zero-based tab index (0..7) of [pocket] in the BDSP Bag. *)

val pocket_steps :
  from:pocket -> to_:pocket -> [ `Left of int | `Right of int | `Stay ]
(** Shortest D-pad navigation across the eight wrapping Bag pocket tabs from
    [from] to [to_]. Ties at distance 4 go [`Right 4]. *)

val mart_quantity_steps :
  target_qty:int ->
  [ `Up of int | `Down of int | `Right of int | `Left of int ] list
(** Minimal D-pad presses to dial [target_qty] (clamped to 1..99) in a BDSP Poké
    Mart quantity picker starting at 1, where [`Up] is +1, [`Down] is -1,
    [`Right] is +10, and [`Left] is -10. Never overshoots 99. *)

val bag_open_probes : picture:Wire.box -> Wire.probe_spec list
(** Color-stats probe for the green top-right BDSP Bag header bar, relative to
    [picture]. *)

val bag_open : Effects.measurements -> bool
(** [true] when the green top-right Bag header bar is detected in the
    measurements; [false] when absent or not matching. *)
