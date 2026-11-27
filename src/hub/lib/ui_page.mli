(** Single-page HTML/CSS/JS dashboard served at [GET /] by [gamepilot ui]. *)

val html : string
(** Self-contained dark-mode control hub showing configured consoles, a dynamic
    program launcher built from [/api/programs], and live run logs. *)
