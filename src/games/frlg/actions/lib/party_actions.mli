(** Party and bag actions from the overworld, ported from the fork's Mail Glitch
    actions (Programs/MailGlitch/PokemonFRLG_MailGlitchActions:
    [swap_party_slots()], [run_give_bag_item()]) and its item use
    (PokemonFRLG_AutoStoryItemUse), each step waiting on the party or bag
    reader. Slots are from 1. *)

val pokemon_row : int
(** POKéMON on the full Start menu: 1. *)

val switch_taps_up : int
(** A member's menu ends in SWITCH, ITEM, CANCEL whatever its field moves and
    language, and wraps, so UP this many times from SUMMARY lands on SWITCH: 3
    (pokefirered src/party_menu.c). *)

val open_party : unit -> Effects.measurements
(** START, POKéMON, the party read. Fails as [no_party]. *)

val choose_slot : Effects.measurements -> int -> unit
(** On the party, the cursor moved from the selected slot to this one, then A.
*)

val swap : log:(string -> unit) -> int -> int -> unit
(** The two members trade places: the first's menu, SWITCH, the second, A, then
    out to the overworld. Fails as [no_party] or [no_member_menu]. *)

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
