(** A game's action sum decoded from a list of parts: each action set's decoder
    says which kind names it owns, and the game lists its parts once, each with
    its constructor ([docs/design/Composable-Rules.md], "Actions"):

    {[
      let parts =
        Action_parts.
          [
            Part ((module Builtin_action_decode), fun a -> Story a);
            Part ((module Toy_walk_decode), fun a -> Walk a);
          ]

      let action_of_plan = Action_parts.action_of_plan parts
    ]}

    Kind names are strings, so the compiler cannot see two parts own one: each
    game's plan format test asserts [claimed_twice parts = []]. *)

(** One action set's plan decoder. *)
module type ACTION_DECODE = sig
  type t

  val names : string list
  (** The kinds it owns, as plans write them. *)

  val of_plan :
    string -> (where:string -> Json_field.obj -> (t, string) result) option
  (** The reader of the kind of that name, given the event's [args] ([where]
      their prefix; an unknown arg is its error), or [None] when the set does
      not own the name. *)
end

(** A set's decoder and the constructor that puts its action in the game's sum.
*)
type 'action part =
  | Part :
      (module ACTION_DECODE with type t = 'a) * ('a -> 'action)
      -> 'action part

val action_of_plan :
  'action part list ->
  string ->
  (where:string -> Json_field.obj -> ('action, string) result) option
(** The reader of the first part that owns the name, its action put in the sum;
    [None] when no part owns it. *)

val claimed_twice : 'action part list -> string list
(** The names two or more parts own, each once, in the order the parts list
    them. A game's plan format test wants [[]]. *)
