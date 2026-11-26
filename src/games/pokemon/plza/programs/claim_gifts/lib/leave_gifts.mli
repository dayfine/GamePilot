(** From any Mystery Gift screen back to the main menu, each press chosen by
    what the screen reads ({!Plza_readers.Mystery_gift_screen},
    {!Plza_readers.Main_menu_row}), held 1 s within 2.5 s:

    - the main menu: done;
    - a question with Yes highlighted ("stop receiving?" over the gift list,
      "disconnect?" off the Mystery Gift menu): A (2.5 s), yes;
    - a question with No highlighted: Up (80 ms, released 300) to Yes;
    - a message alone (no question, card or gift list under it, as
      "disconnected"): A (2.5 s) past it;
    - a gift's card, the gift list, the Mystery Gift menu, Link Play, any other
      screen, or one that did not hold: B (1.5 s).

    12 presses at most. A is pressed only on a question read with Yes
    highlighted or on a message read with no gift list under it: on the list, A
    would claim the selected gift (console B, 2026-11-25: B after a card toggled
    "stop receiving?" four times, and a fixed B, A, A, B to leave closed it and
    claimed the first item). B leaves the card for the list (console B, the same
    run). Ours, not yet run on a console past "stop receiving?": the
    "disconnect?" question and the "disconnected" message are taken to show as
    the other questions and messages do. *)

val to_main_menu : log:(string -> unit) -> (unit, string) result
(** Back on the main menu as above, a log line a press; [Error] with the last
    reading when it does not show after 12 presses. The probes must be
    subscribed ({!Mystery_gift.probes}). *)
