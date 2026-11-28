(** What a checkpoint's plan needs of the save before its first event, for the
    pre-flight ({!Preflight}): each party member an action names unless an
    earlier event brings it, no Mail on a member of the save it deposits
    ([pc_deposit]), some member knowing Cut or Fly, the badge each field move
    needs, the money its purchases cost, the bag items it gives or uses that no
    earlier purchase or pickup ([pick_up_item]) of its own brought (a Rare Candy
    for [use_rare_candy] and [candy_level], the ball budget for [capture] and
    [wild_rng]), what the checkpoint before it promised, and the place. Each is
    a {!Need.t}. *)

val needs :
  ?options:Run_options.t ->
  Frlg_actions.Mart_plan.stocks ->
  before:Pokemon_engine.Postconditions.t option ->
  Pokemon_engine.Plan.t ->
  (Need.t list, string) result
(** What the save must hold for the plan's first event, in the table's order:
    the party, the money, the items, the place. [options] (default
    {!Run_options.none}) applies CLI [--options] overrides such as [ball] and
    [balls] before computing the needs. [Error] for a plan arg that does not
    decode. *)
