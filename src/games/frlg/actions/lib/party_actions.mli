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
    a held item is switched for it (the "already holding" page pressed through,
    then YES; the fork answers a question it reads once 1200 ms after the A).
    Mail opens its Easy Chat editor, where one word is written after
    {!mail_editor_wait_ms} and confirmed by {!confirm_mail}. A berry comes from
    the Berry Pouch ({!Berry_pouch.choose_give}). *)

val give_to : int -> unit
(** After GIVE: the party read, the fork's 400 ms (an earlier A is dropped),
    then the slot chosen ({!choose_slot}). Fails as [no_party]. *)

val give_row : int
(** GIVE on an item's menu: row 1. *)

val confirm_mail : unit -> unit
(** After PLUS in the mail editor: its Yes/No arrow on YES
    ({!Frlg_readers.Mail_editor}, 4 s), then A, as the C++ ItemDuplication
    confirms; the fork's give presses A after 1200 ms. Fails as
    [mail_no_confirm]. *)

val mail_editor_wait_ms : int
(** The Easy Chat editor opening: 2500, the fork's measured wait. *)

val use : log:(string -> unit) -> item:string -> slot:int option -> unit
(** The item from its pocket, USE (row 0), then on the member when a slot is
    given, then out to the overworld. With no slot the item acts on the field:
    an Escape Rope ends at the settle after a warp, anything else at the talk
    settle. *)

val party_settle_ms : int
(** After the party opens, before its marks are read: 800, the fork's wait. *)

val verify_mail_glitch : log:(string -> unit) -> who:string -> slot:int -> unit
(** The fork's [run_verify_mail_glitch()]: the party opened, the member's sprite
    read for the held-item mark ({!Frlg_readers.Party_menu.mark}, the fork's
    PartyHeldItemDetector), the party closed. After mg-05's Recycle the member
    holds the berry, not mail: any other mark fails as [mail_glitch_not_active],
    naming the mark read (mail: Knock Off missed; none: the berry was not
    recycled). [who] names the member in the log. *)
