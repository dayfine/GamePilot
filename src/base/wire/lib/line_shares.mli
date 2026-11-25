(** [core.line_shares@1] (protocol v1.13): its pixel test and its result.

    The test is linear comparisons on a pixel's channels, all of which a counted
    pixel passes. They state the fork's PLZA PixelShares tests
    (PokemonLZA_PixelShares.cpp, PokemonLZA_ControlsHintDetector.cpp) as they
    are written, e.g. sky blue's [b > r + 60] as
    [{ weights = (-1, 0, 1); op = Greater; value = 60 }]. The result is the
    share of passing pixels per row and per column of the box's frame pixels, so
    a reader sliding the fork's box one line at a time gets every position's
    share from one probe. *)

type json = Yojson.Safe.t

type op =
  | Greater
  | Greater_equal
  | Less
  | Less_equal
      (** How a comparison's weighted sum stands to its value: [>], [>=], [<],
          [<=] on the wire. *)

type comparison = { weights : int * int * int; op : op; value : int }
(** [r * wr + g * wg + b * wb op value], channels 0..255. *)

type test = comparison list
(** Every comparison holds; the daemon refuses an empty test. *)

val greater : r:int -> g:int -> b:int -> int -> comparison
(** [greater ~r ~g ~b v]: [r·R + g·G + b·B > v]. *)

val at_least : r:int -> g:int -> b:int -> int -> comparison
(** [>=]. *)

val passes : test -> int * int * int -> bool
(** Whether a pixel (r, g, b) passes, as the daemon counts it. *)

val test_of_json : string -> json -> test
(** A probe's [test]; [what] names it in a [Decode_error]. *)

val json_of_test : test -> json
(** A probe's [test], as {!test_of_json} reads it. *)

type t = { rows : float list; columns : float list }
(** Top to bottom and left to right: each line's passing pixels over its pixels.
*)

val of_json : string -> json -> t
(** A result object's [rows] and [columns]; [what] names it in a [Decode_error].
*)

val to_json : t -> json
(** The result object, [kind] included. *)
