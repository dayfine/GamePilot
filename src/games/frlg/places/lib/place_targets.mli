(** Route targets that name a place, expanded into the events a plan wrote by
    hand before places existed (Programs-As-Goals section 3). A pure function
    from a plan's JSON to a plan's JSON, run when a plan is loaded, before
    {!Checkpoints.Plan_decode} and the runner see it: logs, event states and the
    watch page see plain events.

    A route whose [args.target] is [{"place": NAME}] becomes a route to the
    place's pose ({!Place_table.pose}). When the place is on a lift's floor
    other than the one the player stands on, it becomes three events, as the
    hand-written plans had them: the route (same id) to below this floor's lift
    door, [ID.lift] (a ["lift_floor"] ride, declaring where it lets the player
    out), and [ID.walk] from the lift to the place; the walk is left out when
    the lift lets the player out on the place itself. Leaving a lift's floors
    for a place elsewhere rides to the floor with the way out first
    ({!Lift_stops.way_out}), and arriving from elsewhere rides from it.

    Where the player stands is reckoned as the runner does: the checkpoint's
    [start], then each route's target, each ride's exit or each event's one-tile
    [declared_after]. A place route needs it known. *)

val expand :
  Place_table.t ->
  source:string ->
  Yojson.Safe.t ->
  (Yojson.Safe.t, string) result
(** The plan with every place route expanded; a plan with none comes back
    unchanged. Errors name [source] (the file) and the event: an unknown place
    (with the nearest names), an unknown position, or a route between two lifts.
    A plan whose shape is wrong otherwise is left for the decoder. *)
