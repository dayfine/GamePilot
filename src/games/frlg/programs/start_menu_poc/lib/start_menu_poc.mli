(** Program: open FireRed's Start menu and close it again.

    load_state (when given one), subscribe {!Menu_panel.probe}, press Start,
    await the menu, press B, await it gone. Uses only the effects. *)

module Menu_panel = Menu_panel
(** The menu panel reader the recorded runs used. *)

type outcome =
  | Passed of { opened_ms : float; closed_ms : float }
      (** daemon-clock ms from each press's [batch_done] to the frame that
          showed the change; 0 when it already showed at [batch_done] *)
  | Did_not_open
  | Did_not_close

val default_state : string
(** [overworld.ss] under [$GAMEPILOT_STATES], else under
    [~/.local/share/gamepilot/states]; [~] is [HOME] or, on Windows,
    [USERPROFILE]. *)

val timeout_ms : int
(** Per await: 3000. *)

val run : ?state:string -> unit -> outcome
(** Without [state], from the screen as it is (the Switch, in the overworld). *)

val describe : outcome -> string
(** One line. *)
