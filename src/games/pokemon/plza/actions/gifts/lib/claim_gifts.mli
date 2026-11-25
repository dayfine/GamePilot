(** Claiming PLZA's Mystery Gifts and putting them in Box 1, saved:
    [plza_claim_and_bank.sh] from the BDSPLab lab tools (console B, 2026-11-20),
    its stages 1 to 3. From the overworld, with five Pokémon in the party and
    Box 1 empty: the Internet gift (Vivillon, Poké Ball Pattern) lands in party
    slot 6, the code's gift (Xerneas for CELEBRATE30TH) in Box 1 slot 1; the
    Vivillon goes to Box 1 slot 2; PLZA is saved and closed
    ({!Switch_home.Game_entry.close_game}).

    Where it differs: the gift in party slot 6 goes to its own slot whichever
    gifts the run claims ({!mode}, {!Gift_to_box.gift}): the code's gift claimed
    alone lands in party slot 6 and goes to slot 1, where the script moved it to
    slot 2 (console B, 2026-11-25). New here: the Internet gift alone, and
    {!Box_slot_2_to_1}.

    The run is a chain of steps ({!Mystery_gift}, {!Gift_to_box}), each named by
    the screen it starts on ({!points}); a run can start on any of them and stop
    before any later one, the console left on that screen.

    A run first wakes the screen ({!Switch_home.Stick_wake}): a console left on
    a stop dims, and a dimmed screen reads as none of them. Then the start and
    the stop are read where a reader knows the screen (gift-list, card,
    keyboard, code-card, boxes, save: held 1 s, a card within 30 s), with no
    press; the run is an error when one does not show, and logs a point no
    reader knows as not read (console B, 2026-11-25: a stop on card was logged
    while the screen was still the white fade before it). Each step's screens
    are read; the first one not seen ends the run with an error naming it. *)

(** What a run claims and boxes. Its gifts also say which one is in party slot 6
    when a run starts past the claims, so a run that stopped is finished with
    the same mode. *)
type mode =
  | Both_gifts
      (** the Internet gift (to party slot 6, then Box 1 slot 2), then the
          code's (straight to Box 1 slot 1) *)
  | Code_gift_only
      (** the script's [--code-only]: from the overworld, Mystery Gift, then
          straight to the code; its gift to party slot 6, then Box 1 slot 1 *)
  | Internet_gift_only
      (** the Internet gift alone, to party slot 6, then Box 1 slot 2; from the
          Mystery Gift menu after its card (code), the code's disconnect presses
          ({!Mystery_gift.disconnect}; not yet run on a console from that menu)
      *)
  | Box_slot_2_to_1
      (** no gift: from the overworld into the Boxes (the party not read), Box 1
          slot 2 moved to an empty slot 1 ({!Gift_to_box.move_slot_2_to_1}),
          saved and closed: a code's gift the script's move left in slot 2 *)

type span = {
  from : string;  (** the point the console is on: "overworld" from the start *)
  stop_at : string option;  (** the point to stop on, before its step *)
  mode : mode;  (** what the run claims and boxes *)
}
(** The part of the run to play: where it starts and where it stops. *)

val points : string list
(** The screens between the steps, in order: overworld (the start), mystery-gift
    (its menu), gift-list (the Internet list), card (the Internet gift's card),
    code (the Mystery Gift menu again), keyboard (the code keyboard), code-card
    (the code gift's card), disconnect (its list), after-gifts (the overworld,
    the gifts claimed), boxes (the Boxes), moved (the main menu, the gift
    moved), save (Save Progress's prompt), saved (the overworld, saved). A
    mode's run has those of its own steps: {!Code_gift_only} skips mystery-gift,
    gift-list and card; {!Internet_gift_only} keyboard, code-card and disconnect
    (its code step leaves Mystery Gift); {!Box_slot_2_to_1} has overworld,
    boxes, moved, save and saved. *)

val default_code : string
(** CELEBRATE30TH, the script's default. *)

val run :
  log:(string -> unit) ->
  picture:Wire.box ->
  assets:Plza_readers.Blob_assets.t ->
  gift_name:string option ->
  tile:Switch_home.Home_screen.tile_color ->
  span:span ->
  code:string ->
  (unit, string) result
(** The steps from [span.from] to [span.stop_at] (or the end). [assets] are the
    PLZA readers' uploaded templates (the main menu's buttons), [gift_name] the
    Internet gift's name template's, uploaded from {!gift_name_template}; [tile]
    is PLZA's colour for the HOME reader that closes the game. [Error] before
    any press for an unknown point or a stop not after the start ({!check}). *)

val gift_name_template :
  language:string -> span -> (string option, string) result
(** The repo path of the Internet gift's name template for the game's language
    (a tag of [gamepilot run --options language=]): en and fr, each cropped from
    its gift list (400 x 38 from (592, 566) of the 1080p frame, Vivillon's name
    at item 4: readers/test/images/mystery-gift's gift-list-cursor-on-1 and
    gift-list-fr-cursor-on-1). [None] when the span does not claim the Internet
    gift (the code alone, no gift, a start past the list, a stop on it); [Error]
    for another language, before any press. *)

val check : span -> (unit, string) result
(** The start and the stop are points of the mode's run, the stop after the
    start. *)
