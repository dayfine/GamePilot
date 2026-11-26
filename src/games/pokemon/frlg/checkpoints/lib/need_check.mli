(** Each need of the pre-flight ({!Preflight}) judged on what was read of the
    save: the party and its held-item marks, the members' moves, the money, the
    bag, the Trainer Card, the Pokédex count and the frame at the start. One row
    a need: what it needs, what was read, and the verdict. *)

type read = {
  observed : Pokemon_engine.Postcondition_check.observed;
      (** The party, its held-item marks, the money, the bag and the Pokédex
          count, as {!Postcondition_reads.observe} read them. *)
  place : Frlg_readers.Start_frame.difference option;
      (** The frame after the load against the one kept at the start; [None]
          when none was kept or the frame did not read. *)
  members : Room_policy.member list option;
      (** Each member's species, level and moves on its summary
          ({!Frlg_actions.Party_summary}): the field moves and the room are
          judged on them. [None] when not read. *)
  card : Frlg_readers.Trainer_card_front.t option;
      (** The badges and stars on the Trainer Card
          ({!Frlg_actions.Trainer_card_badges}); [None] when not read. *)
}
(** What the pre-flight read of the loaded save. *)

(** [Ok]: the save holds it; [Mismatch]: it does not; [Not_read]: what judges it
    was not read. *)
type verdict = Ok | Mismatch | Not_read

type row = { need : string; read : string; verdict : verdict }
(** A line of the pre-flight's table: the need and the read in words. *)

val row : read -> Need.t -> row
(** The need judged on the read. A field move needs a member whose moves were
    read; an [Anywhere_start] passes unread (the first Fly checks it). *)
