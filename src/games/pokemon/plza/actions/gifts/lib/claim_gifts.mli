(** Claiming PLZA's Mystery Gifts and putting them in Box 1, saved:
    [plza_claim_and_bank.sh] from the BDSPLab lab tools (console B, 2026-11-20),
    its stages 1 to 3, as one call. From the overworld, with five Pokémon in the
    party and Box 1 empty: the Internet gift (the 4th, Vivillon) lands in party
    slot 6, the code's gift (Xerneas for CELEBRATE30TH) in Box 1 slot 1; the
    Vivillon goes to Box 1 slot 2; PLZA is saved and closed
    ({!Switch_home.Game_entry.close_game}).

    Each step's screens are read ({!Mystery_gift}, {!Gift_to_box}); the first
    one not seen ends the call with an error naming it. *)

(** Where to start, as the script's flags: [From_internet] (none), [From_code]
    ([--code-only]: the menu and Mystery Gift again, then the code),
    [From_boxes] ([--from-boxes]: the menu, then the move and the save). *)
type start = From_internet | From_code | From_boxes

val default_code : string
(** CELEBRATE30TH, the script's default. *)

val run :
  log:(string -> unit) ->
  picture:Wire.box ->
  assets:Plza_readers.Blob_assets.t ->
  tile:Switch_home.Home_screen.tile_color ->
  start:start ->
  stop_at_list:bool ->
  code:string ->
  (unit, string) result
(** With [stop_at_list] (and [From_internet]): stops once the Internet gift list
    is active, having claimed nothing, the console left on the list (the first
    console run's safe point). [assets] are the PLZA readers' uploaded templates
    (the main menu's buttons); [tile] is PLZA's colour for the HOME reader that
    closes the game. *)
