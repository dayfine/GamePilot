(** The engine over the toy game ({!Toy_rules}, read by {!Toy_plan_format}, kept
    by {!Toy_event_snapshot}). *)

include module type of struct
  include Program_engine.Make (Toy_rules) (Toy_plan_format) (Toy_event_snapshot)
end
