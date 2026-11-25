module Make (T : Engine_rules.GAME_RULES) = struct
  type part =
    | Text of string
    | Pose of T.Pose.t
    | Reason of Failure.Make(T).reason
    | Failure of Failure.Make(T).t

  type t = part list
end
