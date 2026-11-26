(** What [plza.claim-gifts] decides: which of the catalog's gifts a run claims,
    where each one's Pokémon must be after it, and how each gift came out. Its
    plan's events are these game actions, in order, sharing one {!run}:

    - [gifts_start]: today's date (UTC, the run's input) and the catalog
      printed; the main menu opened and the party read ({!party}). A party of
      five or six with full HP is needed.
    - [settle_boxes]: the Boxes opened on Box 1 and closed there
      ({!Gift_boxes.settle}), with the slots of the Pokémon gifts not past their
      last day nor received in HOME: a gift an earlier run left in party slot 6
      is moved to the first of them that is empty, and each is read and logged.
      Box 1 is then the box the game puts a gift in when the party is full; with
      five, the first gift received lands in party slot 6.
    - [claim_gifts]: each gift in the catalog's order. A gift whose last day is
      before today is skipped, with a log line; a HOME gift is not supported
      yet; any other is claimed ({!Gift_claim.claim}). One the game says was
      received or its code used before is already received; one not received is
      failed and the run goes on to the next one, unless the main menu is lost
      ([screen_lost]: the gifts after it are not tried).
    - [check_gift_slots]: the Boxes settled again with the slots of the Pokémon
      gifts received now, the one in party slot 6 moved to the first empty one;
      each must then hold a Pokémon, else [gifts_not_in_place] names each gift
      that does not (it fails) and the run stops before the save.
    - [save_progress]: saved when any gift was received or a Pokémon moved
      ({!Save_progress}).
    - [report_gifts]: one line a gift (id, name, how, last day, outcome);
      [gifts_failed] naming each gift that failed.

    Every failure repeats: a retry would reload the latest autosave and lose the
    gifts not yet saved. Ours: the fork has no Mystery Gift program. *)

(** The party, as the main menu's cards show it. *)
type party =
  | Full
      (** Six Pokémon: every gift lands in a box. The sixth is taken for a gift
          an earlier run left there ({!Gift_boxes}). *)
  | Room_for_one  (** Five: the first gift lands in party slot 6. *)

(** What the main menu read at the start. *)
type party_read =
  | Party of party  (** Five or six Pokémon at full HP. *)
  | No_menu of string  (** No main menu, after X; why. *)
  | Not_ready of string  (** Not five or six Pokémon at full HP; what read. *)

(** How one gift came out. *)
type outcome =
  | Claimed  (** Received, and (a Pokémon) read in its box slot. *)
  | Already_received
      (** The game says it was received, or its code used, before (it may be in
          HOME by now): done. *)
  | Expired  (** Its last day is before today: not tried. *)
  | Not_supported of string  (** Claimed some way the program cannot yet. *)
  | Failed of string  (** Not received, or not in its box slot; why. *)
  | Not_tried  (** The run stopped before it. *)

type game_steps = {
  read_party : unit -> party_read;
      (** Open the main menu (X from the overworld) and read its party cards. *)
  claim : Plza_gift_catalog.Gift_catalog.gift -> Gift_claim.claim;
      (** Claim one gift, from the main menu back to it. *)
  settle_boxes :
    Plza_gift_catalog.Gift_catalog.box_slot list ->
    (Gift_boxes.settled, string) result;
      (** Open the Boxes on Box 1, move party slot 6's Pokémon to the first of
          these slots (in the order received) that is empty and read each, from
          the main menu back to it. *)
  save : unit -> (unit, string) result;  (** Save from the main menu. *)
  log : string -> unit;  (** A line for the log and the watch page. *)
}
(** What the decisions read and do in the game. *)

type run
(** One run's gifts and what came of each, shared by its events. *)

val start :
  Plza_gift_catalog.Gift_catalog.t ->
  today:Plza_gift_catalog.Gift_catalog.date ->
  run
(** A run of the catalog on [today], nothing tried yet. *)

val outcomes : run -> (Plza_gift_catalog.Gift_catalog.gift * outcome) list
(** Each gift and its outcome so far, in the catalog's order. *)

val outcome_text : outcome -> string
(** ["claimed"], ["expired"], ["failed: <why>"], ... *)

val game_actions :
  game_steps -> run -> (string * Plza_engine.Game.game_action) list
(** The six actions above, by the names the plan gives them. Each takes no args.
*)

val check_plan : Plza_engine.Plan.t -> (unit, string) result
(** Before the console moves: the plan's events are all these game actions, and
    its execution is empty. *)
