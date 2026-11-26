(* A program's run options: KEY=VALUE pairs, checked against the program's
   declaration (frlg.ace's item and withdraw here), looked up and shown. *)

open Run_options

let ace =
  [
    {
      key = "item";
      value = One_of [ "master-ball"; "luxury-ball" ];
      presence = Required;
      doc = "the item to make";
    };
    {
      key = "withdraw";
      value = Int_range (1, 999);
      presence = Default "1";
      doc = "how many go to the bag";
    };
    { key = "note"; value = Text; presence = Optional; doc = "a note" };
  ]

let result = function Ok text -> text | Error e -> "error: " ^ e

let pair text () =
  result (Result.map (fun (k, v) -> k ^ " / " ^ v) (Run_options.pair text))

let check ?(decls = ace) given () =
  let pairs = List.map (fun p -> Result.get_ok (Run_options.pair p)) given in
  result (Result.map to_text (Run_options.check decls pairs))

let lookup given read () =
  let pairs = List.map (fun p -> Result.get_ok (Run_options.pair p)) given in
  match Run_options.check ace pairs with
  | Ok t -> read t
  | Error e -> "error: " ^ e

let decls d () = result (Result.map (fun () -> "ok") (check_declaration d))
let item value presence = [ { key = "item"; value; presence; doc = "" } ]
let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "run_options"
    [
      case "a pair" (pair "item=master-ball") "item / master-ball";
      case "a value with =" (pair "note=a=b") "note / a=b";
      case "an empty value" (pair "note=") "note / ";
      case "no =" (pair "item") "error: --options item: not KEY=VALUE";
      case "an empty key" (pair "=1") "error: --options =1: an empty key";
      case "given, in declaration order"
        (check [ "withdraw=50"; "item=luxury-ball" ])
        "item=luxury-ball withdraw=50";
      case "a default filled"
        (check [ "item=master-ball" ])
        "item=master-ball withdraw=1";
      case "an optional key given"
        (check [ "item=master-ball"; "note=x" ])
        "item=master-ball withdraw=1 note=x";
      case "a required key missing" (check [ "withdraw=5" ])
        "error: --options item=master-ball | luxury-ball is required";
      case "an unknown key"
        (check [ "item=master-ball"; "colour=red" ])
        "error: --options colour: not an option of this program; it takes item \
         (master-ball | luxury-ball), withdraw (1 to 999), note (text)";
      case "a program that takes none"
        (check ~decls:[] [ "item=master-ball" ])
        "error: --options item: this program takes no options";
      case "none given to one that takes none" (check ~decls:[] []) "";
      case "a word not listed"
        (check [ "item=great-ball" ])
        "error: --options item=great-ball: item is master-ball | luxury-ball";
      case "a number out of range"
        (check [ "item=master-ball"; "withdraw=1000" ])
        "error: --options withdraw=1000: withdraw is 1 to 999";
      case "not a number"
        (check [ "item=master-ball"; "withdraw=ten" ])
        "error: --options withdraw=ten: withdraw is 1 to 999";
      case "a number written oddly"
        (check [ "item=master-ball"; "withdraw=050" ])
        "error: --options withdraw=050: withdraw is 1 to 999";
      case "empty text"
        (check [ "item=master-ball"; "note=" ])
        "error: --options note=: note is text";
      case "a key given twice"
        (check [ "item=master-ball"; "item=luxury-ball" ])
        "error: --options item is given twice";
      case "find"
        (lookup [ "item=master-ball" ] (fun t ->
             Option.value (find t "item") ~default:"none"))
        "master-ball";
      case "find an optional key not given"
        (lookup [ "item=master-ball" ] (fun t ->
             Option.value (find t "note") ~default:"none"))
        "none";
      case "int"
        (lookup [ "item=master-ball"; "withdraw=50" ] (fun t ->
             Option.fold ~none:"none" ~some:string_of_int (int t "withdraw")))
        "50";
      case "describe a required key"
        (fun () -> describe (List.hd ace))
        "item=master-ball | luxury-ball (required): the item to make";
      case "describe a default"
        (fun () -> describe (List.nth ace 1))
        "withdraw=1 to 999 (default 1): how many go to the bag";
      case "a sound declaration" (decls ace) "ok";
      case "a key twice"
        (decls (ace @ ace))
        "error: option item: declared twice";
      case "a key in capitals"
        (decls [ { (List.hd ace) with key = "Item" } ])
        "error: option Item: a key is lower case, digits, - and _";
      case "no word to choose"
        (decls (item (One_of []) Required))
        "error: option item: no value to choose";
      case "an empty range"
        (decls (item (Int_range (5, 1)) Required))
        "error: option item: an empty range";
      case "a default not taken"
        (decls (item (Int_range (1, 9)) (Default "10")))
        "error: option item: the default 10 is not 1 to 9";
    ]
