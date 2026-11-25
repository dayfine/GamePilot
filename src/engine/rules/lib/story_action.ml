type t = Talk | Answer of bool | Scene | Save

let to_string = function
  | Talk -> "talk"
  | Answer yes -> if yes then "answer yes" else "answer no"
  | Scene -> "scene"
  | Save -> "save"
