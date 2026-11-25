(** Fragment calls in a plan, expanded into the fragment's events when the plan
    is loaded, before its place routes ({!Frlg_places.Place_targets}) and the
    decoder: logs, event states and the watch page see plain events.

    A call is an event that names a fragment instead of a kind:
    [{"id": "heal_lavender", "fragment": "heal_at", "args": {"town":
     "lavendertown"}, "why": "..."}]. It takes exactly the fragment's params,
    each a string. Each of the fragment's events gets the call's id (its own id
    a suffix: [heal_lavender.walk]), its own [why] or else the call's, and the
    call's [skip_if]. *)

val expand :
  Fragment_table.t ->
  source:string ->
  Yojson.Safe.t ->
  (Yojson.Safe.t, string) result
(** The plan with every fragment call expanded; a plan with none comes back
    unchanged. Errors name [source] (the file) and the call: an unknown fragment
    (with the nearest names), a field a call does not take, or args that are not
    the fragment's params. A plan whose shape is wrong otherwise is left for the
    decoder. *)
