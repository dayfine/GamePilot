(** Saving from the main menu with Save Progress, checked by its "Last Saved"
    time (moves and timings as run on console B, 2026-11-20): R (1.5 s) opens
    the SAVE dialog ({!Plza_readers.Save_dialog}), read held 1 s within 3 s with
    its "Last Saved"; A (3.5 s), A (1.5 s) save; the main menu must show again
    within 5 s; R again and "Last Saved" read again; B (1.5 s) closes the dialog
    and B (1.5 s) the menu. The save counts only when "Last Saved" changed. The
    probes must be subscribed ({!Mystery_gift.probes}). *)

val save : log:(string -> unit) -> (unit, string) result
(** Saved as above, back on the overworld. [Error] when the dialog or the menu
    does not show, or "Last Saved" did not change (not saved, or saved within
    the minute of the last save). *)
