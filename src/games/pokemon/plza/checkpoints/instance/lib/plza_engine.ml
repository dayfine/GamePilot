include
  Program_engine.Make (Plza_rules) (Plza_plan_format) (Plza_text)
    (Plza_event_snapshot)

module Pose = Plza_rules.Pose
module Walk_args = Plza_rules.Walk_args
module Saved = Plza_event_snapshot
