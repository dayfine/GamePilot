include
  Engine_checkpoints.Make (Pokemon_terms) (Pokemon_plan_codec) (Pokemon_text)
    (Pokemon_saved)

module Pose = Pokemon_terms.Pose
module Own_kind = Pokemon_terms.Own_kind
module Postconditions = Pokemon_terms.Postconditions
module Postcondition_check = Pokemon_terms.Postcondition_check
module Pose_text = Pokemon_text.Pose_text
module Postconditions_text = Pokemon_text.Postconditions_text
module Saved = Pokemon_saved
