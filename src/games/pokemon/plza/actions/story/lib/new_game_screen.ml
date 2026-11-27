type t = {
  home : bool;
  language_entry : int option;
  look_picker : bool;
  look : int option;
  name_keyboard : bool;
  keyboard_cursor : Switch.Code_keyboard.key option;
  text_pixels : int;
  confirm_choices : bool;
}

let nothing =
  {
    home = false;
    language_entry = None;
    look_picker = false;
    look = None;
    name_keyboard = false;
    keyboard_cursor = None;
    text_pixels = 0;
    confirm_choices = false;
  }
