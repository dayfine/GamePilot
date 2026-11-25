(** One read of the screen as 01.00a ({!New_game_intro}) reads it: the HOME
    menu, the new game's screens before Confirm Choices
    ({!Plza_readers.Intro_screens}), the name keyboard's cursor and text field
    ({!Switch_home.Keyboard_typing}) and Confirm Choices. *)

type t = {
  home : bool;  (** The HOME menu, lit (a dimmed one is not read). *)
  language_entry : int option;
      (** {!Plza_readers.Intro_screens.language_entry}. *)
  look_picker : bool;  (** {!Plza_readers.Intro_screens.look_picker_shown}. *)
  look : int option;  (** {!Plza_readers.Intro_screens.highlighted_look}. *)
  name_keyboard : bool;
      (** {!Plza_readers.Intro_screens.name_keyboard_shown}. *)
  keyboard_cursor : Switch_home.Code_keyboard.key option;
      (** {!Switch_home.Code_keyboard.cursor}. *)
  text_pixels : int;  (** {!Switch_home.Keyboard_typing.text_pixels}. *)
  confirm_choices : bool;
      (** Confirm Choices' highlight reads ({!Plza_readers.Confirm_choices}). *)
}

val nothing : t
(** A screen on which nothing reads. *)
