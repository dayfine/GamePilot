(** Plays a {!Battle_script} on a {!Battle.game_steps} from anywhere in a battle
    (its opening included) to its end: each event the game steps report gets the
    script's answer, until the battle is over or the script has none. Level-ups,
    move learns and evolutions are decided by {!Level_up}. *)

type summary = {
  menus : int;  (** action menus answered *)
  send_ins : int;  (** members sent in after a faint *)
  refusals : int;  (** moves the game turned down *)
  switches_refused : int;
      (** switches the game turned down, under {!Battle_script.t}'s
          [switch_refused] *)
  prompts : int;  (** YES/NO prompts and level-up phases answered *)
  learned : string list;  (** moves learned, as read; the latest first *)
}
(** Counts of what happened in one battle. *)

(** How {!run} ended. *)
type outcome =
  | Over of summary
      (** The battle left the screen: won, run from, or lost; the caller reads
          which from the screen after it. *)
  | Failed of { why : string; summary : summary }
      (** The script had no answer or the game steps could not carry it out. The
          game is left as it was, in the battle. *)

val empty_summary : summary
(** Nothing answered yet. *)

val run :
  ?log:(string -> unit) -> Battle.game_steps -> Battle_script.t -> outcome
(** [log] gets a line per event and per command. *)

val describe : outcome -> string
(** One line. *)
