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

(* What one read did: its result, its looks, and the other calls in order
   (opening, the log line, closing). *)
type outcome = { read : Card.t option; looks : int; calls : string list }

let run looks =
  let calls = ref [] in
  let read = T.read_with (fake_game_steps looks calls) in
  let calls = List.rev !calls in
  {
    read;
    looks = List.length (List.filter (( = ) "look") calls);
    calls = List.filter (( <> ) "look") calls;
  }

let case name input expectation = { Table_test.name; input; expectation }

let first_and_last = function
  | [] -> "no call"
  | first :: _ as calls ->
      Printf.sprintf "%s first, %s last" first
        (List.nth calls (List.length calls - 1))

let log_lines o =
  String.concat " | "
    (List.filter (fun c -> c <> "open" && c <> "close") o.calls)

(* One case per fact of a scenario: the read, the looks, the card opened first
   and closed last, the log line. *)
let scenario name looks ~read ~looks:n ~log =
  let o = lazy (run looks) in
  let fact what f expected =
    case (name ^ ": " ^ what) (fun () -> f (Lazy.force o)) expected
  in
  [
    fact "the read"
      (fun o -> Option.fold ~none:"unread" ~some:Card.to_string o.read)
      read;
    fact "the looks" (fun o -> string_of_int o.looks) (string_of_int n);
    fact "opened first, closed last"
      (fun o -> first_and_last o.calls)
      "open first, close last";
    fact "the log" log_lines log;
  ]

let eight =
  "8 badges (boulder, cascade, thunder, rainbow, soul, marsh, volcano, earth), \
   1 star"

let () =
  Table_test.run "trainer card badges"
    (List.concat
       [
         scenario "read once two looks agree"
           [ None; Some (card 8 1); Some (card 8 1) ]
           ~read:eight ~looks:3
           ~log:("Trainer Card: " ^ eight ^ ".");
         scenario "a look that changes starts over"
           [ Some (card 0 0); Some (card 2 0); Some (card 2 0) ]
           ~read:"2 badges (boulder, cascade), no star" ~looks:3
           ~log:"Trainer Card: 2 badges (boulder, cascade), no star.";
         scenario "never shows: unread, the card closed" [ None ] ~read:"unread"
           ~looks:22 ~log:"Trainer Card: the badges did not read.";
       ])
