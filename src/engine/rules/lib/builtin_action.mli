(** The engine's built-in actions, a set every game's action sum can list: talk
    to whoever the player faces, answer a yes/no prompt, clear a scene back to
    free control, and save ([docs/design/Composable-Rules.md]). The plan reads
    them with [Engine_plan_format.Builtin_action_decode], they print themselves
    ({!to_string}), and each game runs them its own way. *)

(** Built-in checkpoint actions shared across games. *)
type t =
  | Talk  (** Talk to whoever the player faces and settle back to control. *)
  | Answer of bool  (** Answer a yes/no prompt: [true] for yes. *)
  | Scene  (** Clear dialog and cutscenes back to free control. *)
  | Save  (** Save the game in-game. *)

val to_string : t -> string
(** The action, its name first: [talk], [answer yes], [answer no], [scene],
    [save]. *)
