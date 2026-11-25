(* Trainer_card_badges.read_with on fake game steps: the looks a card gives
   while it fades in, and what the read decides from them. *)

open Frlg_actions
module Card = Frlg_readers.Trainer_card_front
module T = Trainer_card_badges

let card earned stars : Card.t =
  { badges = List.init 8 (fun i -> i < earned); stars }

(* The game: each look takes the next of [looks] (the last one again once used
   up); the clock moves on each wait. What was done is kept in [calls]. *)
let fake_game_steps looks calls : T.game_steps =
  let looks = ref looks and clock = ref 0. in
  let call c = calls := c :: !calls in
  {
    open_card = (fun () -> call "open");
    look =
      (fun () ->
        call "look";
        match !looks with
        | [ last ] -> last
        | next :: rest ->
            looks := rest;
            next
        | [] -> None);
    wait = (fun ms -> clock := !clock +. float ms);
    now_ms = (fun () -> !clock);
    close_card = (fun () -> call "close");
    log = (fun line -> call line);
  }

let run looks () =
  let calls = ref [] in
  let read = T.read_with (fake_game_steps looks calls) in
  let looks = List.length (List.filter (( = ) "look") !calls) in
  Printf.sprintf "%s after %d looks; %s"
    (Option.fold ~none:"unread" ~some:Card.to_string read)
    looks
    (String.concat ", " (List.rev (List.filter (( <> ) "look") !calls)))

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "trainer card badges"
    [
      case "read once two looks agree"
        (run [ None; Some (card 8 1); Some (card 8 1) ])
        "8 badges (boulder, cascade, thunder, rainbow, soul, marsh, volcano, \
         earth), 1 star after 3 looks; open, Trainer Card: 8 badges (boulder, \
         cascade, thunder, rainbow, soul, marsh, volcano, earth), 1 star., \
         close";
      case "a look that changes starts over"
        (run [ Some (card 0 0); Some (card 2 0); Some (card 2 0) ])
        "2 badges (boulder, cascade), no star after 3 looks; open, Trainer \
         Card: 2 badges (boulder, cascade), no star., close";
      case "never shows: unread, the card closed" (run [ None ])
        "unread after 22 looks; open, Trainer Card: the badges did not read., \
         close";
    ]
