(** The engine's story actions, a set every game's action sum can list: talk to
    whoever the player faces, answer a yes/no prompt, clear a scene back to free
    control, and save ([docs/design/Composable-Rules.md]). The plan reads them
    with [Engine_plan_format.Story_action_decode], they print themselves
    ({!to_string}), and each game runs them its own way. *)

type t =
  | Talk
  | Answer of bool  (** Answer a yes/no prompt: [true] for yes. *)
  | Scene  (** Clear dialog and cutscenes back to free control. *)
  | Save

val to_string : t -> string
(** The action, its name first: [talk], [answer yes], [answer no], [scene],
    [save]. *)
