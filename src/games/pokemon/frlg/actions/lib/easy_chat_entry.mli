(** Writes words into the Easy Chat mail editor, field after field, each one
    found and checked on screen (pokefirered easy_chat_2.c: A on a field opens
    the group grid, A on a group its word list, A on a word puts it in the field
    and goes back to the fields). Not in the fork.

    The grid lists only the groups the save has unlocked and the POKéMON group
    only the species seen, so nothing is counted from the data: in the grid and
    in the list the cursor goes DOWN a row at a time until its row shows the
    target (both cells read against the candidates,
    {!Frlg_text.Easy_chat_words}), then to its column, and A only once the
    cursor ({!Frlg_readers.Easy_chat_screen}) is on it. Each field is read back
    after its word ({!Frlg_text.Mail_fields.read_field}), before the next one.

    English only: the group names and words are read against the English game's
    ({!Frlg_text.Easy_chat_words}), in its font; another language's editor does
    not read. *)

type word = { group : string; word : string }
(** A word and the group it is taken from, as the grid names it (["MOVE 2"],
    ["BULK UP"]). *)

val max_rows : int
(** Rows a scan goes down before it gives up: 130 (POKéMON2's 251 words take
    126). *)

val field_row : int -> int
(** Field [i] (from 0) is on row [i / 2]. *)

val field_col : int -> int
(** ... and column [i mod 2]. *)

val moves_to_next_field : int -> Wire.button list
(** From field [i] to field [i + 1]: RIGHT from a row's first field, DOWN and
    LEFT from its second (pokefirered easy_chat_2.c). *)

type game_steps = {
  read_cursor : unit -> Frlg_readers.Easy_chat_screen.cell;
  read_cell : row:int -> col:int -> string option;
  press : Wire.button -> unit;
}
(** What the scan reads and presses: the cursor's cell (failing as
    [easy_chat_no_cursor] when none reads), what a shown cell reads (one of the
    candidates, or [None]), a press and its wait. *)

val scan : game_steps -> what:string -> target:string -> int -> unit
(** In the group grid or a word list: DOWN a row at a time, at most this many
    rows, until a cell of the cursor's row reads [target], then LEFT or RIGHT
    onto it, where the cursor must read. Fails as [easy_chat_not_found] (no row
    showed it) or [easy_chat_no_cursor]. [what] (["group"], ["word"]) names it
    in the failure. *)

val check_unchanged : count:int -> unit
(** The first [count] fields read ["???"]: the ? Mail on an empty Box 3 slot 1
    (pomeg-letterbombers' Mail Glitch notes). Fails as [not_question_mark_mail]
    naming the first field that does not. *)

val write : log:(string -> unit) -> word list -> unit
(** From the fields with the cursor on field 1: each word into the next field,
    read back right after it is typed. Fails as [bad_args] (a word not in its
    group), [easy_chat_no_cursor], [easy_chat_not_found] or [mail_word_wrong],
    before START: nothing is kept. *)
