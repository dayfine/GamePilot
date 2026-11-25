(* What a run keeps beside an event's state, byte for byte, for the golden test
   (kept_files.golden): each kept value as Event_snapshot.write_kept writes it
   (one line of JSON and its newline, printed as is),
   and files kept by older runs (fewer fields, nulls) as they read back and are
   written again. A change that keeps kept_files.golden as it is writes and
   reads every kept file the same way. *)

open Pokemon_engine

let house2 : Pose.observed =
  {
    at_map = "VermilionCity_House2";
    at_tile = { x = 4; y = 4 };
    faces = Some North;
  }

let start ?money ?coins ?(items = []) () : Postcondition_check.start =
  {
    start_money = money;
    start_coins = coins;
    start_caught = None;
    start_items = items;
  }

let written =
  [
    ( "the start money, coins and items, and the reckoned pose",
      ({
         start =
           start ~money:29202 ~coins:50
             ~items:[ ("revive", 0); ("escape-rope", 4) ]
             ();
         at = Some house2;
       }
        : Saved.t) );
    ( "nothing read at the start, the pose unknown",
      { start = start (); at = None } );
    ( "the start money only, a facing the game could not tell",
      { start = start ~money:29202 (); at = Some { house2 with faces = None } }
    );
    ( "an item name that needs escaping",
      { start = start ~items:[ ("poké-ball \"x\"", 2) ] (); at = None } );
  ]

let older =
  [
    ("kept before coins and items were", {|{"start_money":29202,"at":null}|});
    ( "kept before coins and items were, with a pose",
      {|{"start_money":100,"at":{"map":"Town","tile":[1,2],"facing":"west"}}|}
    );
    ("an empty object", "{}");
    ( "fields in another order, spaced",
      {|{ "at": null, "start_items": {"potion": 3}, "start_coins": 7 }|} );
    ( "a facing no run writes",
      {|{"at":{"map":"Town","tile":[1,2],"facing":"up"}}|} );
    ("a field no run writes", {|{"start_money":1,"at":null,"extra":true}|});
    ("not an object", "[]");
    ("an item count that is not a number", {|{"start_items":{"potion":"3"}}|});
    ("a pose with no map", {|{"at":{"tile":[1,2],"facing":null}}|});
  ]

let state = Filename.temp_file "kept" ".ss"
let kept_file = Event_snapshot.kept_path state
let file_bytes () = In_channel.with_open_bin kept_file In_channel.input_all

let print_written (name, kept) =
  Event_snapshot.write_kept state kept;
  Printf.printf "%s\n  %s" name (file_bytes ())

let print_older (name, bytes) =
  Out_channel.with_open_bin kept_file (fun out ->
      Out_channel.output_string out bytes);
  match Event_snapshot.read_kept ~missing:"missing" state with
  | Error e -> Printf.printf "%s\n  error: %s\n" name e
  | Ok kept ->
      Event_snapshot.write_kept state kept;
      Printf.printf "%s\n  written again: %s" name (file_bytes ())

let () =
  print_string "== written by a run\n";
  List.iter print_written written;
  print_string "== kept by older runs, read back\n";
  List.iter print_older older;
  Sys.remove kept_file;
  Sys.remove state
