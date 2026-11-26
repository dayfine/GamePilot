(** Reader: Mystery Gift's message that a gift cannot be had again, by a
    template of one of its lines in the game's language. Ours, measured on
    console B's Japanese 360p frames (2026-11-26):

    - an Internet gift received before (after its claim's A): "この おくりものは /
      一度受け取ったことがあるので / 受け取ることができません", its second line cut at (696, 519, 522, 42)
      of the 1080p frame;
    - a code used before (after the code's +): "この シリアルコードは / 使用済み です / ...",
      its second line cut at (825, 459, 270, 45).

    Each template is matched within 15 px of where it was cut; the line shows
    when it scores 0.03 or less. The templates were cut from 360p frames and
    scaled 3 times up; no 1080p frame of either message was kept. Only Japanese
    templates exist; a game in another language reads neither message. *)

type templates = {
  gift : string option;
      (** The uploaded template of the Internet message's line, or [None]. *)
  code : string option;
      (** The uploaded template of the code message's line, or [None]. *)
}
(** The game language's templates. *)

val none : templates
(** No template: neither message reads. *)

val probes : picture:Wire.box -> templates -> Wire.probe_spec list
(** A [core.template_match@1] probe for each template given. *)

val gift_received : Effects.measurements -> bool
(** The Internet gift's "received before" message shows. *)

val code_used : Effects.measurements -> bool
(** The code's "used before" message shows. *)

val describe : Effects.measurements -> string
(** Both scores, for a log line. *)
