(** The button detector the PLZA readers share, ported from
    PokemonLZA_ButtonDetector.cpp: a [core.find@1] probe for one button's
    template over a box, and whether a blob there matches it.

    As the fork matches a button: the bright pixels in each of eight ranges
    (0x808080 to white up to 0xf0f0f0 to white), blobs of at least 1000 pixels
    at 4K; for a D-pad marker's black inside, the dark pixels in each of four
    ranges (black to 0x404040 up to black to 0x707070), blobs of at least 100
    pixels at 4K. Each button has the fork's least width and height at 4K (50 x
    50 for A, B and the right arrow, 30 x 30 for minus and the D-pad markers, 10
    x 10 for their insides) and its score limit (70 for A and the right arrow,
    80 for B, minus and the D-pad markers, 120 for their insides); aspect and
    fill within 0.8 to 1.25 of the template's (the default bounds of
    CommonTools/ImageMatch/WaterfillTemplateMatcher.cpp in
    https://github.com/PokemonAutomation/Arduino-Source). Sizes and areas are
    scaled from 4K to 1080p.

    Where it differs: the fork's detector also keeps where the button was; this
    says only whether it shows. Only the buttons the readers use are here. *)

(** The buttons the PLZA readers look for, each with its own template and size
    limits. *)
type button =
  | A  (** a prompt's A ("A Talk") *)
  | B  (** the main menu's B (Close) *)
  | Minus  (** the Run prompt's minus *)
  | Right  (** the main menu's right arrow *)
  | Dpad_up  (** the party bar's D-pad up marker *)
  | Dpad_down  (** the party bar's D-pad down marker *)
  | Dpad_up_interior  (** the D-pad up marker's black inside *)
  | Dpad_down_interior  (** the D-pad down marker's black inside *)

val probe :
  picture:Wire.box ->
  assets:Blob_assets.t ->
  id:string ->
  button ->
  Native_box.t ->
  Wire.probe_spec list
(** The probe named [id] for [button] over the box, for a game picture at
    [picture] in the frame. *)

val shown : Effects.measurements -> string -> button -> bool
(** A blob of the probe [id] matches [button]; [false] when the probe is
    missing. *)
