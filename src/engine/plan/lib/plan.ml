module type RAW = sig
  type t
end

module Make (T : Engine_rules.GAME_RULES) (Raw : RAW) = struct
  type kind =
    | Talk
    | Answer of bool
    | Scene
    | Save
    | Named_action of Raw.t
    | Game of T.Action.t

  type event = {
    id : string;
    kind : kind;
    way : string option;
    why : string;
    skip_if : string list;
    declared_after : T.Pose.t option;
    once_per_save : bool;
  }

  type checkpoint = {
    checkpoint_id : string;
    title : string;
    start : T.Pose.t option;
    end_flags : string list;
    events : event list;
  }

  type repeat = { until : T.Postconditions.t; max_rounds : int }

  type t = {
    game : string;
    checkpoint : checkpoint;
    execution : Raw.t;
    metadata : Raw.t option;
    postconditions : T.Postconditions.t option;
    retries : int;
    repeat : repeat option;
  }
end
