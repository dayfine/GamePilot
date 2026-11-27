(** Reader: Mystery Gift's info card, the white card with a dark down arrow in
    its bottom right corner (over a grey "i" watermark), by its layout alone: no
    text is read, so it reads in any language. Ours, measured on console B
    (2026-11-26): the card after a claim's A on a gift received before ("この
    おくりものは / 一度受け取ったことがあるので / ...", "由于此礼物 已经接收过了，因此无法再接收。") and after a code's
    \+ on a code used before ("この シリアルコードは / 使用済み です / ...", "此序列号已经使用过了。 ..."),
    in Japanese and zh-Hans; the card spans x 358 to 1561, y 150 to 928 of the
    1080p frame in all of them.

    It shows when, in the 1080p frame:
    - strips across the card's top (420, 165, 1080, 14) and bottom (420, 905,
      820, 14), left of the watermark, are 0.90 white or more (every channel 200
      or over; the card is 253, its text sits between them);
    - strips just outside its left (300, 300, 40, 500) and right (1575, 300, 40,
      500) edges are 0.10 white at most (the blue background);
    - the arrow's box (1420, 835, 46, 45), where it bobs (y 844 to 872), is 0.04
      or more dark (every channel 110 or under; 0.07 to 0.11 on console B's
      cards) and 0.60 or more white (the card and the watermark).

    The watermark itself is not read: its grey (235, 240, 241) is too close to
    the card's white for a colour range to keep them apart once the picture is
    10% brighter. What the card says is not read either: after the Internet
    list's A it is taken for "received before", after a code's + for "code used
    before". Any other message on this card (a connection error, say) would be
    taken so too: none was captured. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The six strips' [color_count] probes. *)

val shown : Effects.measurements -> bool
(** The info card shows, as above. *)

val describe : Effects.measurements -> string
(** The six shares, for a log line. *)
