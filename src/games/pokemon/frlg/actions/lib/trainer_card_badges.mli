(** The badges and stars read off the Trainer Card's front
    ({!Frlg_readers.Trainer_card_front}): what a plan's [badges] and
    [hall_of_fame] preconditions are checked on. New: the fork reads no badges.
    Read as {!Trainer_card_read} reads the card; not flipped, as FireRed draws
    the badges and the stars on the front (pret pokefirered
    [DrawStarsAndBadgesOnCard]). *)

val read_with :
  Frlg_readers.Trainer_card_front.t Trainer_card_read.game_steps ->
  Frlg_readers.Trainer_card_front.t option
(** {!Trainer_card_read.read_with} for the badges and stars. Logs
    ["Trainer Card: 8 badges (boulder, ...), 1 star."], or
    ["Trainer Card: the badges did not read."]. *)

val read : log:(string -> unit) -> Frlg_readers.Trainer_card_front.t option
(** {!read_with} on the console ({!Trainer_card_read.read}): the badges and
    stars on the latest frame. Fails as [no_start_menu] or [not_closed]. *)
