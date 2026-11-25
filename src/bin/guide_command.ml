(* gamepilot guide PROGRAM | --write | --check

   The user guides (docs/guide/, docs/guide/README.md): one page per
   registered program, <id>.md, and any number of extra pages for a part of
   one, <id>.<part>.md (frlg.mail_glitch.item_duplication.md). Hand-written
   prose around generated blocks (Guide_page, Guide_blocks).

   - PROGRAM prints each block the program's pages can hold, for a first draft;
   - --write refills every page's blocks in place and starts a page, from a
     skeleton, for a program that has none;
   - --check fails, naming each page and the command that fixes it, when a
     program has no page, a page names no program, a page still holds the
     skeleton's TODO, or a block is not what --write would write (CI runs it:
     a plan change makes its program's checkpoints block stale). *)

module R = Program_registry

let usage = "  gamepilot guide PROGRAM | --write | --check\n"
let ( let* ) = Result.bind
let regenerate = "cd src && opam exec -- dune exec -- gamepilot guide --write"
let todo = "<!-- TODO(guide)"

(* The program a page is for, by its file name; None for the index. *)
let program_of_page name =
  if name = "README.md" then Ok None
  else
    match
      List.find_opt
        (fun (p : R.t) ->
          name = p.id ^ ".md" || String.starts_with ~prefix:(p.id ^ ".") name)
        R.all
    with
    | Some p -> Ok (Some p)
    | None ->
        Error (name ^ ": no program has this id (gamepilot programs lists them)")

let guide_dir () =
  match R.locate Guide_blocks.guide_dir with
  | Some dir -> Ok dir
  | None ->
      Error (Guide_blocks.guide_dir ^ " not found from here: run in the repo")

let pages dir =
  Sys.readdir dir |> Array.to_list
  |> List.filter (fun n -> Filename.check_suffix n ".md")
  |> List.sort compare

let contains text sub =
  let n = String.length sub in
  let rec at i =
    i + n <= String.length text && (String.sub text i n = sub || at (i + 1))
  in
  at 0

let read path = In_channel.with_open_bin path In_channel.input_all

let write path text =
  Out_channel.with_open_bin path (fun oc -> Out_channel.output_string oc text)

let block p name arg =
  let marker = Guide_page.start_marker name arg in
  match Guide_blocks.generate p { name; arg; body = "" } with
  | Ok body -> marker ^ "\n" ^ body ^ "\n" ^ Guide_page.end_marker ^ "\n"
  | Error e -> "<!-- " ^ name ^ ": " ^ e ^ " -->\n"

let skeleton (p : R.t) =
  let b name = block (Some p) name None in
  String.concat "\n"
    [
      "# " ^ p.name ^ "\n";
      todo
      ^ ": what it does and gets you, for a player; replace every TODO. -->\n";
      b "backends";
      "## Before you start\n";
      b "needs";
      "## Running it\n";
      b "commands";
      "## What happens\n";
      b "checkpoints";
      "## When it stops\n";
      b "preflight";
      "## Known limits\n";
    ]

let show id =
  match R.find id with
  | None -> Error ("no program " ^ id ^ ": gamepilot programs lists them")
  | Some p ->
      List.iter
        (fun name -> print_string (block (Some p) name None))
        [ "backends"; "needs"; "commands"; "checkpoints"; "preflight" ];
      Ok 0

(* The page's text with its blocks refilled. *)
let refill dir name =
  let* p = program_of_page name in
  let text = read (Filename.concat dir name) in
  let* filled =
    Result.map_error
      (fun e -> name ^ ": " ^ e)
      (Guide_page.fill (Guide_blocks.generate p) text)
  in
  Ok (text, filled)

let missing dir =
  List.filter
    (fun (p : R.t) ->
      not (Sys.file_exists (Filename.concat dir (p.id ^ ".md"))))
    R.all

let write_all () =
  let* dir = guide_dir () in
  List.iter
    (fun (p : R.t) ->
      write (Filename.concat dir (p.id ^ ".md")) (skeleton p);
      print_endline ("started " ^ Guide_blocks.page_of p))
    (missing dir);
  List.fold_left
    (fun acc name ->
      let* code = acc in
      let* text, filled = refill dir name in
      if filled <> text then (
        write (Filename.concat dir name) filled;
        print_endline ("updated " ^ name));
      Ok code)
    (Ok 0) (pages dir)

let page_problems dir name =
  match refill dir name with
  | Error e -> [ e ]
  | Ok (text, filled) ->
      (if filled <> text then [ name ^ ": generated blocks are stale" ] else [])
      @
      if contains text todo then
        [ name ^ ": still has the skeleton's TODO(guide)" ]
      else []

let check () =
  let* dir = guide_dir () in
  let problems =
    List.map
      (fun (p : R.t) -> Guide_blocks.page_of p ^ ": no guide page")
      (missing dir)
    @ List.concat_map (page_problems dir) (pages dir)
  in
  if problems = [] then (
    print_endline "guides up to date";
    Ok 0)
  else (
    List.iter prerr_endline problems;
    prerr_endline ("regenerate: " ^ regenerate ^ ", then edit the prose");
    Ok 1)

let main = function
  | [ "--check" ] -> check ()
  | [ "--write" ] -> write_all ()
  | [ id ] when not (String.starts_with ~prefix:"-" id) -> show id
  | _ -> Error "gamepilot guide takes a program, --write or --check"
