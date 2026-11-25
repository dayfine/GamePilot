type t = Engine_rules.Zone_pose.t

let pose ({ place; spot } : Engine_rules.Zone_pose.t) =
  match spot with Some s -> place ^ "/" ^ s | None -> place

let observed = pose
