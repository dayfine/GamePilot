(** Plays a {!Battle_script} on a {!Battle_driver} from anywhere in a battle
    (its opening included) to its end: each event the driver reports gets the
    script's answer, until the battle is over or the script has none. *)

type summary = {
  menus : int;  (** action menus answered *)
  send_ins : int;  (** members sent in after a faint *)
  refusals : int;  (** moves the game turned down *)
  prompts : int;  (** YES/NO prompts answered *)
}

type outcome =
  | Over of summary
      (** The battle left the screen: won, run from, or lost; the caller reads
          which from the screen after it. *)
  | Failed of { why : string; summary : summary }
      (** The script had no answer or the driver could not carry it out. The
          game is left as it was, in the battle. *)

val run : ?log:(string -> unit) -> Battle_driver.t -> Battle_script.t -> outcome
(** [log] gets a line per event and per command. *)

val describe : outcome -> string
(** One line. *)
