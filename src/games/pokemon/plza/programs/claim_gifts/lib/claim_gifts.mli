(** What [plza.claim-gifts] decides: which of the catalog's gifts a run claims,
    where each one's Pokémon must be after it, and how each gift came out. Its
    plan's events are these game actions, in order, sharing one {!run}:

    - [gifts_start]: today's date (UTC, the run's input) and the catalog
      printed; the main menu opened and the party read ({!party}). A party of
      five or six with full HP is needed: with five, the first gift's Pokémon
      lands in party slot 6, with fewer more than one would.
    - [claim_gifts]: each gift in the catalog's order. A gift whose last day is
      before today is skipped, with a log line; a HOME gift is not supported
      yet; any other is claimed ({!Gift_claim.claim}). A gift not received is
      failed and the run goes on to the next one, unless the main menu is lost
      ([screen_lost]: the gifts after it are not tried).
    - [check_gift_slots]: each received gift's Pokémon read in its catalog box
      slot, the one in party slot 6 moved there first ({!Gift_boxes.check}); an
      empty slot fails that gift.
    - [save_progress]: saved when any gift was received ({!Save_progress}).
    - [report_gifts]: one line a gift (id, name, how, last day, outcome);
      [gifts_failed] naming each gift that failed.

    Every failure repeats: a retry would reload the latest autosave and lose the
    gifts not yet saved. Ours: the fork has no Mystery Gift program. *)

(** The party, as the main menu's cards show it. *)
type party =
  | Full  (** Six Pokémon: every gift lands in a box. *)
  | Room_for_one  (** Five: the first gift lands in party slot 6. *)

(** What the main menu read at the start. *)
type party_read =
  | Party of party  (** Five or six Pokémon at full HP. *)
  | No_menu of string  (** No main menu, after X; why. *)
  | Not_ready of string  (** Not five or six Pokémon at full HP; what read. *)

(** How one gift came out. *)
type outcome =
  | Claimed  (** Received, and (a Pokémon) found in its box slot. *)
  | Already_received  (** The game says the save has it: done. *)
  | Expired  (** Its last day is before today: not tried. *)
  | Not_supported of string  (** Claimed some way the program cannot yet. *)
  | Failed of string  (** Not received, or not in its box slot; why. *)
  | Not_tried  (** The run stopped before it. *)

type game_steps = {
  read_party : unit -> party_read;
      (** Open the main menu (X from the overworld) and read its party cards. *)
  claim : Plza_gift_catalog.Gift_catalog.gift -> Gift_claim.claim;
      (** Claim one gift, from the main menu back to it. *)
  check_slots :
    party_gift:Plza_gift_catalog.Gift_catalog.box_slot option ->
    in_box:Plza_gift_catalog.Gift_catalog.box_slot list ->
    ( (Plza_gift_catalog.Gift_catalog.box_slot * Gift_boxes.slot_read) list,
      string )
    result;
      (** Read the box slots, the party slot 6 gift moved to its slot first. *)
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
(** The five actions above, by the names the plan gives them. Each takes no
    args. *)

val check_plan : Plza_engine.Plan.t -> (unit, string) result
(** Before the console moves: the plan's events are all these game actions, and
    its execution is empty. *)
