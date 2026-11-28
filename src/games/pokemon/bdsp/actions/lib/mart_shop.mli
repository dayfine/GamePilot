(** Reusable BDSP Poké Mart and Veilstone Department Store shopping action. *)

type purchase = {
  row : int;  (** Zero-based row index of the item in the Buy list. *)
  quantity : int;  (** Number of items to buy, in the range [1..99]. *)
}
(** One item purchase in a BDSP shop Buy menu. *)

type game_steps = {
  open_shop : unit -> (unit, string) result;
      (** Talk to the shop clerk and open the Buy item list. *)
  move_to_row : int -> unit;
      (** Move the Buy list cursor to the zero-based [row] and select it. *)
  set_quantity : int -> unit;
      (** Dial the quantity picker from 1 to the requested quantity. *)
  confirm_purchase : unit -> (unit, string) result;
      (** Confirm the quantity and purchase prompt, advancing the receipt
          dialog. *)
  close_shop : unit -> unit;
      (** Exit the Buy list and clerk dialog back to the overworld. *)
  log : string -> unit;  (** Emit a progress log line. *)
}
(** Game reads and inputs needed to buy items at a BDSP shop. *)

val run : game_steps -> purchase list -> (int, string) result
(** Validate every {!purchase} ([row >= 0], [quantity] in [1..99]), open the
    shop, buy each item in order, and close the shop. Returns the total number
    of items bought, or an error if validation fails or any step errors. *)

val live_game_steps : log:(string -> unit) -> picture:Wire.box -> game_steps
(** Live BDSP Switch steps for {!run}, assuming the player stands facing the
    shop clerk. *)
