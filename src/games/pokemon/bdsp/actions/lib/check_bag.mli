(** Reusable BDSP action to traverse Bag pockets and snapshot pages. *)

type pocket_snapshot = {
  pocket : Bdsp_readers.Bag_pocket_reader.pocket;
      (** Bag pocket tab to visit. *)
  pages : int;  (** Number of pages (>= 1) to snapshot in [pocket]. *)
}
(** One pocket inspection entry in a Bag check plan. *)

type game_steps = {
  open_bag : unit -> (unit, string) result;
      (** Open the X menu and enter the Bag screen. *)
  switch_pocket :
    from:Bdsp_readers.Bag_pocket_reader.pocket ->
    to_:Bdsp_readers.Bag_pocket_reader.pocket ->
    unit;
      (** Navigate from the current pocket tab [from] to [to_]. *)
  scroll_page : unit -> unit;
      (** Advance the active pocket list down by one page of items. *)
  snapshot : pocket:Bdsp_readers.Bag_pocket_reader.pocket -> page:int -> unit;
      (** Capture or record one-based [page] of [pocket]. *)
  close_bag : unit -> unit;
      (** Close the Bag and X menu back to the overworld. *)
}
(** Game reads and inputs needed to inspect Bag pockets in BDSP. *)

val run :
  game_steps ->
  start_pocket:Bdsp_readers.Bag_pocket_reader.pocket ->
  pocket_snapshot list ->
  (int, string) result
(** Validate every {!pocket_snapshot} ([pages >= 1]), open the Bag, visit each
    requested pocket starting from [start_pocket], snapshot each page, and close
    back to the overworld. Returns the total number of snapshots taken. *)

val live_game_steps :
  log:(string -> unit) ->
  on_snapshot:(pocket:Bdsp_readers.Bag_pocket_reader.pocket -> page:int -> unit) ->
  picture:Wire.box ->
  game_steps
(** Live BDSP Switch steps for {!run}, reusing {!Overworld_actions} and
    {!Bdsp_readers.Bag_pocket_reader.pocket_steps}. *)
