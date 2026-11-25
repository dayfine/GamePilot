(** Fragment calls in a plan, expanded into the fragment's events when the plan
    is loaded, before a game's own rewriters (Pokémon's place routes) and the
    decoder: logs, event states and the watch page see plain events.

    A call is an event that names a fragment instead of a kind:
    [{"id": "heal_lavender", "fragment": "heal_at", "args": {"town":
     "lavender"}, "why": "..."}]. It takes exactly the fragment's params, each a
    string. Each of the fragment's events gets the call's id (its own id a
    suffix: [heal_lavender.walk]), its own [why] or else the call's, and the
    call's [skip_if]. *)

type resolve =
  kind:string -> string -> field:string option -> (string, string) result
(** The game's answer for a placeholder: the argument of a parameter of that
    kind, itself ([field = None]) or a field of what it names ([{town.nurse}]);
    an error for an unknown key (with the nearest) or field. *)

val expand :
  Fragment_table.t ->
  resolve ->
  source:string ->
  Yojson.Safe.t ->
  (Yojson.Safe.t, string) result
(** The plan with every fragment call expanded; a plan with none comes back as
    it was. Errors name [source] (the file) and the call: an unknown fragment
    (with the nearest names), a field a call does not take, args that are not
    the fragment's params, or the game's. *)
