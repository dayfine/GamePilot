module Make (T : Engine_terms.GAME_TERMS) = struct
  type kind =
    | Talk
    | Answer of bool
    | Scene
    | Save
    | Game_action of Json_field.obj
    | Own of T.own_kind

  type event = {
    id : string;
    kind : kind;
    action : string option;
    why : string;
    skip_if : string list;
    declared_after : T.pose option;
    once_per_save : bool;
  }

  type checkpoint = {
    checkpoint_id : string;
    title : string;
    start : T.pose option;
    events : event list;
  }

  type repeat = { until : T.promises; max_rounds : int }

  type t = {
    game : string;
    checkpoint : checkpoint;
    execution : Json_field.obj;
    metadata : Json_field.obj option;
    postconditions : T.promises;
    retries : int;
    repeat : repeat option;
  }
end
