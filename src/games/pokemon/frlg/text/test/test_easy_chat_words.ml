(* The Easy Chat words (easy_chat_words_eng.txt, from pret): the grid's group
   order, and where the ACE setup's four words sit in their groups (pomeg-
   letterbombers' FRLG non-JPN Post-E4 route). Indices checked by hand on mGBA
   (2026-11-25): CAPABLE is ACTIONS' 8th word, KARATE CHOP MOVE 1's 61st,
   BULK UP MOVE 2's 23rd. *)

open Frlg_text

let words =
  match Data_files.locate Data_files.easy_chat_words_eng with
  | None -> failwith "easy_chat_words_eng.txt not found"
  | Some path -> (
      match Easy_chat_words.load path with
      | Ok w -> w
      | Error why -> failwith why)

let index group word =
  match Easy_chat_words.group words group with
  | None -> "no group"
  | Some g -> (
      match List.find_index (String.equal word) g.words with
      | Some i -> string_of_int i
      | None -> "not in the group")

let first n l = List.filteri (fun i _ -> i < n) l

let () =
  Table_test.run "easy chat words"
    [
      {
        Table_test.name = "the grid's first groups";
        input =
          (fun () -> String.concat ", " (first 4 (Easy_chat_words.names words)));
        expectation = "POKéMON, TRAINER, STATUS, BATTLE";
      };
      {
        Table_test.name = "the grid's last groups";
        input =
          (fun () ->
            String.concat ", "
              (List.filteri (fun i _ -> i >= 16) (Easy_chat_words.names words)));
        expectation = "ADJECTIVES, EVENTS, MOVE 1, MOVE 2, POKéMON2";
      };
      {
        Table_test.name = "CAPABLE";
        input = (fun () -> index "ACTIONS" "CAPABLE");
        expectation = "7";
      };
      {
        Table_test.name = "KARATE CHOP";
        input = (fun () -> index "MOVE 1" "KARATE CHOP");
        expectation = "60";
      };
      {
        Table_test.name = "BULK UP";
        input = (fun () -> index "MOVE 2" "BULK UP");
        expectation = "22";
      };
      {
        Table_test.name = "MAGIKARP in POKéMON";
        input =
          (fun () ->
            match index "POKéMON" "MAGIKARP" with
            | ("no group" | "not in the group") as e -> e
            | _ -> "listed");
        expectation = "listed";
      };
      {
        Table_test.name = "look-alikes share the first letter";
        input =
          (fun () ->
            match Easy_chat_words.group words "MOVE 2" with
            | None -> "no group"
            | Some g ->
                string_of_bool
                  (List.for_all
                     (fun w -> w.[0] = 'B')
                     (Easy_chat_words.look_alikes g "BULK UP")));
        expectation = "true";
      };
    ]
