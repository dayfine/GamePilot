(** One thing a save must hold before a checkpoint's first event, for the
    pre-flight ({!Preflight}): a party member, a field move, a badge, money, a
    bag item, the place, or a plan's declared precondition. {!Plan_needs}
    collects them from a plan, {!Plan_preconditions} from its goal; this module
    says each in words. *)

type t =
  | Party_in_order of string list
  | Party_includes of {
      members : string list;
      slots : Pokemon_engine.Postconditions.slot list;
    }
  | Member of { species : string; for_ : string }
      (** A member an event uses ([for_]: ["party_swap"]). *)
  | No_mail of { species : string; for_ : string }
      (** The first member of this species holds no Mail: a [pc_deposit] stores
          it, and the game will not store a Mail holder ("Please remove the
          MAIL."). *)
  | Holding_no_mail of { for_ : string }
      (** Some member holds no Mail: a [pc_deposit] stores the first such member
          (["member"]: ["holding_no_mail"]). *)
  | Knows_move of { move : string; for_ : string }
      (** Some member knows this field move: a [cut_tree] event's Cut, which the
          game lets any member that knows it use, or a [fly] event's Fly, which
          the first member that knows it uses. *)
  | Badge of { badge : string; for_ : string }
      (** The badge a field move needs outside battle ([for_]: the action,
          ["fly"] needs ["thunder"], ["cut_tree"] ["cascade"]), read off the
          Trainer Card. The game checks the badge, not a count (pret pokefirered
          src/party_menu.c: FLAG_BADGE01_GET + the field move; Flash Boulder,
          Cut Cascade, Fly Thunder, Strength Rainbow, Surf Soul, Rock Smash
          Marsh, Waterfall Volcano). *)
  | Money_at_least of { amount : int; for_ : string }
  | Money_between of { min : int; max : int }
  | Item_at_least of { item : string; count : int; for_ : string }
  | Item_exactly of { item : string; count : int }
  | Place of string  (** The checkpoint's start map. *)
  | Anywhere_start of Pokemon_engine.Pose.place_class
      (** The checkpoint starts anywhere in the class (outdoors). FireRed does
          not read the map: the pre-flight lets it pass, and the first Fly
          checks it (the game will not fly indoors). *)
  | Badges_at_least of int
      (** At least this many badges ({!Plan_preconditions}: [badges] a count).
      *)
  | Badges of string list  (** Each of these badges, by name. *)
  | Hall_of_fame  (** The Hall of Fame entered: a star on the card. *)
  | Caught_at_least of int
      (** At least this many species caught, the Trainer Card's Pokédex count
          ({!Plan_preconditions}: [caught]). *)

val describe : t -> string
(** The need as the pre-flight's NEED column ({!Preflight}) and the user guides
    (docs/guide/) say it: ["money at least ¥4100 (buy_coins)"]. *)

val asks_something : t -> bool
(** False for a need any save meets: money or an item at least 0, at least 0
    badges or species caught, an empty party order, badge list or [includes].
    The user guides leave these out (review rule R2,
    [.agents/rules/review-rules.md]). *)
