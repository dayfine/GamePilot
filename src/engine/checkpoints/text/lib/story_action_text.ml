let action : Engine_rules.Story_action.t -> string = function
  | Talk -> "talk"
  | Answer yes -> if yes then "answer yes" else "answer no"
  | Scene -> "scene"
  | Save -> "save"
