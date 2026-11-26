(** FireRed's shared game actions as the plans name them, each with its args
    read and checked before anything is pressed. Pure: {!Game_actions} performs
    them. *)

type swap = By_species of string * int | Slots of int * int

(** The members a PC deposit stores. *)
type deposit =
  | Members of string list  (** These species, in order. *)
  | Holding_no_mail
      (** The first member, slot 1 first, whose party mark is not Mail: the one
          member the PC takes when the others hold Mail. *)

type t =
  | Mart of Mart_plan.t
  | Use_item of { item : string; on : Action_args.member option }
  | Give_bag_item of { item : string; to_ : Action_args.member }
  | Party_swap of swap
  | Buy_coins of int
  | Redeem_prize_mon of int
  | Ingame_trade of { offer : string; receive : string option }
  | Spin_for_encounter of { max_batches : int }
  | Cut_tree of Grid_geometry.Direction.t
  | Verify_mail_glitch of Action_args.member
  | Pc_deposit of deposit
  | Pc_withdraw
  | Pick_up_item of string
  | Read_caught of { at_least : int option }

val names : string list
(** The action names {!decode} accepts, used to validate plan action names and
    suggest close matches on typos. *)

val default_spin_batches : int
(** ["spin_for_encounter"]'s ["max_batches"] when left out: 25. *)

val decode :
  Mart_plan.stocks ->
  string ->
  Json_field.obj ->
  (t, Pokemon_engine.Failure.cause) result
(** The action of that name with its args; [bad_args] naming the field, or
    [unknown_action]. The args:
    - [mart]: see {!Mart_plan.t}.
    - [use_item]: ["item"], and ["species"] or ["target_slot"] for an item used
      on a member.
    - [give_bag_item]: ["item"], and ["species"] or ["target_slot"].
    - [party_swap]: ["species"] and ["target_slot"], or ["slot_a"] and
      ["slot_b"].
    - [buy_coins]: ["coins"]. [redeem_prize_mon]: ["slot"] from 0.
    - [ingame_trade]: ["species"] offered, optional ["receive"].
    - [spin_for_encounter]: optional ["max_batches"].
    - [cut_tree]: ["direction"].
    - [verify_mail_glitch]: ["species"] or ["target_slot"].
    - [pc_deposit]: ["species"], a list of the members to store, or ["member"]:
      ["holding_no_mail"] ({!Holding_no_mail}), facing a Pokémon Center's PC
      ({!Pc_deposit}).
    - [pc_withdraw]: no args: the first Pokémon in the box the PC opens on moved
      into the party, facing a Pokémon Center's PC ({!Pc_withdraw}).
    - [pick_up_item]: ["item"], the item the player faces (a hidden item, an
      item ball): a talk, as the plan's [talk] event, that names what it gains
      so a pre-flight counts it ({!Frlg_checkpoints.Plan_needs}).
    - [read_caught]: optional ["at_least"]: the count of species caught, read
      off the Trainer Card ({!Trainer_card_caught}) and logged; below [at_least]
      it fails. *)

val to_string : t -> string
(** One line, for logs and tests. *)
