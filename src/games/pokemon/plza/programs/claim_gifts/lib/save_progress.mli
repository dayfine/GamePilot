(** Saving from the main menu with Save Progress, checked by its "Last Saved"
    time (moves and timings as run on console B, 2026-11-20): R (1.5 s) opens
    the SAVE dialog ({!Plza_readers.Save_dialog}), read held 1 s within 3 s with
    its "Last Saved" and its current time; then the dialog read, up to 65 s,
    until its current time reads another minute, held 1 s; A (3.5 s), A (1.5 s)
    save; the main menu must show again within 5 s; R again and "Last Saved"
    read again; B (1.5 s) closes the dialog and B (1.5 s) the menu. The save
    counts only when "Last Saved" changed.

    Waiting for the minute makes the save's own minute differ from any save
    before it: the game may have saved in the minute the dialog opens in
    (console B, 2026-11-26: "Last Saved" and the current time both 12:12 before
    the A), and a save then leaves "Last Saved" as it was. The two times are set
    in different types and sizes, so they are not compared; "Last Saved" changed
    after the minute did means it shows the save's minute. Ours: the fork's PLZA
    programs do not save from this dialog. The probes must be subscribed
    ({!Mystery_gift.probes}). *)

val save : log:(string -> unit) -> (unit, string) result
(** Saved as above, back on the overworld. [Error] when the dialog or the menu
    does not show, the current time does not change within 65 s (no A pressed),
    or "Last Saved" did not change. *)
