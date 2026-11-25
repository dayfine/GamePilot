(** The party member a Fly uses: the first, slot 1 first, that knows Fly, read
    off each member's summary moves page ({!Summary_paging}), and FLY's row on
    its party menu. A plan names no member for a Fly: any member that knows it
    will do. Where we differ: the fork's PokemonFRLG_Navigation.cpp always opens
    the last party slot's menu for Fly. *)

type user = {
  slot : int;  (** From 1. *)
  menu_row : int;  (** FLY's row on its menu, from 1. *)
}

val field_moves : string list
(** The moves a party member's menu can list, in the order of pret pokefirered's
    field move table (src/party_menu.c): Flash, Cut, Fly, Strength, Surf, Rock
    Smash, Waterfall, Teleport, Dig, Milk Drink, Softboiled, Sweet Scent. *)

val menu_row : string list -> int option
(** FLY's row (from 1) on the menu of a member that knows these moves, in move
    order: SUMMARY, then a row for each field move it knows, in move order (pret
    pokefirered src/party_menu.c: it walks the moves in order and adds a row for
    each one that is a field move). [None] when Fly is not among them. *)

val first : string list list -> user option
(** The first member, of the party's moves slot 1 first, that knows Fly. *)

val read : log:(string -> unit) -> (user, Pokemon_engine.Failure.cause) result
(** From the overworld: each member's moves, slot 1 first, until one knows Fly,
    then out to the overworld. Fails as [no_party], [no_member_menu] or
    [no_summary], and as [no_fly_user] (it repeats) when no member knows Fly. *)
