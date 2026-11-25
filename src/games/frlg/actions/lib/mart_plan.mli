(** A ["mart"] action's plan, and the presses it takes, worked out before the
    clerk is talked to. Each Mart's stock is read from
    [src/games/frlg/assets/kanto_mart_stocks.json] (made from pokefirered, as
    its ["source"] says). Ported from the fork's AutoStory Mart
    (PokemonFRLG_AutoStoryMart: [plan_mart_buys()], [quantity_presses()]), with
    a budget in place of its [if_affordable].

    The BUY list is the Mart's stock in order, then CANCEL; the cursor starts on
    the top row and stays on the row bought. The quantity box starts at 1: UP
    adds one, RIGHT adds ten, at most {!max_quantity}. *)

type stock_item = { item : string; price : int }
type stocks

val empty : stocks
(** No Mart: every map is unknown. *)

val asset : string
val parse : Yojson.Safe.t -> (stocks, string) result

val load : unit -> (stocks, string) result
(** The table, found from the working directory and read once. *)

val stock : stocks -> string -> stock_item list option
(** A Mart's stock by its map's name. *)

type line = { line_item : string; quantity : int }

type t = { map : string; lines : line list; budget : int option }
(** The args: ["map"] (a Mart of the table), ["items"] (each an ["item"] the
    Mart sells and a ["quantity"], 1 to {!max_quantity}) and an optional
    ["budget"]: the most money the trip may spend. *)

val max_quantity : int
(** 99. *)

val of_args : stocks -> where:string -> Json_field.obj -> t
(** Raises {!Json_field.Invalid} naming the field. *)

type buy = { row : int; buy_item : string; buy_quantity : int; cost : int }
(** [row]: the item's row on the BUY list, from 0. *)

val buys : stock_item list -> t -> buy list
(** The lines in order, each cut to what is left of the budget; a line the
    budget covers none of is left out. *)

val quantity_presses : int -> int * int
(** [(right, up)] from 1 to the quantity: RIGHT never passes it, so it never
    stops at the most. *)

val buys_to_string : buy list -> string
(** ["2 retro-mail (row 1, $100)"], joined by ["; "]; ["nothing"] when empty. *)
