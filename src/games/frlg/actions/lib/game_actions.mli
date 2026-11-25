(** Performs FireRed's shared game actions ({!Action_requests}) as story
    handlers, and keeps the reckoned party ({!Party_roster}) up to date: a swap
    swaps it, a trade replaces the member, a prize joins it. *)

type context = {
  log : string -> unit;
  party : Party_roster.t ref;
  facing : unit -> Grid_geometry.Direction.t option;
      (** Where the player faces, when known (the spin starts from it). *)
  stocks : unit -> (Mart_plan.stocks, string) result;
}

val perform :
  context ->
  Action_requests.t ->
  (unit, Pokemon_checkpoints.Failure.cause) result
(** Runs the action. An in-game trade whose offer is gone and whose [receive] is
    in the party already passes without a press (it ran before this save). *)

val handlers : context -> (string * Pokemon_checkpoints.Game.game_action) list
(** One handler per {!Action_requests.names}: decode, then {!perform}; then
    mg-06's ({!Mail_glitch_use.handlers}) and the Rare Candy ones
    ({!Candy_actions.handlers}), and the ACE setup's ({!Ace_mail.handlers}). *)
