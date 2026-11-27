(** Reusable BDSP action to teach a TM from the overworld. *)

type request = {
  tm_row : int;  (** Zero-based row of the TM in the Bag's TMs pocket. *)
  party_slot : int;  (** One-based party slot ([1..6]) of the recipient. *)
  replace_move_slot : int option;
      (** Optional one-based move slot ([1..4]) to overwrite when the Pokémon
          already knows four moves; [None] when a free move slot exists. *)
}
(** Parameters for teaching one TM to a party Pokémon. *)

type game_steps = {
  open_tm_pocket : unit -> (unit, string) result;
      (** Open the X menu, enter the Bag, and switch to the TMs pocket. *)
  select_tm : int -> unit;
      (** Scroll to [tm_row] in the TMs pocket and choose Use. *)
  choose_party_slot : int -> (unit, string) result;
      (** Pick the one-based [party_slot] to learn the TM. *)
  replace_move : int option -> (unit, string) result;
      (** Overwrite the optional one-based move slot and advance the learned
          move dialog. *)
  close_to_overworld : unit -> unit;
      (** Back out of the Bag and X menu to the overworld. *)
  log : string -> unit;  (** Emit a progress log line. *)
}
(** Game reads and inputs needed to teach a TM in BDSP. *)

val run : game_steps -> request -> (unit, string) result
(** Validate [request] ([tm_row >= 0], [party_slot] in [1..6], and optional
    [replace_move_slot] in [1..4]), open the TMs pocket, teach the TM, and close
    back to the overworld. *)

val live_game_steps :
  start_pocket:Bdsp_readers.Bag_pocket_reader.pocket ->
  log:(string -> unit) ->
  picture:Wire.box ->
  game_steps
(** Live BDSP Switch steps for {!run}, starting from the overworld with Bag
    selected on the X menu and the Bag opening on the Medicine pocket. *)
