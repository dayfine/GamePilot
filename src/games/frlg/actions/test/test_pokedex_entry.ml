(* Pokedex_entry.read_with on a fake list that moves as pret's list_menu.c
   moves the Pokédex's (9 rows shown; DOWN keeps the arrow on row 5 while the
   list can scroll, UP on row 3; RIGHT and LEFT nine of those), and
   Skip_conditions.check on condition names and its answer to an entry. *)

open Frlg_actions

type list_state = { mutable top : int; mutable row : int }

let shown_rows = 9
let down_row = 5
let up_row = 3

(* The list of numbers 1..[highest]: one step down or up. *)
let down l ~count =
  if l.top + l.row < count - 1 then
    if l.row < down_row || l.top >= count - shown_rows then l.row <- l.row + 1
    else l.top <- l.top + 1

let up l =
  if l.top + l.row > 0 then
    if l.row > up_row || l.top = 0 then l.row <- l.row - 1
    else l.top <- l.top - 1

let move l ~count = function
  | Wire.Down -> down l ~count
  | Wire.Up -> up l
  | Wire.Right ->
      for _ = 1 to shown_rows do
        down l ~count
      done
  | Wire.Left ->
      for _ = 1 to shown_rows do
        up l
      done
  | _ -> ()

(* The save: the highest number seen, the seen and caught numbers' names; every
   [lose]th tap lost when [lose] > 0; [reads] false: no look reads. *)
type save = {
  highest : int;
  seen : (int * string) list;
  caught : int list;
  lose : int;
  reads : bool;
}

let fake_game_steps save calls : Pokedex_entry.game_steps =
  let l = { top = 0; row = 0 } and taps = ref 0 in
  let call c = calls := c :: !calls in
  let number_at row = l.top + row + 1 in
  {
    open_list = (fun () -> call "open");
    look =
      (fun () ->
        if save.reads then Some { row = l.row; number = number_at l.row }
        else None);
    tap =
      (fun b ->
        incr taps;
        if save.lose = 0 || !taps mod save.lose <> 0 then
          move l ~count:save.highest b);
    entry_on =
      (fun ~row ~name ->
        let n = number_at row in
        match List.assoc_opt n save.seen with
        | Some shown when shown = name ->
            Some (if List.mem n save.caught then Caught else Seen)
        | Some _ -> None
        | None -> Some Not_seen);
    close_list = (fun () -> call "close");
    log = (fun line -> call line);
  }

let save =
  {
    highest = 149;
    seen = [ (7, "SQUIRTLE"); (130, "GYARADOS"); (149, "DRAGONITE") ];
    caught = [ 7 ];
    lose = 0;
    reads = true;
  }

let read save ~number ~name =
  let calls = ref [] in
  let result =
    match
      Pokedex_entry.read_with (fake_game_steps save calls) ~number ~name
    with
    | Ok e -> Pokedex_entry.entry_name e
    | Error e -> "error: " ^ e
  in
  let calls = List.rev !calls in
  let closed = List.nth_opt calls (List.length calls - 1) = Some "close" in
  Printf.sprintf "%s%s" result (if closed then "" else " (not closed)")

let entry_cases =
  [
    ("No129 dashes", (save, 129, "MAGIKARP"), "not seen");
    ("No130 seen", (save, 130, "GYARADOS"), "seen");
    ("No007 caught", (save, 7, "SQUIRTLE"), "caught");
    ("No149 the last", (save, 149, "DRAGONITE"), "seen");
    ("No150 past the list's end", (save, 150, "MEWTWO"), "not seen");
    ("every third tap lost", ({ save with lose = 3 }, 130, "GYARADOS"), "seen");
    ( "a name on the row that is not the species'",
      (save, 130, "MAGIKARP"),
      "error: No130's row shows neither MAGIKARP nor dashes" );
    ( "nothing reads",
      ({ save with reads = false }, 130, "GYARADOS"),
      "error: the list's arrow and number did not read" );
  ]

let species = [ ("bulbasaur", "BULBASAUR"); ("ivysaur", "IVYSAUR") ]

let check condition =
  match Skip_conditions.check species condition with
  | Ok () -> "ok"
  | Error e -> e

let () =
  Table_test.run "pokedex entry"
    (List.map
       (fun (name, (save, number, species), expectation) ->
         {
           Table_test.name;
           input = (fun () -> read save ~number ~name:species);
           expectation;
         })
       entry_cases
    @ List.map
        (fun (condition, expectation) ->
          {
            Table_test.name = "check " ^ condition;
            input = (fun () -> check condition);
            expectation;
          })
        [
          ("pokedex_seen:ivysaur", "ok");
          ( "pokedex_seen:mew",
            "skip_if pokedex_seen:mew: mew is no Kanto Pokedex species" );
          ("pokedex_not_seen:bulbasaur", "ok");
          ( "pokedex_not_seen:mew",
            "skip_if pokedex_not_seen:mew: mew is no Kanto Pokedex species" );
          ("surge_winnable", "ok");
        ]
    @ List.map
        (fun (name, seen, entry, expectation) ->
          {
            Table_test.name = "answer " ^ name;
            input =
              (fun () ->
                let what, holds = Skip_conditions.answer ~seen entry in
                Printf.sprintf "%s, %b" what holds);
            expectation;
          })
        [
          ("pokedex_seen, seen", true, Ok Pokedex_entry.Seen, "seen, true");
          ("pokedex_seen, caught", true, Ok Pokedex_entry.Caught, "caught, true");
          ( "pokedex_seen, not seen",
            true,
            Ok Pokedex_entry.Not_seen,
            "not seen, false" );
          ("pokedex_not_seen, seen", false, Ok Pokedex_entry.Seen, "seen, false");
          ( "pokedex_not_seen, caught",
            false,
            Ok Pokedex_entry.Caught,
            "caught, false" );
          ( "pokedex_not_seen, not seen",
            false,
            Ok Pokedex_entry.Not_seen,
            "not seen, true" );
          ( "pokedex_not_seen, not read: the event runs",
            false,
            Error (Pokemon_engine.Failure.cause "pokedex_unread" "no list"),
            "not read (pokedex_unread: no list), so not skipped, false" );
        ]
    @ [
        {
          Table_test.name = "number_of magikarp";
          input =
            (fun () ->
              match
                Pokedex_entry.number_of
                  (List.init 160 (fun i ->
                       if i = 128 then ("magikarp", "MAGIKARP")
                       else (string_of_int i, "")))
                  "magikarp"
              with
              | Some n -> string_of_int n
              | None -> "none");
          expectation = "129";
        };
      ])
