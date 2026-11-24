(** What a checkpoint's plan needs of the save before its first event, for the
    pre-flight ({!Preflight}): each party member an action names unless an
    earlier event brings it, some member knowing Cut, the money its purchases
    cost, the bag items it gives or uses, what the checkpoint before it
    promised, and the place. *)

type need =
  | Party_in_order of string list
  | Party_includes of { members : string list; slots : Story.Plan.slot list }
  | Member of { species : string; for_ : string }
      (** A member an event uses ([for_]: ["fly"]). *)
  | Knows_move of { move : string; for_ : string }
      (** Some member knows this field move: a [cut_tree] event's Cut, which the
          game lets any member that knows it use. *)
  | Money_at_least of { amount : int; for_ : string }
  | Money_between of { min : int; max : int }
  | Item_at_least of { item : string; count : int; for_ : string }
  | Item_exactly of { item : string; count : int }
  | Place of string  (** The checkpoint's start map. *)

val needs :
  Frlg_actions.Mart_plan.stocks ->
  before:Story.Plan.postconditions option ->
  Story.Plan.t ->
  need list
(** What the save must hold for the plan's first event, in the table's order:
    the party, the money, the items, the place. Raises
    {!Grid_maps.Json_field.Invalid} for a plan arg that does not read. *)
