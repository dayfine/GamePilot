(** What a program's chain needs of the save, as [gamepilot programs] prints it:
    the free party slots (Frlg_checkpoints.Party_room) and the field moves its
    plans use (Frlg_checkpoints.Plan_needs). *)

val needs : string -> (string, string) result
(** The plan folder's chain: ["N free party slot(s); field moves: ..."]. *)
