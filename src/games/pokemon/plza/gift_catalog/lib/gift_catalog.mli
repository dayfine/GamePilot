(** PLZA's Mystery Gift catalog: the gifts [plza.claim-gifts] claims and
    [plza.bank-home] banks in Pokémon HOME, as [gifts.json] in claim-gifts'
    folder lists them ({!Gift_catalog_decode} reads it): the one place each
    gift's box slot and HOME boxes are written. Pure: the gifts, the date a run
    compares their expiry with, and the lines that print them. Ours: the fork
    has no Mystery Gift program. *)

type date = { year : int; month : int; day : int }
(** A calendar day, as ISO writes it (2026-11-25). *)

val date_of_string : string -> (date, string) result
(** ["YYYY-MM-DD"], a real day (30 February is refused). *)

val date_to_string : date -> string
(** ["2026-11-25"]. *)

val compare_date : date -> date -> int
(** Earlier days first. *)

(** How a gift is claimed from the game's Mystery Gift menu. *)
type how =
  | Code  (** typed on "Get with Code/Password" *)
  | Internet  (** picked from the "Get via Internet" list *)
  | Home  (** received through Pokémon HOME, which the program cannot do yet *)

val how_name : how -> string
(** ["code"], ["internet"], ["home"]: as [gifts.json] writes it. *)

type box_slot = { box : int; slot : int }
(** A Boxes slot: box 1 the first, slot 1 to 30 left to right, then down. *)

(** The order a HOME box's slots are tried in for the first empty one, column by
    column. *)
type home_order =
  | Left_to_right  (** from column 1 *)
  | Right_to_left  (** from the last column *)

type pokemon = {
  box_slot : box_slot;
      (** Where the program leaves the gift's Pokémon: the first free box slot
          the game gives it, on a save with a full party (or five, the first
          gift then moved from party slot 6) and Box 1 empty, the gifts claimed
          in the catalog's order. *)
  home_boxes : int list;
      (** The Pokémon HOME boxes it is banked in later (plza.bank-home), tried
          in order: the first with an empty slot takes it. *)
  home_order : home_order;  (** How each of them is searched. *)
}
(** Where a gift's Pokémon goes. *)

type gift = {
  id : string;  (** Short, lower case and [-]: ["xerneas-30th"]. *)
  name : string;  (** As a player calls it: ["Shiny Xerneas"]. *)
  how : how;
  code : string option;  (** The code, for a {!Code} gift only. *)
  expires : date;  (** The last day it can be claimed. *)
  pokemon : pokemon option;  (** [None]: items, nothing lands in a box. *)
  source : string;
      (** The page that announced it (Dittobase, Nintendo Life or VGC). *)
}
(** One gift. *)

type t = gift list
(** The gifts, in the order a run claims them. *)

val expired : today:date -> gift -> bool
(** Its last day is before [today]. *)

val line : gift -> string
(** The gift for the run's log: id, name, how and last day. *)

val lines : t -> string list
(** {!line} of each gift. *)

val guide_table : t -> string
(** The catalog as the guide's [gifts] block shows it: a Markdown table of name,
    how, code, last day, box slot and HOME boxes. *)
