(** How a PLZA plan writes PLZA's rules ({!Plza_rules}): a pose is a zone
    ([{"place": "LumioseCity", "spot": ...}]), the action is [walk]
    ({!Walk_decode}), and [postconditions] is empty. *)

include Engine_plan_format.Plan_format.PLAN_FORMAT with module T = Plza_rules
