(** Claiming PLZA's Mystery Gifts and putting them in Box 1, saved:
    [plza_claim_and_bank.sh] from the BDSPLab lab tools (console B, 2026-11-20),
    its stages 1 to 3. From the overworld, with five Pokémon in the party and
    Box 1 empty: the Internet gift (Vivillon, Poké Ball Pattern) lands in party
    slot 6, the code's gift (Xerneas for CELEBRATE30TH) in Box 1 slot 1; the
    Vivillon goes to Box 1 slot 2; PLZA is saved and closed
    ({!Switch_home.Game_entry.close_game}).

    The run is a chain of steps ({!Mystery_gift}, {!Gift_to_box}), each named by
    the screen it starts on ({!points}); a run can start on any of them and stop
    before any later one, the console left on that screen. Each step's screens
    are read; the first one not seen ends the run with an error naming it. *)

type span = {
  from : string;  (** the point the console is on: "overworld" from the start *)
  stop_at : string option;  (** the point to stop on, before its step *)
  code_only : bool;
      (** the script's [--code-only]: from the overworld, Mystery Gift, then
          straight to the code *)
}

val points : string list
(** The screens between the steps, in order: overworld (the start), mystery-gift
    (its menu), gift-list (the Internet list), card (the Internet gift's card),
    code (the Mystery Gift menu again), keyboard (the code keyboard), code-card
    (the code gift's card), disconnect (its list), after-gifts (the overworld,
    the gifts claimed), boxes (the Boxes), moved (the main menu, the gift
    moved), save (Save Progress's prompt), saved (the overworld, saved). *)

val default_code : string
(** CELEBRATE30TH, the script's default. *)

val run :
  log:(string -> unit) ->
  picture:Wire.box ->
  assets:Plza_readers.Blob_assets.t ->
  gift_name:string ->
  tile:Switch_home.Home_screen.tile_color ->
  span:span ->
  code:string ->
  (unit, string) result
(** The steps from [span.from] to [span.stop_at] (or the end). [assets] are the
    PLZA readers' uploaded templates (the main menu's buttons), [gift_name] the
    Internet gift's name template's; [tile] is PLZA's colour for the HOME reader
    that closes the game. [Error] before any press for an unknown point or a
    stop not after the start ({!check}). *)

val check : span -> (unit, string) result
(** The points are known, the stop after the start, the code alone from the
    overworld. *)
