(** What the in-game save does on each screen after the first YES/NO shows, the
    fork's [SaveDialog] (AutoStory/PokemonFRLG_AutoStorySave.h and
    PokemonFRLG_AutoStoryActions.cpp, [frlg/lean]): every YES/NO gets YES, a
    page with the arrow gets A, text without one is waited out, the Start menu
    coming back means a NO was taken, and two looks at nothing in a row end it:
    the overworld if no page came after the last YES, else a save error. B is
    never pressed. Pure; {!Game_save} reads the screens and presses. *)

type screen =
  | Yes_no
  | Paged_text  (** A message with the arrow for the next page. *)
  | Text  (** A message without an arrow: SAVING, or saved. *)
  | Start_menu
  | Nothing
      (** No message and no menu: the overworld, or a frame between two. *)

type action =
  | Wait
  | Answer_yes
  | Next_page
  | Check_overworld  (** Confirm the overworld (START opens the menu): saved. *)
  | Fail_cancelled  (** The Start menu is back: a YES/NO was answered NO. *)
  | Fail_error  (** A paged message after the last YES: "Save error." *)

type t

val start : t
val next : t -> screen -> t * action
val screen_name : screen -> string
val action_name : action -> string
