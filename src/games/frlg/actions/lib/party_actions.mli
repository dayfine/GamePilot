(** Party and bag actions from the overworld, ported from the fork's Mail Glitch
    actions (Programs/MailGlitch/PokemonFRLG_MailGlitchActions:
    [swap_party_slots()], [run_give_bag_item()]) and its item use
    (PokemonFRLG_AutoStoryItemUse), each step waiting on the party or bag
    reader. Slots are from 1. *)

val pokemon_row : int
(** POKéMON on the full Start menu: 1. *)

val open_party : unit -> unit
(** START, POKéMON, the party read. Fails as [no_start_menu] or [no_party]. *)

val choose_slot : int -> unit
(** On the party, the cursor moved to this slot by reading it
    ({!Menu_cursor.move_to}), then A once: the screen after it (an item given or
    used, a trade, a switch) has no one reader to confirm by. *)

val member_menu : Effects.measurements -> bool
(** A member's menu shows over the party. *)

val on_member_menu : int -> (unit -> 'a) -> 'a
(** On the party: with the member's menu read ({!Frlg_readers.Member_menu},
    subscribed only here), the slot chosen until its menu shows, then the body.
    Fails as [no_member_menu]. *)

val choose_member_row : int -> taken:(Effects.measurements -> bool) -> unit
(** On a member's menu, in the body of {!on_member_menu}: the row (from 0,
    SUMMARY) chosen until [taken] holds. Fails as [no_member_menu]. *)

val swap : log:(string -> unit) -> int -> int -> unit
(** The two members trade places: the first's menu, SWITCH (third from its
    bottom, whatever its field moves), the second, A, then out to the overworld.
    Fails as [no_party] or [no_member_menu]. *)

val give : log:(string -> unit) -> item:string -> slot:int -> unit
(** The item from its pocket, GIVE (row 1 of its menu, mail's too), the member;
    a held item is switched for it (YES). Mail opens its Easy Chat editor, where
    one word is written and confirmed ({!mail_editor_wait_ms}: no reader for the
    editor). Berries (the Berry Pouch) are not done: [not_implemented]. *)

val mail_editor_wait_ms : int
(** The Easy Chat editor opening: 2500, the fork's measured wait. *)

val use : log:(string -> unit) -> item:string -> slot:int option -> unit
(** The item from its pocket, USE (row 0), then on the member when a slot is
    given, then out to the overworld. With no slot the item acts on the field:
    an Escape Rope ends at the settle after a warp, anything else at the talk
    settle. *)
