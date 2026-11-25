(** Reader: the move effectiveness symbols beside the four moves while ZL locks
    on in battle: the fork's [MoveEffectivenessSymbolDetector]
    (PokemonLZA_MoveEffectivenessSymbol.cpp). In each move's box (top 0.780,
    0.750; left 0.750, 0.800; right 0.806, 0.800; bottom 0.780, 0.850; each
    0.025 x 0.041) the white pixels in four ranges (0xc0c0c0 to 0xf0f0f0 up to
    white), blobs of 50 pixels at least, each scored against the four symbols'
    templates (their Packages images, cropped as the fork does); the best score
    under 150 names the move's symbol.

    Where we differ: the fork scores a blob's box with the pixels outside the
    colour range blacked out; the daemon scores the box as it is. Under a symbol
    the button is dark, so the two are close; the 150 bound is wide. *)

(** A move's symbol, weakest first: the fork's [MoveEffectivenessSymbol]. *)
type symbol = No_effect | Not_very_effective | Effective | Super_effective

val symbol_name : symbol -> string
(** As the fork logs it: ["No Effect"], ["Not Very Effective"], ["Effective"],
    ["Super Effective"]. *)

val probes : picture:Wire.box -> assets:Blob_assets.t -> Wire.probe_spec list
(** The 16 probes (four boxes, four templates each). *)

val read : Effects.measurements -> symbol option list
(** The four moves' symbols, top, left, right, bottom; [None] for a move with
    none (or a missing probe). *)
