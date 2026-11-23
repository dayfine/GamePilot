(** Wall anchors: when the walker is unsure which of a few tiles the player is
    on, find holds that bring every candidate to one tile, so the walk can go on
    from a known position.

    A hold keeps one direction pressed until a wall stops the player. What a
    hold is (and how far it went) belongs to the game. Anchors predict where
    holds would end; they do not say the holds were walked. *)

type ('hypothesis, 'hold) step = {
  positions : 'hypothesis list;
      (** Where the candidates end up after the hold. *)
  hold : 'hold;
}
(** One safe hold and where it takes the candidates. *)

type ('position, 'hold) anchor = {
  holds : 'hold list;  (** In the order they are held; empty when known. *)
  at : 'position;  (** Where every candidate ends up. *)
}
(** Holds that bring every candidate to the same position. *)

(** A game's movement rules for holds. *)
module type Movement = sig
  type context
  (** What the rules need besides the candidates: the map, the walking mode. *)

  type hypothesis
  (** One candidate for where the player is. Two candidates may share a position
      and still differ, e.g. in which objects have moved. *)

  type position
  type hold

  val position : hypothesis -> position
  val equal_hypothesis : hypothesis -> hypothesis -> bool
  val equal_position : position -> position -> bool

  val hold :
    context -> hypothesis list -> Direction.t -> (hypothesis, hold) step option
  (** Holding that direction from every candidate, or [None] when it is unsafe
      for any of them: a person, a warp or an unknown edge on the way. *)

  val tiles : hold -> int
  (** How far the hold walks. Orders anchors with the same number of holds. *)
end

(** Wall anchors under one game's rules. *)
module Make (M : Movement) : sig
  val default_max_holds : int
  (** 3. *)

  val find_anchors :
    ?max_holds:int ->
    M.context ->
    M.hypothesis list ->
    (M.position, M.hold) anchor list
  (** The anchors with the fewest holds (at most [max_holds]), fewest held tiles
      first, then by {!Direction.all} order. No candidates have no anchor;
      candidates already at one position need no holds, even with
      [max_holds = 0]. A hold that leaves the candidates as they were, leaves
      none, or walks no tiles is not tried. *)
end
