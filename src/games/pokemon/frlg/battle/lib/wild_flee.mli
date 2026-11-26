(** Running from a wild battle on any {!Battle.game_steps}, as a state→action
    loop on what the battle shows: the action menu gets RUN, the battle's text
    is played on by the game steps ("Got away safely!", "Can't escape!"), and
    the battle is over once no battle screen shows. Whether the overworld then
    takes input is the caller's to read.

    A trainer's battle refuses RUN with its own text and the action menu comes
    back, as after "Can't escape!"; no reader tells the two apart yet, so after
    {!max_runs} refusals the flee gives up and reports, and the caller stops.

    Ported from the fork's flee (PokemonFRLG_Navigation.cpp, [frlg/lean]): RUN
    from the action menu until the battle is over, giving up after the same
    count. Where it differs: the fork waits on fixed timeouts between its
    presses; here each screen the battle shows decides the next press. *)

type outcome =
  | Fled of int  (** the battle is over after this many RUNs *)
  | Not_fled of string  (** why the battle is still on *)

val max_runs : int
(** 5, the fork's attempts before it gives up. A wild foe's escape odds rise
    with every attempt, so 5 refusals mean a trainer's battle or a foe that bars
    escape. *)

val event_timeout_ms : int
(** 20 s: the battle's opening (its wipe, "Wild ... appeared!", the send-out)
    before the first action menu. *)

val run : Battle.game_steps -> log:(string -> unit) -> outcome
val describe : outcome -> string
