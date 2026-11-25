(** How a PLZA plan writes PLZA's rules ({!Plza_rules}): a pose is a zone
    ([{"place": "LumioseCity", "spot": ...}]), the own kind is [walk]
    ({!Walk_decode}), and [postconditions] is empty. *)

include Engine_plan_codec.Plan_codec.PLAN_CODEC with module T = Plza_rules
