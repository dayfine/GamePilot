open Frlg_readers
module Card = Trainer_card_front

let look () = Option.bind (Effects.read ()) Card.read
let describe = Card.to_string
let unread = "the badges did not read"
let read_with steps = Trainer_card_read.read_with steps ~describe ~unread
let read ~log = Trainer_card_read.read ~log ~look ~describe ~unread
