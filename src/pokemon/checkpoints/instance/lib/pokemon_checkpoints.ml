include
  Engine_checkpoints.Make (Pokemon_rules) (Pokemon_plan_codec) (Pokemon_text)
    (Pokemon_saved)

module Pose = Pokemon_rules.Pose
module Pokemon_action = Pokemon_rules.Pokemon_action
module Postconditions = Pokemon_rules.Postconditions
module Postcondition_check = Pokemon_rules.Postcondition_check
module Pose_text = Pokemon_text.Pose_text
module Postconditions_text = Pokemon_text.Postconditions_text
module Saved = Pokemon_saved
