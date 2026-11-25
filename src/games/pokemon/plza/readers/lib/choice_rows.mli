(** Reader: a choice box's rows and which one is highlighted (the screen's
    choice rows reading). Ported from PokemonLZA_DialogChoiceBox.cpp. On the
    1080p frame the panel ends at x 1728, y 808 and grows left to fit its
    longest row; the bottom row's highlight runs y 732-800 and each row above
    sits 80 higher. Rows are read from the bottom up, at most six:

    - a row's strip right of any text (x 1698-1711, 40 high) is highlighted when
      flat (stddevs summing to 30 at most) and every channel averages 200 up, a
      plain row when flat panel blue (red 70 at most, green 100 at most, blue
      80-150 and over red by 40), else the rows have ended;
    - the first highlighted row's highlight is followed left from x 1700 along
      two lines 4 inside its top and bottom while either is white (every channel
      200 up);
    - a plain row has text when its band from 10 right of the highlight's left
      to x 1690 is 0.5% bright (every channel 180 up); the rows end at a plain
      row without text.

    It reads when exactly one row is highlighted and there are two rows at least
    (one white strip alone is light pavement).

    Where it differs: the highlight is followed left to x 960 at most (the
    choice arrow's box; the fork goes on to the frame's edge), so the probes
    stay short. Panels measured in the fork start at x 1198-1408. *)

type t = { count : int; selected : int }
(** The rows, and the highlighted one, 0 the top. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The probes {!read} needs, for a game picture at [picture] in the frame. *)

val read : Effects.measurements -> t option
(** The rows, or [None] when they do not read (or a probe is missing). *)
