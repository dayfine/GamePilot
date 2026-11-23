(** Program: open FireRed's Start menu and close it again.

    load_state, subscribe {!Frlg_readers.Start_menu.probe}, press Start, await
    the menu, press B, await it gone. Uses only the effects. *)

type outcome =
  | Passed of { opened_ms : float; closed_ms : float }
      (** daemon-clock ms from each press's [batch_done] to the frame that
          showed the change; 0 when it already showed at [batch_done] *)
  | Did_not_open
  | Did_not_close

val default_state : string
(** [overworld.ss] under [~/FRLGLab/mgba/gamepilot/states]; [~] is [HOME] or, on
    Windows, [USERPROFILE]. *)

val timeout_ms : int
(** Per await: 3000. *)

val run : state:string -> unit -> outcome

val describe : outcome -> string
(** One line. *)
