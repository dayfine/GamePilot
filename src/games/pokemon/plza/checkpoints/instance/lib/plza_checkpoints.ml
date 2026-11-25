include
  Engine_checkpoints.Make (Plza_rules) (Plza_plan_codec) (Plza_text)
    (Plza_saved)

module Pose = Plza_rules.Pose
module Walk_args = Plza_rules.Walk_args
module Saved = Plza_saved
