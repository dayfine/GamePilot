(** How a PLZA plan writes PLZA's rules ({!Plza_rules}): a pose is a zone
    ([{"place": "LumioseCity", "spot": ...}]), the action is [walk]
    ({!Walk_decode}), and [postconditions] names at most a [place], written as a
    start signature is ([{"minimap": "after-taunie-battle"}]). *)

include Engine_plan_format.Plan_format.PLAN_FORMAT with module T = Plza_rules

val signature_of_plan :
  Yojson.Safe.t -> (Plza_rules.Screen_signature.t, string) result
(** A start signature or a [place], as a plan writes it: an object of the fields
    {!Plza_rules.Screen_signature} names, at least one. [Error] says what is
    wrong (["names nothing"]) for the caller to name the field. A minimap's name
    is not checked here: the readers record them. *)
