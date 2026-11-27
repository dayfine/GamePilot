(* How a guide page's generated blocks are found and refilled: the text around
   them kept as it is, and the errors a broken marker gets. *)

let show_blocks text =
  match Guide_page.blocks text with
  | Error e -> "error: " ^ e
  | Ok bs ->
      String.concat " | "
        (List.map
           (fun (b : Guide_page.block) ->
             Printf.sprintf "%s %s [%s]" b.name
               (Option.value b.arg ~default:"-")
               (String.escaped b.body))
           bs)

let generate (b : Guide_page.block) =
  match b.name with
  | "fail" -> Error "no such block"
  | name -> Ok (name ^ " " ^ Option.value b.arg ~default:"all")

let show_fill text =
  match Guide_page.fill generate text with
  | Ok page -> String.escaped page
  | Error e -> "error: " ^ e

let show_long text =
  Guide_page.long_paragraphs ~max_lines:2 text
  |> List.map (fun (line, n) -> Printf.sprintf "%d:%d" line n)
  |> String.concat " "

let show_missing required text =
  match Guide_page.missing_blocks ~required text with
  | Ok names -> String.concat " " names
  | Error e -> "error: " ^ e

let page =
  "# Title\n\
   prose\n\
   <!-- generated:needs mg-01 -->\n\
   old line 1\n\
   old line 2\n\
   <!-- /generated -->\n\
   more prose\n\
   <!-- generated:backends -->\n\
   <!-- /generated -->\n"

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "guide_page"
    [
      case "blocks with and without an arg"
        (fun () -> show_blocks page)
        "needs mg-01 [old line 1\\nold line 2\\n] | backends - []";
      case "fill keeps the prose and replaces each body"
        (fun () -> show_fill page)
        (String.escaped
           "# Title\n\
            prose\n\
            <!-- generated:needs mg-01 -->\n\
            needs mg-01\n\
            <!-- /generated -->\n\
            more prose\n\
            <!-- generated:backends -->\n\
            backends all\n\
            <!-- /generated -->\n");
      case "fill is stable: twice gives the same page"
        (fun () ->
          match Guide_page.fill generate page with
          | Error e -> e
          | Ok once -> string_of_bool (show_fill once = String.escaped once))
        "true";
      case "a page with no trailing newline keeps none"
        (fun () -> show_fill "a\nb")
        "a\\nb";
      case "a page with no blocks is unchanged"
        (fun () -> show_fill "a\n\nb\n")
        "a\\n\\nb\\n";
      case "a generator's error"
        (fun () -> show_fill "<!-- generated:fail -->\n<!-- /generated -->\n")
        "error: no such block";
      case "a block with no end"
        (fun () -> show_blocks "x\n<!-- generated:needs -->\ny\n")
        "error: line 2: no <!-- /generated --> for this block";
      case "an end with no block"
        (fun () -> show_blocks "x\n<!-- /generated -->\n")
        "error: line 2: <!-- /generated --> with no block open";
      case "a block inside a block"
        (fun () ->
          show_blocks
            "<!-- generated:a -->\n<!-- generated:b -->\n<!-- /generated -->\n")
        "error: line 2: a block starts inside the block of line 1";
      case "a long paragraph, by its first line and length"
        (fun () -> show_long "# T\n\na\nb\nc\n\nd\n")
        "3:3";
      case "a list item is a paragraph of its own"
        (fun () -> show_long "- a\n  b\n- c\n- d\n  e\n  f\n")
        "4:3";
      case "blocks, fences, indented code and tables are not paragraphs"
        (fun () ->
          show_long
            "<!-- generated:x -->\n\
             a\n\
             b\n\
             c\n\
             <!-- /generated -->\n\
             ```\n\
             a\n\
             b\n\
             c\n\
             ```\n\n\
            \    a\n\
            \    b\n\
            \    c\n\n\
             |a|\n\
             |b|\n\
             |c|\n")
        "";
      case "a heading ends a paragraph"
        (fun () -> show_long "a\nb\n## H\nc\n")
        "";
      case "a paragraph at the end of the page"
        (fun () -> show_long "x\n\na\nb\nc")
        "3:3";
      case "a required block the page lacks is missing"
        (fun () -> show_missing [ "options"; "needs" ] page)
        "options";
      case "a page that requires no block misses none"
        (fun () -> show_missing [] "# T\nprose\n")
        "";
      case "a required block the page has is not missing"
        (fun () ->
          show_missing [ "options" ]
            "<!-- generated:options -->\n<!-- /generated -->\n")
        "";
      case "the start marker"
        (fun () -> Guide_page.start_marker "checkpoints" (Some "mg-06"))
        "<!-- generated:checkpoints mg-06 -->";
    ];
  let check_eq name ~expected actual =
    Table_test.report name
      (if actual = expected then Ok () else Error "value did not match expected")
  in
  let load_title ~plan_dir id =
    match id with
    | "01" -> Ok ("01-start", "Start | intro")
    | "02" -> Ok ("02-next", "Next step")
    | other -> Error (plan_dir ^ ": missing " ^ other)
  in
  check_eq "checkpoint_rows formats rows and escapes pipes"
    ~expected:
      (Ok [ "| 01-start | Start \\| intro |"; "| 02-next | Next step |" ])
    (Guide_page.checkpoint_rows ~load_title ~plan_dir:"plans" [ "01"; "02" ]);
  check_eq "checkpoint_rows stops on first error"
    ~expected:(Error "plans: missing 99")
    (Guide_page.checkpoint_rows ~load_title ~plan_dir:"plans" [ "01"; "99" ]);
  check_eq "switch_testing_commands includes args and switch testing flags"
    ~expected:
      "# the Switch: each checkpoint once, from where the console is\n\
       cd src && opam exec -- dune exec -- gamepilot run bdsp.demo --from 01 \
       --to 02 --mode testing --backend switch --serial PORT --capture DEVICE \
       \\\n\
      \    --watch"
    (Guide_page.switch_testing_commands ~args:"bdsp.demo --from 01 --to 02");
  Table_test.finish ()
